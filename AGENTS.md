# Agent 规则

本项目是 ElvUI_WindTools 的 **EllesmereUI 迁移壳**：目录结构、模块骨架、选项页范式沿袭上游，运行时依赖 EllesmereUI（`## RequiredDeps: EllesmereUI`）。`Initialize.lua`、`Core\Module.lua`、`Core\CompatE.lua`、`Options\Core.lua` 已整体改写为 EUI 版本，不与上游逐行对应。

单人开发，不做机械检查。下面写的是该守的形状，判断靠你自己。

## 先认清迁移状态

`Modules\` 下大量文件是**已存在但未接入加载链**的挂起代码：`Modules\Load_Modules.xml` 只加载 `Item\Load_Item.xml`、`Social\Load_Social.xml` 加 4 个直接 `<Script>`（`Combat\RaidMarkers.lua`、`UnitFrames\FriendlyNameplateOutline.lua`、`UnitFrames\QuickFocus.lua`、`Misc\GameBar.lua`）。

`README_zhCN.md` 的「迁移进度」表是唯一权威的模块状态表，标 ❌ 的模块改了等于改死文件。让模块生效 = 在 `Load_*.xml` 登记 **+** 改进度表，两处都要动。

写代码前先读这几个文件，它们定义了要照抄的形状：

| 文件 | 定义了什么 |
|---|---|
| `Initialize.lua` | 加载期三道闸门、`InertStub` 降级、DB 初始化、选项页注册 |
| `Core\Module.lua` | `W:NewModule` / `RegisterModule` / `SafeCall` / 模块公共方法 |
| `Core\Functions\TaskManager.lua` | 战斗延迟与登录后延迟：`AfterCombat` / `OutOfCombat` / `AfterLogin` |
| `Modules\Misc\Core.lua` | 回调注册表范式（`AddCallback` / `AddCallbackForAddon` / `AddCallbackForUpdate`） |
| `Modules\Social\SmartTab.lua` | 已接入的中等模块样板 |
| `Modules\UnitFrames\QuickFocus.lua` | 战斗锁定、幂等注册、礼让他人全局表的密度上限样板 |

## 代码风格

### 文件头

三种形状，按文件需要什么选，不要自创第四种：

```lua
-- Modules\ 下的常规模块
local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local ST = W:NewModule("SmartTab")

-- 需要分段注解、或声明已有的父模块
local W ---@class WindTools
local F, E
W, F, E = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI
local M = W.Modules.Misc ---@class Misc

-- 只拿 addon 表的核心文件（Initialize.lua、Core\Module.lua、Core\CompatE.lua）
local addonName, addon = ...
local EUI = _G.EllesmereUI
```

`addon[1..7]` 是 `W, F, E, L, V, P, G`（见 `Initialize.lua`）。解包后立刻把用到的全局 local 化，**包括 `C_` 命名空间的函数**：`local C_GuildInfo_IsGuildOfficer = C_GuildInfo.IsGuildOfficer`（`Modules\Social\SmartTab.lua:25`），密度参考 `Modules\UnitFrames\QuickFocus.lua:4-19`。

### 排版

格式化配置管不到的一条：源码与注释用 ASCII 标点，不用 em dash、不用弯引号。中文只出现在 `Locales\`、`Core\Changelog\` 与 locale 字符串里；`Core\Metadata.lua`、`Modules\Item\ExtraItemBar_Data.lua` 这类数据文件本来就有外文键名，不在此限。

### 注释

只写「为什么」，不写「是什么」，不写变更历史。样板在 `Modules\UnitFrames\QuickFocus.lua:21-22`：

```lua
-- Frames first spotted during combat lockdown wait here until combat ends.
-- Weak keys let frames destroyed mid-combat drop out instead of leaking.
```

违背直觉的写法（礼让别的插件、幂等去重、降级返回原文）都配一行这种注释，否则下一个人会「顺手修好」它。

### 类型注解

`---@class` / `---@type` / `---@field` / `---@cast` 照现有密度写，不必给每个局部变量补。字段名编辑器抓不到，改 API 调用时自己核对。

### 命名

| 对象 | 约定 | 例 |
|---|---|---|
| 模块实例 | 短大写缩写 | `local ST = W:NewModule("SmartTab")` |
| 已有父模块的子模块 | `local M = W.Modules.Misc` + `---@class Misc` | `Modules\Misc\AntiOverride.lua:2` |
| 字符串登记的回调 | 方法名与回调键同名 | `M:AddCallback("AntiOverride")` |
| 本地化表 | 一律 `L` | `L["Reload UI"]` |
| 颜色 | token 字符串，不写裸色码 | `C.StringByTemplate(text, "rose-500")` |

## 错误处理

按「这个错该不该让调用者知道」选通道。

### 1. 加载期：宁可整体停摆，也不要半初始化

`Initialize.lua` 是唯一有资格中止加载的地方。三道闸门（EUI 存在 → compat 层存在 → `xpcall` 包住主初始化）任一失败就 `AbortWithMessage(message)` + `return`，并用 `InertStub()` 兜住后续文件要 unpack 的槽位。否则失败会变成「每个后续文件各报一次错」，一个字面量错误掩盖真正的根因。

新增「缺了就活不下去」的前置依赖，加进这道闸门，别在每个模块里各判一次。

### 2. 模块初始化与回调：失败只记日志，绝不互相阻断

统一入口是 `SafeCall`（`Core\Module.lua`、`Initialize.lua` 各一份，`Options\Core.lua` 另有 `addon.SafeCall`）：

```lua
local function SafeCall(func, ...)
	if type(func) == "function" then
		return xpcall(func, ErrorHandler, ...)
	end
end

-- 排干队列时逐个隔离
for _, func in next, object do
	xpcall(func, F.Developer.LogDebug, self)
end
```

`W:InitializeModules()` / `W:UpdateModules()` / `F.TaskManager` 的队列消费同理。新增生命周期钩子必须沿用这个形状：一个模块抛错不能带走别的模块，更不能带走整个 `PLAYER_LOGIN`。

### 3. 隔离一律 `xpcall`，不用裸 `pcall`

`pcall` 只回 `ok, err`，顺手把 `err` 丢掉就是藏错：日志永远进不了 BugSack，切配置档后某个模块一直报错你也不会知道。隔离回调一律给 handler：

```lua
xpcall(func, F.Developer.LogDebug, self, ...)   -- 这次没做成、下次还能好
xpcall(func, F.Developer.ThrowError, self, ...) -- 继续跑会产出错误数据
```

项目里没有全局的 `SafeCall`：`Core\Module.lua`、`Initialize.lua` 各有一份 `local SafeCall`，只有 `Options\Core.lua` 导出了 `addon.SafeCall`。在 `Modules\` 下直接用上面两行。

只有两种例外，别推广：

- **探测可选 API**：`pcall(fontString.SetFont, fontString, path, size)`、`pcall(EUI._chatCFD, chatFrame)`。失败本身就表示「这条能力不存在」，是合法分支 —— 但能写成 `if api then` 就写成 `if`。
- **轮询等待**：`F.SetCallback` / `F.WaitFor` 里的 `pcall(condition)` 表示「还没好，再试一次」，错误属于控制流。

已知不一致：`Core\Core.lua:190` 的 `pcall(module.ProfileUpdate, module)` 与同文件 `:170`/`:177` 的 `xpcall(..., F.Developer.LogDebug, module)` 是两种写法，按本条改掉。

### 4. 运行期热路径：守卫 + 静默 return + 一行原因

热路径不抛错。守卫顺序是「对象在 → 方法在 → 类型对 → 状态允许 → 不是 secret/forbidden」，命中就 return：

```lua
if not frame or not frame.GetName or not frame.GetAttribute then return end
if tt:IsForbidden() then return end
if E:IsSecretValue(unit) or not unit or not data or not data.guid then return end
```

要留排查线索时补一句 `LogDebug`，文案统一 `"函数名: 现象"`，例如 `F.Developer.LogDebug("Functions.SetFontWithDB: db not found")`（`Core\Functions\Core.lua:42`）。

**不要用 `assert` 做运行期守卫。** 它只允许出现在注册参数校验这类开发期入口（`Modules\Tooltips\Core.lua:47`）——注册期断言、执行期吞错。

### 5. 真正需要中断调用栈时才 `ThrowError`

只有致命错误与开发期误用才用。它走暴雪 `geterrorhandler()`，带插件名前缀与红色 `[ERROR]`，会真正抛栈：

```lua
_G.geterrorhandler()(format("%s |cffff2457[ERROR]|r\n%s", W.Title, message))
```

判据：继续跑会产出错误数据或静默错乱 → `ThrowError`；只是这次没做成、下次还能好 → 守卫 return + `LogDebug`。

### 日志分级

`LogDebug` / `LogInfo` / `LogWarning` 受 `E.global.WT.developer.logLevel` 控制（默认 `2`，warning 及以上），级别不够时第一行就 return。生产代码不用裸 `print`：聊天框输出走 `F.Print`（格式是 `W.Title: 内容`），要带绿色插件名前缀用 `addon.Print`（`Initialize.lua:155`）。

### 跨插件边界

凡代码会跑进别人的调用栈——hook 别人的生成路径、代理别人的全局表、在别人的 spawn 路径里回调——都必须 `xpcall` 包裹，错误不得外泄。`Modules\UnitFrames\QuickFocus.lua` 在 `__newindex` 里用 `xpcall(QF.TeardownFrame, geterrorhandler(), QF, frame)`，照做。

### 幂等与一次性注册

```lua
-- hook：项目的 SecureHook 已内置去重；绕过它直接 hooksecurefunc 时自己查
if not self:IsHooked(object, method) then ... end

-- 一次性初始化：布尔标记 + 立刻置位
if not W.UIErrorsFrame or self.uiErrorsHandlerRegistered then return end
self.uiErrorsHandlerRegistered = true

-- 模块 Initialize：入口判自身 initialized，末尾置位；关闭分支要复位
if self.initialized then return end
```

接管全局表前先礼让现有占用者（`QuickFocus.lua` 对 `_G.ClickCastFrames` 的检查），不要和 Clique / EllesmereUI 抢同一个表。

### 战斗锁定

- 战斗内不新建/改写受保护帧的锚点、属性、绑定。需要时**记标志位**、出战斗再消费：`QuickFocus` 用 `deferredClear` / `deferredRelease` / `deferredProfileUpdate` + 单一 `PLAYER_REGEN_ENABLED` handler。同一个事件重复注册会**静默替换**前一个 handler，这就是不各自注册的原因。
- 战斗外才能做的事走 `F.TaskManager:AfterCombat(fn, ...)` 或 `OutOfCombat(fn, ...)`，不要自己再注册 `PLAYER_REGEN_ENABLED`；登录后的一次性初始化走 `AfterLogin`。
- 不用 OnUpdate 轮询。等待用 `C_Timer` / `E:Delay` / 事件，重试带上限：`Modules\Tooltips\Core.lua:162` 用 `triedTimes <= 4` 加 `E:Delay(0.33, ...)`。

### 用户可见的错误反馈

弹窗集中在 `E.PopupDialogs.*`（`Core\Options.lua`），带 `whileDead = 1` / `hideOnEscape = 1`，空操作用 `E.noop`。UI 错误框的 handler 返回字符串 `"skip"` 表示吞掉该条消息（`Core\UIError.lua`），handler 本身用 `xpcall(handlerData.handler, F.Developer.ThrowError, params)` 隔离。

## 零成本原则

新增设置项默认 **OFF**，且「用户没开这个功能」时不得有任何开销：不注册事件、不挂 hook、无 ticker、无 OnUpdate、不建帧。改已上线的行为必须走 opt-in 开关；只有真正的 bug 修复才允许无开关地改变行为。

开关的实现是三处，缺一处就是漏成本：

1. `Initialize()` 首行 `if not E.db.WT.<page>.<feature>.enable then return end`；
2. `ProfileUpdate()` 里 `if self.db.enable then RegisterEvent(...) else UnregisterEvent(...) end`；
3. Mover / 皮肤这类外部注册传一个「是否应禁用」的闭包，例如 `E:CreateMover(..., function() return not E.private.WT.skins.enable or ... end, "WindTools,skins,uiErrors")`。

## 数据层级

| 库 | 全局变量 | 作用域 | 默认值定义在 |
|---|---|---|---|
| profile | `EllesmereUI_WindToolsDB` → `E.db.WT` | 每角色/配置档 | `Settings\Profile.lua` |
| global | `WindToolsGlobalDB` → `E.global.WT` | 战网账号 | `Settings\Global.lua` |
| private | `WindToolsPrivateDB` → `E.private.WT` | 本机角色 | `Settings\Private.lua` |

判据是「换角色/换配置档该不该继承」，不是「看起来像本机状态」——`/wtdebug` 的 `DisabledAddOns` 听着像本机状态，实际写在 global（`Core\Commands.lua:65`）。

新增字段要同时改默认值文件与读写处，旧字段迁移写进 `Core\Update.lua` 的版本区间分支（`if privateVersion <= 2.33 then` 那种）。

选项页里不要直接写 `E.db.WT.x`，用 `Options\Core.lua:71-99` 的 `DBGet` / `DBSet` / `DBGet2` / `DBSet2` 闭包工厂。setter **不会**自动刷新界面，它只调调用方传进去的 `after`；要通知 EllesmereUI 设置已变，在同一个文件里调用 `MarkSettingsChanged()`（`Options\Core.lua:101` 的 local 函数，未导出）。

## 本地化

- 文案一律 `L["..."]`，不在源码里写死句子。
- `Locales\` 下文件由 WindToolsScripts 生成，**不要手改**；新 key 同时提供 enUS 与 zhCN。
- 取不到本地化表时降级而不是报错：`local function L(text) return EUI and EUI.L and EUI.L(text) or text end`（`Initialize.lua:8-10`）。

## 变更记录与版本

- 新版本 = 在 `Core\Changelog\` 新建 `<x.y.z>.lua`，照 `_template.lua` 填，表键是去掉小数点的数值版号（`0.2.8` → `W.Changelog[208]`），然后重新生成 `CHANGELOG.md`（`generate_changelog.py`）。**不要手写 CHANGELOG.md。**
- 版本号只在正式发布时递增，同步 `.toc` 的 `## X-Version` 与 `README*.md` 的 badge。日常开发不要动版本号。

## 打包

CI 用 `BigWigsMods/packager` 读 `.pkgmeta` 打包；本地用 `package.ps1`，按它的默认发布流程实现：

```
pwsh -File .\package.ps1                  # 开发版，如 .release\EllesmereUI_WindTools-0.2.8-8b28c90.zip
pwsh -File .\package.ps1 -Release         # 正式版，如 EllesmereUI_WindTools-0.2.8.zip
pwsh -File .\package.ps1 -KeepStaging     # 顺手留下暂存目录，用来核对包里到底有什么
pwsh -File .\package.ps1 -Version 0.3.0   # 把版本号定死，不看 tag、不拼 hash
```

默认是开发版：基础号取 `.toc` 的 `## X-Version`，后面拼 `-<短 hash>`，即 `0.2.8-8b28c90`。只有 `-Release` 才出干净版本号，此时工作区脏了会告警。

zip 内顶层是 `EllesmereUI_WindTools\`，`## Version: @project-version@` 会替换成实际版本，`--@do-not-package@` 段会被删掉。以点开头的文件和目录一律不进包，其余排除项看 `.pkgmeta` 的 `ignore` —— 新增根目录的工具文件（脚本、文档）记得补进去，否则会被打进包里。

## 红线

- 迁移上游代码时保留 `CREDITS.md` 归属。
- 不写版本号分支来「兼容旧客户端」。TOC 同时声明 `120105` 与 `16001`，只能用两端都存在的 API：优先 `C_` 形式，对确实可能缺失的全局做能力守卫，而不是 `if version then`。
- 不在 hook 回调入口直接干活：先判 `initialized` 与 `IsForbidden`。

## 维护这份文档

每条规则都对应代码里一个真实样板，路径写在条目里。review 纠正了一类错误而这规则还没写进来，就补进来并附上可抄的路径；规则依赖的实现被删除或重写，就一并更新。文档保持短——说不清、执行不了的规则不如没有。
