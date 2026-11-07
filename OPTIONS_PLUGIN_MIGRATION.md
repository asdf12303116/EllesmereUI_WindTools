# 选项面板迁移计划：自绘面板 -> EllesmereUI RegisterPlugin

状态：规划完成，代码未动。
目标仓库：`C:\Dev\workspace\Wow\EllesmereUI_WindTools`
参考实现：`C:\Dev\workspace\Wow\Ref\EllesmereUI`（含 `PLUGINS_API.md`、`EllesmereUI_Panel.lua`）

---

## 1. 目标与已定决策

把 WindTools 现在这套自绘选项面板（侧边栏 / 搜索 / 页脚全部自己画）废弃，改为
通过 `EllesmereUI.RegisterPlugin` 注册进 EllesmereUI 自己的选项面板，成为它的一个
sidebar section。

已确认的两项决策：

| 决策点 | 结论 | 理由 |
|---|---|---|
| 接入方式 | 完全迁移，删掉自绘面板 | 用户选择。长期只维护一套 UI，避免两个面板都要跟随 EUI 改动。 |
| 模块划分 | 按现有侧边栏 7 组切，每组一个模块、组内页面做标签页 | 用户选择。`RegisterPlugin` 上限是单插件 20 个模块、单模块 20 页，现有 28 页若一页一模块会超限。7 组正好对上 `Initialize.lua` 的 `SIDEBAR_GROUPS`。 |

不可违反的既有约束（来自 `AGENTS.md`）：

- 不引入新依赖，不改 `Libraries\`。
- 不写版本号分支来兼容旧客户端；TOC 同时声明 `120105` 与 `16001`，只用两端都存在的 API。
- 不手改 `Locales\`（本轮若需新文案，先提出来单独处理）。
- 迁移上游代码保留 `CREDITS.md` 归属。
- 热路径守卫顺序「对象在 -> 方法在 -> 类型对 -> 状态允许 -> 不是 secret/forbidden」；运行期不用 `assert`。

---

## 2. 现状核查（已实测，可直接引用）

### 2.1 自绘面板规模

`Options\Panel.lua` 共 1402 行，自建根 frame、侧边栏滚动列表、内容滚动区、
搜索框、页脚、关闭按钮。对外暴露的入口：

- `W:ShowOptions(page)` `Options\Panel.lua:1318`
- `W:HideOptions()` `Options\Panel.lua:1375`
- `W:ToggleOptions(page)` `Options\Panel.lua:1381`
- `W:RefreshOptions(force)` `Options\Panel.lua:1391`
- `addon.RefreshOptions(force)` `Options\Panel.lua:1396`
- `addon.RefreshSidebarStates()` `Options\Panel.lua:1400`

`Options\Panel.lua:66-117` 的 `PageEnableConfig` 实现「侧边栏电源图标 + 置灰」，
覆盖 12 个页面（Extra Items Bar / Announcement / Chat Bar / Smart Tab / Game Bar /
Super Tracker / World Map / Objective Tracker / Inspect / Item Level / Progression）。
`Options\Panel.lua:136-148` 的 `PAGE_MODULES` + `IsPageAvailable` 决定页面可用性。

### 2.2 页面与分组

`Initialize.lua:189-253` 的 `PAGE_GROUPS` 共 28 页：

- 特殊页 `SPECIAL_PAGES = { "Information", "Advanced" }`（`Initialize.lua:269`）
- 分组页 26 个，`Initialize.lua:273-281` 的 `SIDEBAR_GROUPS` 分 7 组

`Initialize.lua:286-313` 的 `BuildPage(pageName, parent, yOffset)` 按
`GROUP_BY_PAGE[pageName].categories` 依次调用 `addon.OptionBuilders[categoryKey]`，
第 4 参传 `pageName` 作为 `subPage`。

各 category builder 的注册点（`addon.RegisterOptionBuilder(categoryKey, fn)`，
定义在 `Options\Core.lua:21-23`）：

| categoryKey | 文件:行 |
|---|---|
| information | `Options\Information.lua:5` |
| advanced | `Options\Advanced.lua:14` |
| misc | `Options\Misc.lua:132`（带 `subPage` 分片） |
| item | `Options\Item.lua:271`（带 `subPage`） |
| extraItemsBar | `Options\ExtraItemBar.lua:103` |
| announcement | `Options\Announcement.lua:41` |
| combat | `Options\Combat.lua:244` |
| social | `Options\Social.lua:209`（带 `subPage`） |
| maps | `Options\Maps.lua:175`（带 `subPage`） |
| quest | `Options\Quest.lua:230`（带 `subPage`） |
| tooltips | `Options\Tooltips.lua:172`（带 `subPage`） |
| unitFrames | `Options\UnitFrames.lua:120` |
| skins | 无（`Options\Skins.lua` 全文 1 行占位注释） |

`Options\Skins.lua` 目前是 1 行占位，但 `Initialize.lua:250` 仍声明了
`page = "Skins"`，迁移时该页会渲染成空白页，需要一并处理（见 5.6）。

### 2.3 加载顺序

`Options\Load_Options.xml` 共 17 行，`Panel.lua` 在最后（第 16 行）。TOC 里
`Options\Load_Options.xml` 位于 `Settings\Load_Settings.xml` 之后、
`Modules\Load_Modules.xml` 之前，即所有 builder 在模块加载前就已注册。

### 2.4 现有入口调用点

| 位置 | 当前行为 |
|---|---|
| `Core\Commands.lua:106-118` | `/wt`、`/windtools`、`/ewt` 调 `W:ToggleOptions(page)` |
| `Core\CompatE.lua:297-306` | `E:ToggleOptions(path)` 转发到 `wt:ToggleOptions(path)`，接受逗号路径 |
| `Core\Core.lua:49` | `E:ToggleOptions("WindTools,information,changelog")` |
| `Initialize.lua:331-356` | `RegisterBlizzardOptionsEntry()` 在设置-插件里放一个按钮，回调 `W:ToggleOptions()` |
| `Initialize.lua:379-385` | `_G.WindTools_OnAddonCompartmentClick` 调 `W:ToggleOptions()` |
| `Modules\Datatexts\MicroMenu.lua:79,82` | 调 `E:ToggleOptions()`（该模块未接入加载链） |
| `Modules\Skins\ElvUI\Option.lua:34` | `self:SecureHook(E, "ToggleOptions", "ElvUI_SkinOptions")`（该模块未接入加载链） |

### 2.5 面板之外的依赖

- `Options\ExtraItemBar.lua:311-313,326` 调 `addon.InvalidateContentHeaderCache()` /
  `addon.SetContentHeader(_headerBuilder)` / `addon.RefreshOptions(true)`。
- `Options\Social.lua:46`、`Options\ExtraItemBar.lua:114` 直接遍历
  `EllesmereUI._widgetRefreshList` 手动重绘控件。
- `Options\Core.lua:101-103` 的 `MarkSettingsChanged()` 直接写
  `EllesmereUI._settingsChanged = true`。
- `Options\Core.lua:57-69` 在文件加载期安装了一个 `Widgets.Dropdown` 参数兼容垫片。
- 其余 `addon.RefreshOptions()` 调用遍布 `Options\Combat.lua:40`、
  `Options\UnitFrames.lua:25`、`Options\ExtraItemBar.lua` 十余处。

### 2.6 Widget 方法可用性（已逐个比对，无缺口）

WindTools 用到的 8 个方法全部由 EUI 定义：

| 方法 | 定义位置 |
|---|---|
| `SectionHeader` | `Ref\EllesmereUI\EllesmereUIOptions\EllesmereUI_Widgets.lua:2105` |
| `Toggle` | `Ref\EllesmereUI\EllesmereUIOptions\EllesmereUI_Widgets.lua:2353` |
| `Slider` | `Ref\EllesmereUI\EllesmereUIOptions\EllesmereUI_Widgets.lua:2378` |
| `Dropdown` | `Ref\EllesmereUI\EllesmereUIOptions\EllesmereUI_Widgets.lua:2399` |
| `Checkbox` | `Ref\EllesmereUI\EllesmereUIOptions\EllesmereUI_Widgets.lua:2433` |
| `DualRow` | `Ref\EllesmereUI\EllesmereUIOptions\EllesmereUI_Widgets_Rows.lua:340` |
| `Spacer` | `Ref\EllesmereUI\EllesmereUIOptions\EllesmereUI_Widgets_Rows.lua:1524` |
| `Button` | `Ref\EllesmereUI\EllesmereUIOptions\EllesmereUI_Widgets_Rows.lua:106` |
| `ColorPicker` | `Ref\EllesmereUI\EllesmereUIOptions\EllesmereUI_Widgets_Color.lua:971` |

`EllesmereUI.Widgets = WidgetFactory` 的赋值在
`EllesmereUI_Widgets.lua:2092`，而 `EllesmereUI.Widgets` 在搜索预构建期间会被临时
换成 `AbsorberW`（`EllesmereUI_GlobalSearch.lua:720`）。所有 builder 都在函数体内
`local Widgets = EllesmereUI.Widgets`（已逐个文件确认，无文件级捕获），因此天然兼容。

---

## 3. RegisterPlugin API 事实（照抄依据）

完整文档：`Ref\EllesmereUI\PLUGINS_API.md`。`EllesmereUI.PLUGIN_API_VERSION = 5`
（`EllesmereUI_Panel.lua:5638`）。

### 3.1 注册

```lua
EllesmereUI.RegisterPlugin(id, spec) -> boolean
```

定义在 `Ref\EllesmereUI\EllesmereUI_Panel.lua:5822`。校验失败返回 `false`，原因经
`ReportError` 输出为 `EllesmereUI.RegisterPlugin(<id>): <原因>`，不会注册任何东西。

- `id`：`^%a[%w_%-]*$`，最长 40 字符（`ValidId`，`EllesmereUI_Panel.lua:5705`）
- `spec.label`：侧边栏 section 标题，最长 32 字符，纯文本（`PlainText` 会剥掉
  `|T`/`|A`/`|K`/`|H`/`|c`/`|cn`/`|r`/`|n` 与所有控制字符）
- `spec.position`：`"bottom"`（默认）或 `"top"`
- `spec.modules`：1..20 个模块 spec
- 保留 label（`IsReservedLabel`，`EllesmereUI_Panel.lua:5692`）：以 `ellesmere` 或
  `eui` 开头的、以及 `Global Settings` / `Profiles` / `Patch Notes` / `EUI Legends`
  与 EUI 自身分组名（任何语言）

### 3.2 模块 spec

| 字段 | 必填 | 约束 |
|---|---|---|
| `key` | 是 | 同 `id` 格式，插件内唯一 |
| `title` | 是 | 侧边栏行文与面板标题，最长 48 字符，走 `PlainText` |
| `description` | 否 | 标题下的一行，允许颜色代码，最长 300 字符 |
| `pages` | 是 | 1..20 个不重复页名，纯文本，禁止含 `|` 或控制字符 |
| `buildPage(pageName, parent, yOffset)` | 是 | 在 `parent` 上从 `yOffset`（负数，自上而下）开始构建；返回内容总高度（正数） |
| `getHeaderBuilder(pageName)` | 否 | 返回 `function(headerFrame, width) -> height`，在滚动区上方画固定头部 |
| `onPageCacheRestore(pageName)` | 否 | 缓存页重新显示时回调 |
| `onReset()` | 否 | 启用页脚 Reset 按钮，在此重置本模块设置 |
| `onModuleLeave()` | 否 | 切走该模块时回调 |
| `searchPrebuild` | 否 | `false` 让该模块不参与搜索的隐藏预构建；默认 `true` |

模块完整 key 为 `"plugin:<id>:<moduleKey>"`，用
`EllesmereUI.GetPluginModuleKey(id, moduleKey)` 取回。

### 3.3 其它可用函数

| 函数 | 位置 |
|---|---|
| `EllesmereUI.OpenPlugin(id [, moduleKey [, pageName]]) -> boolean` | `EllesmereUI_Panel.lua:5890` |
| `EllesmereUI.GetPluginModuleKey(id, moduleKey)` | `EllesmereUI_Panel.lua:5883` |
| `EllesmereUI.IsPluginRegistered(id)` | `EllesmereUI_Panel.lua:5869` |
| `EllesmereUI.IsSearchPrebuild() -> boolean` | `EllesmereUI_Panel.lua:5876` |
| `EllesmereUI:Show()` / `:Hide()` / `:Toggle()` / `:IsShown()` | `EllesmereUI_Panel.lua:5402 / 5416 / 5417 / 5441` |
| `EllesmereUI:ShowModule(folderName)` | `EllesmereUI_Panel.lua:5600` |
| `EllesmereUI:SelectPage(pageName)` | `EllesmereUI_Panel.lua:4740` |
| `EllesmereUI:RefreshPage(force)` | `EllesmereUI_Panel.lua:4924` |
| `EllesmereUI:InvalidateModulePageCache(moduleName)` | `EllesmereUI_Panel.lua:4500` |
| `EllesmereUI:GetActiveModule()` | `EllesmereUI_Panel.lua:5012` |
| `EllesmereUI:SetContentHeader(buildFunc)` | `EllesmereUI_Panel.lua:2866` |
| `EllesmereUI:SetContentHeaderHeightSilent(h)` | `EllesmereUI_Panel.lua:2928` |
| `EllesmereUI:InvalidateContentHeaderCache()` | `EllesmereUI_Panel.lua:2972` |
| `EllesmereUI.RegisterWidgetRefresh(fn)` | `EllesmereUI.lua:1085-1088` |
| `EllesmereUI.CONTENT_PAD` | `EllesmereUI_Widgets.lua:2094` |

`EllesmereUI:RefreshPage` 在面板隐藏时会推迟（置 `_pendingFastRefresh` 或
`_pendingForceRefresh`，`EllesmereUI_Panel.lua:4936-4949`），且 `activeModule` 或
`activePage` 为空时直接 `return`（`:4925`）。

`EllesmereUI.OpenPlugin` 在战斗中直接拒绝并 `EllesmereUI.PrintError("Cannot open options during combat.")`
（`EllesmereUI_Panel.lua:5896-5899`）。

### 3.4 插件被限制的行为

- 只能新建自己的 section，不能给 EUI 的模块加页、加行或替换页。
- 插件页不参与 EUI profile、profile 同步、spec/条件覆盖。
- 标签一律纯文本，仿冒 EUI 自身条目的 label 被拒绝。
- 注册是快照，注册后再改 spec 表无效。
- 回调全部包在 `xpcall` 里（`Guard`，`EllesmereUI_Panel.lua:5709`），出错只上报不打断面板。
- 文档明确要求：`buildPage` 在 `EllesmereUI.IsSearchPrebuild()` 为真时跳过副作用
  （注册事件、hook、计时器、预览、碰自己的实际 frame）。

### 3.5 搜索预构建的桩工厂

预构建期间 `EllesmereUI.Widgets` 被换成 `AbsorberW`
（`EllesmereUI_GlobalSearch.lua:586`），已实现 18 个方法：
`SectionHeader`(587)、`Toggle`(592)、`Slider`(596)、`Dropdown`(600)、`Checkbox`(604)、
`ColorPicker`(608)、`Button`(612)、`WideButton`(616)、`DualRow`(620)、`TripleRow`(628)、
`MultiSwatchRow`(634)、`DropdownWithOffsets`(638)、`WideDualButton`(644)、
`WideTripleButton`(649)、`WideDropdown`(655)、`TripleDropdown`(659)、`TripleSlider`(665)、
`Spacer`(670)。

任何字符串键返回另一个吸收器，任何方法调用空转，对吸收器做算术得到普通数字，
数字键返回 `nil`。builder 自己直接 `CreateFrame` 的部件会真的建在复用的隐藏 wrapper 上。

---

## 4. 目标结构

`id = "EllesmereUI_WindTools"`（文档要求用插件文件夹名），
`label = "WindTools"`，`position = "bottom"`。

| # | module key | title | pages（标签页，按序） |
|---|---|---|---|
| 1 | `General` | General | General, Game Bar, Information, Advanced |
| 2 | `Items` | Items | Loot & Trade, Display, Inspect, Item Level, Merchant, Extra Items Bar |
| 3 | `Combat` | Combat | Combat |
| 4 | `Social` | Social | Chat Bar, Smart Tab, Announcement |
| 5 | `Maps` | Maps | Super Tracker, Minimap, World Map, Difficulty & Events |
| 6 | `Quest` | Quest | Objective Tracker, Automation, Progress & Turn In, Achievement |
| 7 | `UITweaks` | UI Tweaks | Tooltip Info, Progression, Keystone & Group Info, Tooltip Advanced, Unit Frames, Skins |

合计 7 模块 / 28 页，全部在限制内（模块 <= 20，页 <= 20）。

几点说明：

- 原 `SPECIAL_PAGES` 里的 `Information` 与 `Advanced` 在插件模型下没有「顶部特殊按钮」
  这个概念，收进 `General` 模块当标签页，避免多开一个只有 2 页的模块。
- `Skins` 页保留占位（对应 `Options\Skins.lua`），迁移后仍会渲染成空白页，见 5.6。
- module key 用 `UITweaks` 而非 `UI Tweaks`，因为 `key` 必须匹配 `^%a[%w_%-]*$`，
  空格不合法；`title` 才写 `UI Tweaks`。

---

## 5. 实施步骤

### 5.1 新增 `Options\Plugin.lua`（注册与调度层）

职责：

1. 定义第 4 节的 7 模块 spec，`buildPage` 全部转发到现有的
   `addon.BuildOptionsPage(pageName, parent, yOffset)`。
2. 提供 `addon.RegisterOptionsPlugin()`，在 `PLAYER_LOGIN` 之后调用一次；
   内部只在 `EllesmereUI.RegisterPlugin` 存在时调用，返回 `false` 时通过
   `addon.Print` 记录原因。
3. 导出 `addon.OpenOptionsPlugin(pageName)` / `addon.RefreshOptionsPlugin(force)`，
   供入口层调用。
4. 反向索引 `pageName -> moduleKey`，`OpenPlugin` 需要它。

`buildPage` 的形状（示意）：

```lua
buildPage = function(pageName, parent, yOffset)
    return addon.BuildOptionsPage(pageName, parent, yOffset)
end,
```

不在这里做 `EllesmereUI.IsSearchPrebuild()` 判断，判断下沉到各 builder（见 5.4）。

加载链改动：`Options\Load_Options.xml` 在 `Panel.lua` 之前插入
`<Script file='Plugin.lua'/>`（第 1 步先并存，第 3 步再删 `Panel.lua`）。

### 5.2 入口层统一

| 文件:行 | 改法 |
|---|---|
| `Core\Commands.lua:106-118` | 保留 `/wt` `/windtools` `/ewt`，把 `W:ToggleOptions(page)` 换成新入口；`page` 参数支持页名与模块 key 两种写法 |
| `Core\CompatE.lua:297-306` | `E:ToggleOptions(path)` 解析 `"WindTools,information,changelog"` 这类逗号路径后转发新入口 |
| `Core\Core.lua:49` | 路径改成迁移后的页名（`information` 现在属于 `General` 模块） |
| `Initialize.lua:331-356` | `RegisterBlizzardOptionsEntry` 的按钮回调改新入口 |
| `Initialize.lua:379-385` | `WindTools_OnAddonCompartmentClick` 改新入口 |
| `Initialize.lua:362-370` | `PLAYER_LOGIN` 里在 `SafeCall(W.InitializeModules, W)` 之后加一次 `addon.RegisterOptionsPlugin()` |

`W:ToggleOptions` / `W:ShowOptions` / `W:HideOptions` 保留为兼容外壳，内部转调
`EllesmereUI.OpenPlugin` / `EllesmereUI:Show()` / `EllesmereUI:Hide()`，这样
`Modules\Datatexts\MicroMenu.lua`、`Modules\Skins\ElvUI\Option.lua` 这两个未接入加载链
的模块不需要改也不会在将来炸。

### 5.3 删掉自绘面板

删除 `Options\Panel.lua` 全文 1402 行与 `Options\Load_Options.xml` 里的登记。
迁移前必须把下面这些还活着的符号挪到别处：

| 符号 | 现位置 | 迁到 |
|---|---|---|
| `addon.RefreshOptions(force)` | `Options\Panel.lua:1396` | `Options\Plugin.lua`，实现为 `EllesmereUI:RefreshPage(force)` |
| `addon.RefreshSidebarStates()` | `Options\Panel.lua:1400` | 直接删除；EUI 侧边栏自行维护状态，无调用点保留 |
| `PageEnableConfig` / `IsPageEnabled` / `IsPageAvailable` / `PAGE_MODULES` | `Options\Panel.lua:66-157` | 删除，见 5.5 |
| `W:ShowOptions` / `HideOptions` / `ToggleOptions` / `RefreshOptions` | `Options\Panel.lua:1318-1393` | `Options\Plugin.lua`，转调 EUI |
| `ResolvePage` | `Options\Panel.lua:1281-1310` | `Options\Plugin.lua`，改写成页名/模块名解析 |
| `addon.RefreshSidebarStates` 的调用方 | 无（仅 `Panel.lua` 内部） | 无需处理 |

`Initialize.lua:316-321` 导出的 `addon.OptionPageGroups` /
`OptionPageNames` / `OptionGroupByPage` / `SpecialPages` / `SidebarGroups` /
`BuildOptionsPage` 中，除 `BuildOptionsPage` 外的消费者只有 `Panel.lua`
（`Panel.lua:470,475,570,760,925,1284,1344`）。`Panel.lua` 删除后这些导出可以只留
`BuildOptionsPage` 与 `OptionPageNames`（后者给 `/wt` 的页名解析用）。

### 5.4 搜索预构建适配

现状：全部 builder 都在函数体内取 `local Widgets = EllesmereUI.Widgets`，因此
`AbsorberW` 能正常替换。风险在 builder 里直接建帧或注册副作用的地方：

- `Options\ExtraItemBar.lua:298-326` 的 `_headerBuilder` 与 `BuildLivePreview`
- `Options\Combat.lua` 的战斗提醒预览
- `Options\Misc.lua` 的 Game Bar 图标预览

对策（按代价从低到高）：

1. 这些页面在 spec 上标 `searchPrebuild = false`，搜索只在用户实机打开过一次后才收录。
   代价最小，建议先这样做。
2. 或者在 builder 开头加 `if EllesmereUI.IsSearchPrebuild() then ... end` 跳过硬部件。
   只在确实需要「未打开也能搜到」时才做。

先全部标 `searchPrebuild = false`，验证无 BugSack 后再逐页放开，避免一次性引入
一堆 prebuild 崩溃。

### 5.5 侧边栏电源图标功能的下线

`PageEnableConfig` 在插件模型下无法保留：插件只能有自己的 section 与行，不能给行加
电源图标或置灰态。替代方案：

- 每个模块首页顶部放一个 `Widgets:Toggle(parent, "Enable", ...)`。
  现有 builder 里多数已有页内 Enable 开关（`Options\Misc.lua:374`、
  `Options\ExtraItemBar.lua:408`、`Options\Item.lua:158,179`、
  `Options\UnitFrames.lua:51,78`、`Options\Social.lua` 的 Chat Bar 段等）。
- 需要逐个核查没有页内 Enable 的页面，补上：Announcement、Super Tracker、
  World Map、Objective Tracker、Progression。
- 顶层模块启用状态本来就没有对应 DB 字段，不新增（零成本原则：新设置项默认 OFF 且
  必须有开关三处齐全才加）。

### 5.6 `Skins` 空页

`Options\Skins.lua` 是 1 行占位，`Initialize.lua:250` 仍声明了 `page = "Skins"`。
两个选择：

- 从 `PAGE_GROUPS` 与 `UI Tweaks` 模块的 `pages` 里移除（推荐，避免空白标签页）。
- 或者在 `Options\Skins.lua` 里写一个「尚未移植」的说明页。

### 5.7 content header 迁移

`Options\ExtraItemBar.lua` 现在用 `addon.SetContentHeader(_headerBuilder)`
（`:326`）与 `addon.InvalidateContentHeaderCache()`（`:311`）。迁移到
`getHeaderBuilder`：

```lua
getHeaderBuilder = function(pageName)
    if pageName == "Extra Items Bar" then
        return addon.ExtraItemsBarHeader
    end
end,
```

`:326` 的 `addon.SetContentHeader(_headerBuilder)` 删除；`:311-313` 的
`InvalidateContentHeaderCache` + `SetContentHeader` + `RefreshOptions(true)` 三连
简化为 `EllesmereUI:InvalidateContentHeaderCache()` + `EllesmereUI:RefreshPage(true)`
（或保留 `addon.RefreshOptions(true)` 外壳）。

`Options\Core.lua:107-117` 现在的 `pcall` 包装可以保留（无害），但目标实现变为
EUI 的真实函数。

### 5.8 内部字段访问的合规化

插件 API 文档明确「以 `_` 开头的字段是内部字段，可能随时改动或消失」。当前有 3 处：

| 位置 | 现状 | 改法 |
|---|---|---|
| `Options\Core.lua:102` | `EllesmereUI._settingsChanged = true` | 无公开替代。保留并加注释说明这是 profile 脏标记；风险记录在案，EUI 改字段名时只影响「未保存提示」，不影响功能。 |
| `Options\ExtraItemBar.lua:114` | 遍历 `EllesmereUI._widgetRefreshList` | 改为在 builder 内用 `EllesmereUI.RegisterWidgetRefresh(fn)` 注册自己那一份刷新闭包，不再手动遍历。 |
| `Options\Social.lua:46` | 同上 | 同上。 |

### 5.9 Dropdown 垫片的加载时序问题

`Options\Core.lua:57-69` 在**文件加载期**取 `_G.EllesmereUI.Widgets` 并替换
`Widgets.Dropdown`。但 EUI 的 `EllesmereUI.Widgets = WidgetFactory` 要等
`EllesmereUIOptions` 加载（`EllesmereUI_Widgets.lua:2092`），而 `EllesmereUIOptions`
只在玩家第一次打开 EUI 面板时才加载。所以在 WindTools 的 `Options\Load_Options.xml`
执行时 `EllesmereUI.Widgets` 大概率还是 `nil`，垫片根本没装上。

由于 9 处 legacy 顺序调用已在上一轮全部改成原生顺序（`Options\Misc.lua:123,287,431,449,536,544,577,601`、
`Options\Core.lua:838,839` 本来就是正确顺序），垫片可以删除。要保留的话必须改成
延迟安装（第一次 `buildPage` 时再装）。

### 5.10 文案与 locale

迁移本身预计不需要新词条：section label 用 `WindTools`，模块 title 与页名全部复用
现有的类别名与页名（`Initialize.lua:172-186` 的 `CATEGORY_TITLES` 与
`PAGE_GROUPS` 的 `page` 字段）。若最终决定给新模块标题加 `L[...]`，需要单独提交并
遵守 `Locales\` 的生成流程。

---

## 6. 已知风险

| 风险 | 影响 | 对策 |
|---|---|---|
| `BuildPage` 返回的总高度若与 EUI 期望不符，页面底部会多出或裁掉空白 | 观感 | `BuildPage` 已返回 `math.abs(y) + 30`（`Initialize.lua:312`），与 EUI 自带页一致；迁移后逐页目视核对首尾两页 |
| 搜索预构建期间 builder 的副作用（建帧、计时器） | 内存泄漏、隐藏帧 | 全部 `searchPrebuild = false` 起步，再逐页放开（5.4） |
| `EllesmereUI:RefreshPage` 在面板隐藏时推迟刷新 | 关闭面板后改 DB 不立刻重绘 | 可接受：面板不可见时无需重绘；重新打开会走 `_pendingFastRefresh` |
| 战斗内 `OpenPlugin` 被拒绝 | `/wt` 在战斗中不再打开面板 | 与 EUI 自身行为一致，可接受；`Commands.lua` 里加一句提示 |
| 删除 `Panel.lua` 后 `W:RefreshOptions` 若被遗漏调用会静默失效 | 部分选项不刷新 | 保留 `W:RefreshOptions` 兼容外壳，内部转 `EllesmereUI:RefreshPage` |
| 页面电源图标功能消失 | 少一个快捷开关 | 页内 Enable 开关已覆盖大多数；缺的 5 页补上（5.5） |
| `EllesmereUI._prebuilding` / `_widgetRefreshList` / `_settingsChanged` 属内部字段 | EUI 改版可能失效 | 5.8 逐项处理，`_settingsChanged` 接受风险并记录 |

回滚：迁移分 4 个独立提交（见第 8 节），任意一步可单独 revert；`Panel.lua` 删除是
最后一步，此前自绘面板一直可用。

---

## 7. 验收清单

进游戏后逐项确认：

- [ ] `/wt` 打开 EllesmereUI 面板并停在 WindTools 的 General 模块
- [ ] 侧边栏出现 `WindTools` section，位于 EUI 自身所有分组之下，共 7 行
- [ ] 7 个模块逐行点开，28 个标签页逐页可打开，无 BugSack
- [ ] Extra Items Bar 页顶部的 bar 选择器与实时预览正常（content header）
- [ ] 切换 bar 后页面重建、预览同步更新
- [ ] 侧边栏搜索框输入 `game bar` 能命中 WindTools 的行并可跳转高亮
- [ ] 战斗内 `/wt` 提示不能打开，不报错
- [ ] 插件隔间（AddonCompartment）点击同样打开到 WindTools
- [ ] 设置 - 插件 - WindTools 里的按钮同样打开到 WindTools
- [ ] `/reload` 后重开面板，section 与 7 行仍在，且没有点名本插件的「需要更新」弹窗
- [ ] 每个模块的 Enable 开关切一次，对应模块行为与页面禁用态正确
- [ ] 页脚 Reset 按钮（若启用 `onReset`）能重置且页面刷新

不进游戏也能做的静态检查：

- `cd 'C:\Dev\workspace\Wow\.lua-check'; node check.mjs <改动文件>`（luaparse 5.1）
- `stylua .` 与 `luacheck .`（本机未安装，需另跑）

---

## 8. 提交拆分

按可独立回滚的顺序：

1. `feat(options): register the settings pages through the EllesmereUI plugin API`
   新增 `Options\Plugin.lua`、改 `Options\Load_Options.xml`、改 `Initialize.lua`
   （注册调用 + 入口转调）。此时自绘面板仍在，两条路并存可对比。
2. `refactor(options): route every entry point through OpenPlugin`
   `Core\Commands.lua`、`Core\CompatE.lua`、`Core\Core.lua`、Blizzard 设置入口、
   插件隔间。
3. `refactor(options): drop the standalone options panel`
   删除 `Options\Panel.lua`、清理 `Options\Load_Options.xml`、修剪 `Initialize.lua`
   的页面元数据导出。
4. `chore(build): ignore the panel migration plan`（`.pkgmeta` 加
   `OPTIONS_PLUGIN_MIGRATION.md`）

若第 1 步验证不通过，直接放弃并停在第 0 步，不产生副作用。

---

## 9. 明确不做的事

- 不引入新依赖，不打包 EUI 的任何库。
- 不写 `GetBuildInfo` 版本分支；TOC 继续只声明 `120105, 16001`。
- 不改 `Locales\`（除非第 5.10 节最终确认需要新词条，那时单独开一轮）。
- 不动 README 迁移进度表以外的模块状态（`选项面板(独立)` 一行在第 3 步提交里
  改为「选项面板(并入 EllesmereUI)」）。
- 不重构各 builder 的内部实现；只改它们与面板之间的接口。
- 不给未移植模块补开关（`E.private.WT` 那些死设置保持原样）。
