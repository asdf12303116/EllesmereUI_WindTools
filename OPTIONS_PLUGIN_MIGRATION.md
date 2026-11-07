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
| 模块划分 | 按现有侧边栏 7 组切，每组一个模块、组内页面做标签页 | 用户选择。`RegisterPlugin` 上限是单插件 20 个模块、单模块 20 页，迁移前 28 页若一页一模块会超限。7 组正好对上 `Initialize.lua` 的 `SIDEBAR_GROUPS`。 |

不可违反的既有约束（来自 `AGENTS.md`）：

- 不引入新依赖，不改 `Libraries\`。
- 不写版本号分支来兼容旧客户端；TOC 同时声明 `120105` 与 `16001`，只用两端都存在的 API。
- 不手改 `Locales\`（本轮若需新文案，先提出来单独处理）。
- 迁移上游代码保留 `CREDITS.md` 归属。
- 热路径守卫顺序「对象在 -> 方法在 -> 类型对 -> 状态允许 -> 不是 secret/forbidden」；运行期不用 `assert`。

---

## 2. 现状核查（已实测，可直接引用）

### 2.1 自绘面板规模（已删除，保留记录）

`Options\Panel.lua` 原有 1402 行，自建根 frame、侧边栏滚动列表、内容滚动区、
搜索框、页脚、关闭按钮。它对外暴露的入口已全部消失：

- `W:ShowOptions(page)` `Options\Panel.lua:1318`
- `W:HideOptions()` `Options\Panel.lua:1375`
- `W:ToggleOptions(page)` `Options\Panel.lua:1381`
- `W:RefreshOptions(force)` `Options\Panel.lua:1391`
- `addon.RefreshOptions(force)` `Options\Panel.lua:1396`
- `addon.RefreshSidebarStates()` `Options\Panel.lua:1400`

`Options\Panel.lua:66-117` 的 `PageEnableConfig` 实现「侧边栏电源图标 + 置灰」，
覆盖 11 个页面（Extra Items Bar / Announcement / Chat Bar / Smart Tab / Game Bar /
Super Tracker / World Map / Objective Tracker / Inspect / Item Level / Progression），
已由每页页内的 `Enable` 开关取代（见 5.5）。
`Options\Panel.lua:136-148` 的 `PAGE_MODULES` + `IsPageAvailable` 决定页面可用性，
随面板一并删除——页面可用性现在由 EUI 的页面列表决定，未实现的控件靠
`DualRow` 的 `disabled` 置灰（见第 9 节）。

### 2.2 页面与分组

迁移前 `Initialize.lua` 的 `PAGE_GROUPS` 共 28 页；移除 `Skins` 后为 **27 页**，
页面结构现在只由 `Options\Plugin.lua` 的 `MODULES` 描述一份：

- 特殊页 `Information` 与 `Advanced` 在迁移前走 `SPECIAL_PAGES`，现在分别并入
  `General` 模块的标签页。
- 分组页按 7 个模块组织，与旧 `SIDEBAR_GROUPS` 的 7 组一一对应。

`Initialize.lua` 的 `BuildPage(pageName, parent, yOffset)` 按
`GROUP_BY_PAGE[pageName].categories` 依次调用 `addon.OptionBuilders[categoryKey]`，
第 4 参传 `pageName` 作为 `subPage`；`Options\Plugin.lua` 的 `BuildPage` 只是它的一层
路由包装。

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

`Options\Skins.lua` 目前是 1 行占位，`Initialize.lua` 原先也声明了
`page = "Skins"`，页会渲染成空白。本轮不处理美化模块，已从 `PAGE_GROUPS` 移除该页
（见 5.6、9.10）。

### 2.3 加载顺序

`Options\Load_Options.xml` 现在 16 个 Lua，`Plugin.lua` 是最后一项（`Panel.lua`
已删除）。TOC 里 `Options\Load_Options.xml` 位于 `Settings\Load_Settings.xml` 之后、
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
| 7 | `UITweaks` | UI Tweaks | Tooltip Info, Progression, Keystone & Group Info, Tooltip Advanced, Unit Frames |

合计 7 模块 / **27 页**，全部在限制内（模块 <= 20，页 <= 20）。

几点说明：

- 原 `SPECIAL_PAGES` 里的 `Information` 与 `Advanced` 在插件模型下没有「顶部特殊按钮」
  这个概念，收进 `General` 模块当标签页，避免多开一个只有 2 页的模块。
- **`Skins` 页不迁移**（见 5.6 与 9.10）：本轮不处理美化模块，`Options\Skins.lua`
  只是 1 行占位，迁过去也只是一张永远空着的页。
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

加载链改动：`Options\Load_Options.xml` 插入 `<Script file='Plugin.lua'/>`
作为最后一项（`Panel.lua` 的登记已删除）。

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

### 5.3 删掉自绘面板（已完成）

删除 `Options\Panel.lua` 全文 1402 行与 `Options\Load_Options.xml` 里的登记。
迁移前把这些还活着的符号挪走，实际落点：

| 符号 | 原位置 | 实际去向 |
|---|---|---|
| `addon.RefreshOptions(force)` | `Options\Panel.lua:1396` | `Options\Plugin.lua`，实现为 `EllesmereUI:RefreshPage(force)` |
| `addon.UpdateContentHeaderHeight(h)` | `Options\Panel.lua:324-329` | `Options\Plugin.lua`，实现为 `EllesmereUI:SetContentHeaderHeightSilent(h)`；`Options\ExtraItemBar.lua:285` 是唯一调用点 |
| `addon.RefreshSidebarStates()` | `Options\Panel.lua:1400` | 直接删除；EUI 侧边栏自行维护状态，无调用点保留 |
| `PageEnableConfig` / `IsPageEnabled` / `IsPageAvailable` / `PAGE_MODULES` | `Options\Panel.lua:66-157` | 删除，由每页页内 `Enable` 开关取代，见 5.5 |
| `W:ShowOptions` / `HideOptions` / `ToggleOptions` / `RefreshOptions` | `Options\Panel.lua:1318-1393` | 全部删除，调用方改走 `addon.OpenOptionsPlugin` |
| `ResolvePage` | `Options\Panel.lua:1281-1310` | `Options\Plugin.lua` 的 `addon.ResolveOptionsPage`，改写成页名/模块名解析 |

`Initialize.lua` 原来导出的 `addon.OptionPageGroups` / `OptionPageNames` /
`OptionGroupByPage` / `SpecialPages` / `SidebarGroups` 只被 `Panel.lua`
（`:470,475,570,760,925,1284,1344`）消费，全部删除，只留 `addon.BuildOptionsPage`
（`Options\Plugin.lua` 的 `BuildPage` 依赖）与 `addon.InitDB`。`PAGE_NAMES`、
`SPECIAL_PAGES`、`SIDEBAR_GROUPS` 三个 local 也一并删掉——页面结构现在只在
`Options\Plugin.lua` 的 `MODULES` 里描述一份。

`addon.GetDB` 随之下线：底栏 Reset 改走 spec 的 `onReset`（见 5.8）。

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

### 5.5 侧边栏电源图标功能的下线（已完成）

`PageEnableConfig` 在插件模型下无法保留：插件只能有自己的 section 与行，不能给行加
电源图标或置灰态。实际做法：`PageEnableConfig` 里的 11 个页面各补一个页内
`Widgets:Toggle(parent, "Enable", ...)`，位置在每页第一个 `SectionHeader` 之后。

已补的 10 页（第 11 个是 Game Bar，原本就有 `Options\Misc.lua:414`）：

| 页面 | 文件 | DB 层 |
|---|---|---|
| Announcement | `Options\Announcement.lua` | `E.db.WT.announcement` |
| Chat Bar | `Options\Social.lua` | `E.db.WT.social.chatBar` |
| Smart Tab | `Options\Social.lua` | `E.db.WT.social.smartTab` |
| Super Tracker | `Options\Maps.lua` | `E.private.WT.maps.superTracker` |
| World Map | `Options\Maps.lua` | `E.private.WT.maps.worldMap` |
| Objective Tracker | `Options\Quest.lua` | `E.private.WT.quest.objectiveTracker` |
| Progression | `Options\Tooltips.lua` | `E.private.WT.tooltips.progression` |
| Inspect | `Options\Item.lua` | `E.db.WT.item.inspect` |
| Item Level | `Options\Item.lua` | `E.db.WT.item.itemLevel` |
| Extra Items Bar | `Options\ExtraItemBar.lua` | `E.db.WT.item.extraItemsBar` |

要点：

- **`Objective Tracker` 的 private 默认是 `enable = false`**（`Settings\Private.lua:265`）。
  删掉侧边栏开关后，页内这一行是唯一还能打开它的入口，不能省。
- `Super Tracker` / `World Map` / `Objective Tracker` / `Progression` 四页对应的模块
  没有 `ProfileUpdate`（`Modules\Maps\SuperTracker.lua`、`WorldMap.lua`、
  `Modules\Quest\ObjectiveTracker.lua`、`Modules\Tooltips\Progression.lua`），
  所以 setter 不挂 refresh。
- `Objective Tracker` 与 `Progression` 两页新增 `local otDis` / `local pgDis`
  闭包，把页内其余控件的 `DualRow` cfg 挂上 `disabled = otDis/pgDis`，
  复现原来「页关掉后整页置灰」的观感。**只有 `DualRow`/`TripleRow` 的 cfg 支持
  `disabled`，单控件工厂（`Toggle`/`Slider`/`Dropdown`/`Checkbox`）没有这个形参**，
  所以 `Options\Tooltips.lua:76-85` 的 `pg.raid` / `pg.mythicPlus` 两个单控件
  保持可用，不再置灰。
- 顶层模块启用状态本来就没有对应 DB 字段，不新增（零成本原则：新设置项默认 OFF 且
  必须有开关三处齐全才加）。

### 5.6 `Skins` 页的去除（已完成）

`Options\Skins.lua` 是 1 行占位。本轮**不处理美化模块**（9.10），所以直接移除，
不给它造空壳页：

- 已从 `Initialize.lua` 的 `PAGE_GROUPS` 与 `SIDEBAR_GROUPS` 删掉 `Skins` 条目
  （`PAGE_NAMES` 后来整个 local 一并不存在了）。
- 第 4 节 `UITweaks` 模块的 `pages` 不含 `Skins`，插件侧共 27 页。
- `Options\Skins.lua` 与其在 `Options\Load_Options.xml` 里的登记保留不动，等以后
  真要迁移时再填内容——留一个 1 行占位文件不影响任何东西。

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
| 删除 `Panel.lua` 后 `W:RefreshOptions` 若被遗漏调用会静默失效 | 部分选项不刷新 | 已改用 `addon.RefreshOptions`（`Options\Plugin.lua` 定义，转 `EllesmereUI:RefreshPage`），全仓扫描确认无 `W:RefreshOptions` 残留 |
| 页面电源图标功能消失 | 少一个快捷开关 | 已由页内 Enable 开关覆盖全部 11 页（5.5） |
| `EllesmereUI._prebuilding` / `_widgetRefreshList` / `_settingsChanged` 属内部字段 | EUI 改版可能失效 | 5.8 逐项处理，`_settingsChanged` 接受风险并记录 |
| `onReset` 按模块复位，粒度比原来的「整份 profile 重置」细 | 想一次重置全部时要点 7 次 | 这是 EUI 插件 API 给到的粒度；文档 5.3 已记，必要时后续在 General 模块里加显式的「全部重置」按钮 |

回滚：迁移分 3 个可独立 revert 的提交（见第 8 节），`Panel.lua` 删除在最后一步，
前两步保留双路时也能单独验证。

---

## 7. 验收清单

进游戏后逐项确认：

- [ ] `/wt` 打开 EllesmereUI 面板并停在 WindTools 的 General 模块
- [ ] 侧边栏出现 `WindTools` section，位于 EUI 自身所有分组之下，共 7 行
- [ ] 7 个模块逐行点开，27 个标签页逐页可打开，无 BugSack
- [ ] Extra Items Bar 页顶部的 bar 选择器与实时预览正常（content header）
- [ ] 切换 bar 后页面重建、预览同步更新
- [ ] 侧边栏搜索框输入 `game bar` 能命中 WindTools 的行并可跳转高亮
- [ ] 战斗内 `/wt` 提示不能打开，不报错
- [ ] 插件隔间（AddonCompartment）点击同样打开到 WindTools
- [ ] 设置 - 插件 - WindTools 里的按钮同样打开到 WindTools
- [ ] `/reload` 后重开面板，section 与 7 行仍在，且没有点名本插件的「需要更新」弹窗
- [ ] 每个模块的 Enable 开关切一次，对应模块行为与页面禁用态正确
- [ ] 页脚 Reset 按钮按模块复位：General / Items / Combat / Social / Maps / Quest / UI Tweaks 各试一次，只复位本模块的 DB 切片
- [ ] 独立面板不再出现：`Options\Panel.lua` 已删除，`W:ToggleOptions` 之类的入口不再存在

不进游戏也能做的静态检查：

- `cd 'C:\Dev\workspace\Wow\.lua-check'; node check.mjs <改动文件>`（luaparse 5.1）
- `stylua .` 与 `luacheck .`（本机未安装，需另跑）

---

## 8. 提交拆分

按可独立回滚的顺序（1–3 与 5 已落盘，4 在迁移文档提交时一并做过）：

1. `feat(options): register the settings pages through the EllesmereUI plugin API`
   新增 `Options\Plugin.lua`、改 `Options\Load_Options.xml`、改 `Initialize.lua`
   （注册调用 + 删除 `Skins` 页）。
2. `refactor(options): route every entry point through OpenPlugin`
   `Core\Commands.lua`、`Core\CompatE.lua`、Blizzard 设置入口、插件隔间。
3. `refactor(options): drop the standalone options panel`
   删除 `Options\Panel.lua`、清理 `Options\Load_Options.xml`、修剪 `Initialize.lua`
   的页面元数据导出与 `PAGE_NAMES`/`SPECIAL_PAGES`/`SIDEBAR_GROUPS`，
   给 10 个页面补页内 `Enable`（`Options\{Announcement,Social,Maps,Quest,Tooltips,Item,ExtraItemBar}.lua`），
   `Options\Plugin.lua` 加 `onReset` 与 `addon.UpdateContentHeaderHeight`，
   三个 README 的进度表把「选项面板(独立)」改成「选项面板」。
4. `chore(build): ignore the panel migration plan`（`.pkgmeta` 加
   `OPTIONS_PLUGIN_MIGRATION.md`，已在 `9817b5d0` 完成）
5. `docs(options): plan the move to the EllesmereUI plugin API`（本文档，已在
   `5d631cdf` 完成，后续章节的增补随迁移提交一起走）

若第 1 步验证不通过，直接放弃并停在第 0 步，不产生副作用。

---

## 9. 未实现功能的占位空壳清单

### 9.1 定位与统计口径

本节只登记「上游 WindTools 有、本移植版没有后端实现」的功能，供后续分批认领时估算
工作量。**本轮只立清单，不写任何 Lua 代码**。

统计依据（均已实测，见第 2 节）：

- `Modules\Load_Modules.xml` 目前只加载 7 个后端：`ExtraItemsBar`、`ChatBar`、
  `SmartTab`、`RaidMarkers`、`FriendlyNameplateOutline`、`QuickFocus`、`GameBar`。
- 与上游 `Ref\ElvUI_WindTools\Modules\` 逐字节比对，**40 个文件完全一致**，说明它们
  仍是 ElvUI 原生代码，一行都还没动；`differs` 的文件多数只改了文件头，不能算移植。
- 按 9.3–9.9 的表逐项累加，本轮要补空壳的模块代码合计 **27 147 行**，对应上游选项
  代码 **12 941 行**。本地现有的选项文件平均只有上游的十分之一体量（例如
  `Options\Quest.lua` 本地 237 行 / 上游 3304 行）。
- **`Skins` 整个模块本轮不处理**（9.10）。它自身还有 172 个文件 / 17 451 行模块代码
  与 4523 行选项代码，体量相当于其余全部模块之和的六成，且与「美化」主题强耦合，
  混在空壳里只会把界面塞满一堆永远灰着的开关。等其余模块有了进展再单独立项。

### 9.2 空壳的统一做法（不可变的部分）

1. **一律禁用，且只保留一个真实可用的「Enable」开关位。** EUI 的单控件工厂没有
   `disabled` 形参（`Toggle` 第 6 参是 tooltip、`Slider` 第 10 参是 pixel、`Dropdown`
   第 8 参是 tooltip），`disabled` 只存在于 `DualRow` / `TripleRow` 的 cfg 表。因此每个
   空壳必须包成一行 `DualRow`：

   ```lua
   local function notAvailable() return true end
   _, h = Widgets:DualRow(parent, y,
       { type = "toggle", text = "Fast Loot",
         getValue = function() return false end,
         setValue = function() end,
         tooltip = "Automatically loot the nearest corpse.",
         disabled = notAvailable,
         disabledTooltip = "This feature is not available yet." },
       { type = "spacer" }
   ); y = y - h
   ```

   样板文件与行号：`Options\Advanced.lua:30-46`（单 toggle）与 `:70-85`
   （一次禁用 1 toggle + 2 slider）。

2. **`getValue` 恒返回 `false`，`setValue` 空实现。** 空壳不写 DB，避免存档里留下
   无法验证的脏值；真实现时再把这一对换回 `DBGet` / `DBSet`。这条与「默认关闭」等价，
   且不受上游默认值影响——上游有 7 个开关默认是 `true`（`pauseToSlash`、
   `onlyStopWatched`、`guildNewsItemLevel`、`antiOverride`（zhCN）、
   `reshiiWrapsUpgrade`、`moveFrames.enable`、`lfgList.enable`），空壳期一律表现为关。

3. **零成本：空壳不得建帧、注册事件、挂 hook、起 ticker。** 它们只是控件行加一个
   常真禁用闭包，`disabledTooltip` 走 EUI 现成的 `AddControlDisabledTooltip`
   （`EllesmereUI_Widgets.lua:401-420`），不需要本插件做任何事。

4. **`disabledTooltip` 统一文案：`"This feature is not available yet."`**（与
   `Options\Advanced.lua` 现有两处一致，EUI 已加载的语言会自动翻译）。

5. **整页空壳的页首 Enable 开关同样禁用**，否则用户能打开一个什么都不做的模块。

6. 本地 `Options\*.lua` 里**已经存在**大量这类「界面在、后端不在」的死开关（第 2 节
   实测：Misc 的 LFG List / Move Frames / Mute / CVars / Keybind Alias，Item / Combat /
   Maps / Quest 整段）。这些**不需要新建控件**，只需按上面第 1 条把每个控件包进
   `DualRow` 加 `disabled`。表中「界面现状」列标 `已在` 的就是这一类；标 `需新建`
   的是本地连控件都没有、要按上游分组补写空壳行的。

7. **整页禁用还是逐控件禁用：一律逐控件。** `DualRow` 的
   `requireState` 只能联动同一行内的另一个控件，没有「整页联动」能力；页首
   Enable 单独禁用一行，其余控件各自禁用一行，互不依赖、实现最简单。

8. **总账：57 个空壳组**（不含 `Skins`）。其中 47 组「界面已在」（只需给现有控件包
   `DualRow` 加 `disabled`），9 组「需新建」（连控件都没有，要按上游分组补写），1 组
   （SO-06 Chat Text）「需并入现有页作子段」。

### 9.3 General 模块（General / Game Bar / Information / Advanced）

`Game Bar` 已实现，其余为待填页面。

| ID | 功能 | 上游模块（行） | 上游选项（行） | 界面现状 |
|---|---|---|---|---|
| GN-01 | General 页 12 个杂项开关 | `Misc\PauseToSlash.lua` 27、`Misc\Math.lua` 62、`Misc\DisableTalkingHead.lua` 25、`Misc\SkipCutScene.lua` 151、`Misc\HideCrafter.lua` 46、`Misc\LootPanel.lua` 15、`Misc\KeybindTextAbove.lua` 39、`Misc\GuildNewsItemLevel.lua` 46、`Misc\AddCNFilter.lua` 27、`Misc\AntiOverride.lua` 15、`Misc\AutoToggleChatBubble.lua` 26、`Misc\ReshiiWrapsUpgrade.lua` 62 | `Options\Misc.lua` `general` 23(131) | 已在（`Options\Misc.lua:159-206`） |
| GN-02 | Extra Binding Buttons | `Misc\ExtraBindingButtons.lua` 35 | 并入 `general` | 需新建 |
| GN-03 | Automation（自动接受/交任务等） | `Misc\Automation.lua` 103 | `automation` 154(88) | 已在（`Options\Misc.lua` Automation 段） |
| GN-04 | Move Frames | `Misc\MoveFrames.lua` 792 | `moveFrames` 438(114) | 已在（`Options\Misc.lua` Move Frames 段） |
| GN-05 | Mute（坐骑/其他静音） | `Misc\Mute.lua` 334 | `mute` 552(163) | 已在（`Options\Misc.lua` Mute 段） |
| GN-06 | LFG List 增强 | `Misc\LFGList.lua` **1741** | `lfgList` 1504(427) | 已在（含 Icon / Class Line / Additional Text / Party Keystone / Right Panel 5 子段） |
| GN-07 | Spell Activation Alert | `Misc\SpellActivationAlert.lua` 63 | `spellActivationAlert` 1931(88) | 已在 |
| GN-08 | Keybind Alias | `Misc\KeybindAlias.lua` 68 | `keybindAlias` 2019(124) | 已在（含 `Options\Core.lua:590` 的别名编辑器弹窗） |
| GN-09 | Exit Phase Diving | `Misc\ExitPhaseDiving.lua` 138 | `exitPhaseDiving` 2143(64) | 已在 |
| GN-10 | CVars Editor | `Misc\Core.lua` 98（`cvars` 数据表） | `cvars` 242(196) | 已在（General/Combat/Visual Effect/Control 4 子段） |
| GN-11 | Information 三页正文 | 无对应模块（纯文案） | `Options\Information.lua` `help` 50(288)、`credits` 338(345)、`changelog` 683(151) | 已在骨架（`Options\Information.lua` 40 行只有 3 个 header，正文为空） |
| GN-12 | CVar Alert / Fix SetPassThroughButtons | `Core\Core.lua` `W:GameFixing()`（**全仓无调用点**） | `Options\Advanced.lua` `gameFix` 69(53) | 已在（`Options\Advanced.lua:51-58`，目前是活开关但后端未接线） |
| GN-13 | Table Attribute Display | 无 | `Options\Advanced.lua` `developer` 部分 | 已禁用（`Options\Advanced.lua:71-85`，本轮已合规） |
| GN-14 | Profiles 页 | 无（依赖 ElvUI Profile 机制） | `Options\Advanced.lua` `reset` 231(1088) 一部分 | 需新建；EUI 自带 Profiles 是否复用待定 |
| GN-15 | Reset 页脚 | 无 | `Options\Advanced.lua` `reset` 231(1088) | 已改为 EUI 的 per-module Reset（`Options\Plugin.lua` 的 `RESET_SLICES` + `onReset`），不再需要自绘页脚 |

小计：未移植 15 组 / 3913 行模块代码 / 1395 行选项。**`Misc\LFGList.lua` 1741 行是
本模块最重的一块**，建议单独成批。`General` 页 12 个开关虽然控件已在，但 12 个后端
模块全是 ElvUI 原生代码（逐字节一致），所以整组都算未移植。

### 9.4 Items 模块（6 页，仅 Extra Items Bar 已实现）

| ID | 功能 | 上游模块（行） | 上游选项（行） | 界面现状 |
|---|---|---|---|---|
| IT-01 | Delete Item | `Item\DeleteItem.lua` 160 | `Options\Item.lua` `delete` 680(51) | 已在 |
| IT-02 | Fast Loot | `Item\FastLoot.lua` 59 | `fastLoot` 812(44) | 已在 |
| IT-03 | Trade | `Item\Trade.lua` 58 | `trade` 856(46) | 已在 |
| IT-04 | Already Known | `Item\AlreadyKnown.lua` 387 | `alreadyKnown` 731(81) | 已在 |
| IT-05 | Contacts | `Item\Contacts.lua` 764 | `contacts` 902(209) | 已在（Display 页引 `item.contacts`） |
| IT-06 | Inspect | `Item\Inspect.lua` 1528 | `inspect` 1111(625) | 已在（含 8 个子段，全部为死开关） |
| IT-07 | Item Level | `Item\ItemLevel.lua` 171 | `itemLevel` 1736(320) | 已在 |
| IT-08 | Extend Merchant Pages | `Item\ExtendMerchantPages.lua` 205 | `extendMerchantPages` 2056(57) | 已在 |
| — | Extra Items Bar | `Item\ExtraItemBar.lua` 1014 + `_Data 2528` | `extraItemsBar` 106(574) | **已移植** |

小计：未移植 8 组 / 3332 行模块代码 / 1433 行选项。

### 9.5 Combat 模块（1 页，仅 Raid Markers 已实现）

| ID | 功能 | 上游模块（行） | 上游选项（行） | 界面现状 |
|---|---|---|---|---|
| CB-01 | Combat Alert | `Combat\CombatAlert.lua` 719 | `combatAlert` 285(323) | 已在（含 Animation / Text / Enter Text / Leave Text / Font / 双 Sound 共 7 子段） |
| CB-02 | Destroy Totem | `Combat\DestroyTotem.lua` 61 | `destroyTotem` 608(120) | 已在 |
| CB-03 | Quick Keystone | `Combat\QuickKeystone.lua` 67 | `quickKeystone` 728(418) | 已在 |
| CB-04 | Damage Meter Layout | `Combat\DamageMeterLayout.lua` 637 | `damageMeterLayout` 1146(363) | 已在（Container / Auto Switch 两子段） |

小计：未移植 4 组 / 1484 行 / 1224 行选项。

### 9.6 Social 模块（3 页，Chat Bar 与 Smart Tab 已实现）

| ID | 功能 | 上游模块（行） | 上游选项（行） | 界面现状 |
|---|---|---|---|---|
| SO-01 | Announcement | `Announcement\Core.lua` 167 + `Events.lua` 94 + `Quest.lua` 65 + `Utility.lua` 182 + `Goodbye.lua` 15 + `ResetInstance.lua` 131 + `Keystone.lua` 51 | `Options\Announcement.lua` `enable` 43(13) / `quest` 56(194) / `utility` 250(364) / `goodbye` 614(108) / `resetInstance` 722(94) / `keystone` 816(90) / `general` 906(41) | 已在（`Options\Announcement.lua` 7 个 SectionHeader 全在，后端只有 `Announcement\Core.lua` 未接入） |
| SO-02 | Chat Link | `Social\ChatLink.lua` 388 | `chatLink` 786(490) | **需新建页**（Social 模块下新增第 4 个标签页） |
| SO-03 | Context Menu | `Social\ContextMenu.lua` 522 | `contextMenu` 1276(178) | **需新建页** |
| SO-04 | Emote | `Social\Emote.lua` 293 | `emote` 1454(63) | **需新建页** |
| SO-05 | Friend List | `Social\FriendList.lua` 577 | `friendList` 1517(254) | **需新建页** |
| SO-06 | Chat Text | `Social\ChatText.lua` 1839 | 上游无独立 options 组（并入 `chatBar`） | 需并入 Chat Bar 页，作空壳子段 |

小计：未移植 6 组 / 4324 行 / 1889 行选项 + 4 个新页。

### 9.7 Maps 模块（4 页，全部为后端空缺）

| ID | 功能 | 上游模块（行） | 上游选项（行） | 界面现状 |
|---|---|---|---|---|
| MP-01 | Super Tracker | `Maps\SuperTracker.lua` 368 | `superTracker` 21(260) | 已在（`maps.superTracker` 已引用，后端无） |
| MP-02 | Rectangle Minimap | `Maps\RectangleMinimap.lua` 294 | `rectangleMinimap` 281(63) | 已在 |
| MP-03 | Minimap Buttons | `Maps\MinimapButtons.lua` 969 | `minimapButtons` 344(295) | 已在 |
| MP-04 | World Map | `Maps\WorldMap.lua` **3041** | `worldMap` 639(121) | 已在（`maps.worldMap` 已引用） |
| MP-05 | Instance Difficulty | `Maps\InstanceDifficulty.lua` 199 | `instanceDifficulty` 760(171) | 已在 |
| MP-06 | Event Tracker | `Maps\EventTracker.lua` 1075 + `EventTracker_Data.lua` 1146 | `eventTracker` 931(1129) | 已在（含 Panel Style 子段） |
| MP-07 | Datatexts（MicroMenu / Range） | `Datatexts\MicroMenu.lua` 123、`Range.lua` 83 | 无独立选项组 | **需新建页**或并入 World Map 页 |

小计：未移植 7 组 / 7298 行 / 2039 行选项。`WorldMap` 与 `EventTracker` 两组是**单组
破千行**的重头，应各自独立成批。

### 9.8 Quest 模块（4 页，全部为后端空缺）

| ID | 功能 | 上游模块（行） | 上游选项（行） | 界面现状 |
|---|---|---|---|---|
| QS-01 | Objective Tracker | `Quest\ObjectiveTracker.lua` 511 | `objectiveTracker` 31(**1043**) | 已在（含 Progress / Header 子段） |
| QS-02 | Auto Collapse | `Quest\AutoCollapse.lua` 199 | `autoCollapse` 1074(157) | 已在 |
| QS-03 | Switch Buttons | `Quest\SwitchButtons.lua` 215 | `switchButtons` 1231(155) | 已在 |
| QS-04 | Progress（含 Automation Conditions） | `Quest\Progress.lua` 566 | `progress` 1386(**1101**) | 已在 |
| QS-05 | Turn In | `Quest\TurnIn.lua` 775 | `turnIn` 2487(286) | 已在 |
| QS-06 | Prey Hunt | `Quest\PreyHunt.lua` 355 | `preyHunt` 2773(315) | 已在 |
| QS-07 | Achievement Screenshot | `Quest\AchievementScreenshot.lua` 102 | `achievementScreenshot` 3088(62) | 已在 |
| QS-08 | Achievement Tracker | `Quest\AchievementTracker.lua` **1292** | `achievementTracker` 3150(155) | 已在 |

小计：未移植 8 组 / 4015 行 / 3274 行选项。**`Options\Quest.lua` 是本地与上游差距
最大的一组（237 行 vs 3304 行）**，空壳补全后本地文件会显著变长，属预期。

### 9.9 UI Tweaks 模块（6 页）

| ID | 功能 | 上游模块（行） | 上游选项（行） | 界面现状 |
|---|---|---|---|---|
| UI-01 | Tooltip 基础 | `Tooltips\Core.lua` 244 + `HealthBar.lua` 48 + `Icons.lua` 226 + `UnitInfo.lua` 113 | `general` 35(104) + `elvUITweaks` 139(202) | 已在（Tooltip Info 与 Tooltip Advanced 两页） |
| UI-02 | Progression | `Tooltips\Progression.lua` 436 | `progression` 341(261) | 已在（`tooltips.progression` 已引用，后端无） |
| UI-03 | Keystone & Group Info | `Tooltips\Keystone.lua` 43 + `GroupInfo.lua` 143 + `MythicPlus.lua` 133 + `TierSet.lua` 103 | `keystone` 602(90) + `groupInfo` 692(159) | 已在 |
| UI-04 | Objective Progress | `Tooltips\ObjectiveProgress.lua` 64 | `objectiveProgress` 851(52) | 已在 |
| UI-05 | Absorb | `UnitFrames\Absorb.lua` 110 | `absorb` 127(310) | 已在（`unitFrames.absorb` 已引用） |
| UI-06 | Role Icon | `UnitFrames\RoleIcon.lua` 16 | `roleIcon` 437(112) | 已在（Absorb 页内引用 `unitFrames.roleIcon`） |
| UI-07 | Name Clip | `UnitFrames\NameClip.lua` 132 | `nameClip` 549(78) | 已在（`unitFrames.nameClip` 已引用） |
| UI-08 | Dispel Overlay | `UnitFrames\DispelOverlay.lua` **712（本地文件不存在）** | `dispelOverlay` 627(98) | **需新建文件与页** |
| UI-09 | Tags | `UnitFrames\Tags.lua` 258 | `tags` 725(221) | **需新建页** |
| — | Quick Focus / Friendly Nameplate Outline | 已移植（本地另外新增了 FriendlyNameplateOutline，上游无此文件） | `quickFocus` 14(113) | **已移植** |

小计：未移植 9 组 / 2781 行 / 1687 行选项 + 1 个新文件。

### 9.10 Skins 模块（本轮不处理）

本地 `Options\Skins.lua` 只有 1 行占位注释，`Initialize.lua:250` 仍声明
`page = "Skins"`，迁移后该页会渲染成空白页（见 5.6）。

**本轮明确不补 Skins 空壳。** 上游 `Skins` 是全仓最大的一块：172 个文件 / 17 451 行
模块代码、4523 行选项代码，占未移植总量的一半以上。它是纯美化主题，与本次「补齐
功能占位」的目的不同，而且 SK-06（ElvUI 本体）与 SK-10（BigWigs）依赖本插件刻意
不依赖的第三方插件。处理方式先按 5.6 从 `PAGE_GROUPS` 移除 `Skins` 页，等其余模块
有了进展再单独立项。

上游分组备查（仅供后续立项估量，本轮不实现）：

| ID | 上游选项组 | 选项行 | 覆盖范围 |
|---|---|---|---|
| SK-01 | `general` 54(339) + `font` 393(146) | 485 | 全局底色 / 字体 |
| SK-02 | `cooldownViewer` 539(664) | 664 | 冷却查看器 |
| SK-03 | `lossOfControl` 1203(381) | 381 | 失控提示 |
| SK-04 | `blizzard` 1584(553) | 553 | 暴雪原生界面（`Skins\Blizzard\` 95 文件 5656 行） |
| SK-05 | `damageMeter` 2137(247) | 247 | 伤害统计 |
| SK-06 | `elvui` 2384(184) | 184 | ElvUI 本体（`Skins\ElvUI\` 24 文件 1179 行）；依赖 ElvUI，不做 |
| SK-07 | `addons` 2568(391) | 391 | 第三方插件（`Skins\Addons\` 38 文件 8250 行） |
| SK-08 | `widgets` 2959(**1151**) | 1151 | 通用控件（`Skins\Widgets\` 7 文件 865 行） |
| SK-09 | `libraries` 4110(74) | 74 | 库美化 |
| SK-10 | `bigWigsSkin` 4184(340) | 340 | BigWigs；依赖 BigWigs，不做 |

### 9.11 汇总与建议分批

分两张表看：**表 A 是空壳（只做界面）**，**表 B 是真做后端**。二者是同一批功能的
两个阶段，不叠加。

表 A（空壳期，只改 `Options\*.lua`，零后端代码；不含 `Skins`）：

| 批次 | 范围 | 空壳组数 | 说明 |
|---|---|---|---|
| A1 | 「界面已在」的组补 `DualRow` + `disabled` | 47 | 纯界面，风险最低，可立即开工（含 GN-11 空骨架、GN-13 已合规） |
| A2 | 「需新建」补控件骨架 | 10 | 需要新页、新文件或新子段（GN-02、GN-14、SO-02..06、MP-07、UI-08、UI-09） |

合计 47 + 10 = **57**，与 9.2 第 8 条的总账一致。

表 B（真实现期，改 `Modules\*.lua`，按模块分组；不含 `Skins`）：

| 批次 | 范围 | 模块代码 | 选项代码 | 组数 |
|---|---|---|---|---|
| B1 | General 剩余 15 组 | 3913 | 1395 | 15 |
| B2 | Items + Combat | 3332 + 1484 = 4816 | 1433 + 1224 = 2657 | 12 |
| B3 | Social 剩余 6 组 | 4324 | 1889 | 6 |
| B4 | UI Tweaks 9 组 | 2781 | 1687 | 9 |
| B5 | Quest 8 组 | 4015 | 3274 | 8 |
| B6 | Maps 7 组（WorldMap / EventTracker 各自再拆） | 7298 | 2039 | 7 |

> 表 B 口径：模块代码 = 9.3–9.9 各表「上游模块（行）」逐项相加，合计
> 3913 + 4816 + 4324 + 2781 + 4015 + 7298 = **27 147 行**，与 9.1 一致；选项代码
> 合计 **12 941 行**。`Skins`（17 451 / 4523）不计入本表。

A1 是**纯界面改动、无后端代码**，可以先做，风险最低，且立刻满足「这些功能在设置中
都显示且禁用」；A2 同理。B 系列才是真正的工作量。

### 9.12 与迁移步骤的衔接

- 本节的空壳**不写进 `Options\Plugin.lua`**，只改各 `Options\<module>.lua` 的 builder
  内部；`Plugin.lua` 的 7 模块 27 页结构不受影响。
- 新页（SO-02..05、MP-07、UI-08、UI-09）会改变第 4 节的页数：Social 3→7 页、
  Maps 4→5 页、UITweaks 6→8 页。基准是移除 `Skins` 后的 **27 页**，加完这 7 个新页
  为 **34 页**。单模块页数最多 8（UITweaks），仍在 `MAX_PAGES = 20` 之内，
  但**第 4 节表格需要在补新页时同步更新**。
- 建议把表 A（空壳）放在第 8 节提交序列的**第 1 步之前**或**第 3 步之后**，避免与
  面板删除混在同一个提交里；表 B 与迁移无依赖，可随时穿插。

---

## 10. 明确不做的事

- 不引入新依赖，不打包 EUI 的任何库。
- 不写 `GetBuildInfo` 版本分支；TOC 继续只声明 `120105, 16001`。
- 不改 `Locales\`（除非第 5.10 节最终确认需要新词条，那时单独开一轮）。
- 不动 README 迁移进度表以外的模块状态（`选项面板(独立)` 一行在第 3 步提交里
  改为「选项面板(并入 EllesmereUI)」）。
- 不重构各 builder 的内部实现；只改它们与面板之间的接口。
- 不给未移植模块写**后端实现**。但要按第 9 节给它们补**可见的禁用空壳**
  （`DualRow` + `disabled` + 常真闭包），空壳不含任何运行时代码。
- **不处理 `Skins` 美化模块**（9.10）：不补空壳页、不迁移 `Skins\` 下 172 个文件，
  `Skins` 页按 5.6 从 `PAGE_GROUPS` 移除。其中 SK-06（ElvUI 本体）与 SK-10（BigWigs）
  依赖本插件刻意不依赖的第三方插件，永久不做。
