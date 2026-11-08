<div align="center">
<img width="128" alt="EllesmereUI WindTools" src="https://raw.githubusercontent.com/wind-addons/EllesmereUI_WindTools/main/Media/Textures/WindToolsAddonIcon.png"/><br><br>
![版本](https://img.shields.io/badge/%E7%89%88%E6%9C%AC-0.2.8-538AED.svg?longCache=true&style=for-the-badge)

[![Discord](https://img.shields.io/discord/747075771213807707?color=7289DA&label=DISCORD&logo=discord&style=for-the-badge)](https://discord.gg/CMDsBmhvyW) [![GitHub Stars](https://img.shields.io/github/stars/wind-addons/EllesmereUI_WindTools?style=for-the-badge&label=GitHub%20Stars%20%E2%AD%90&logo=github&color=yellow)](https://github.com/wind-addons/EllesmereUI_WindTools)

简体中文 (zhCN) | [繁體中文 (zhTW)](README_zhTW.md) | [English (enUS)](README.md)

</div>

## 🧬 Fork from ElvUI_WindTools

**EllesmereUI_WindTools** 是 [ElvUI_WindTools](https://github.com/wind-addons/ElvUI_WindTools) 的迁移分支,将 WindTools 从 **ElvUI** 移植到 **EllesmereUI**。

- 原项目:[wind-addons/ElvUI_WindTools](https://github.com/wind-addons/ElvUI_WindTools)
- 依赖:需要先安装 **EllesmereUI**
- 选项页面已注册进 **EllesmereUI** 的设置面板;目前仅以下模块完成迁移。

## 📋 迁移进度

| 模块 | 状态 | 说明 |
|---|---|---|
| 选项面板 | ✅ 已完成 | 并入 EllesmereUI 设置面板;未移植模块的页面不再显示 |
| **额外物品栏** | ✅ 已完成 | 5 条自定义物品栏、按键绑定、空栏自动隐藏 |
| **聊天频道Bar** | ✅ 已完成 | 频道切换栏、方块/文字样式、自动隐藏、悬停显示 |
| **聊天智能Tab切换** | ✅ 已完成 | Tab 频道循环、密语历史、频道开关 |
| 物品(快速拾取、交易、装备查看、物品等级、联系人、删除物品、已知配方、商人翻页) | ✅ 已完成 | 删除物品、快速拾取、交易、商人翻页、已知配方、联系人、装备/观察框体、物品等级共 8 个模块 |
| 战斗(快速标记、战斗提醒、取消图腾、快捷钥匙、伤害统计) | ✅ 已完成 | 目标/世界标记、就位确认、战斗日志、拉怪倒计时、战斗提醒、取消图腾、快捷钥匙、伤害统计布局 |
| 地图(超级追踪、小地图按钮、矩形小地图、世界地图、难度&事件) | ❌ 未移植 | |
| 任务(任务追踪、自动交接、开关按钮) | ❌ 未移植 | |
| 社交(聊天增强、聊天文本、右键菜单、表情、好友列表) | ❌ 未移植 | |
| 通告(任务、实用功能、自定义、告别、重置副本、钥石) | ✅ 已完成 | 任务进度、实用法术使用、自定义法术消息、副本告别、重置与难度变更提示、!keys 回复 |
| 提示框(进度、钥匙、队伍信息、任务进度) | ❌ 未移植 | |
| 单位框体(友方姓名板描边) | ✅ 已完成 | 将 Ellesmere 姓名板描边同步到系统字体，兼顾追随者地下城友方姓名板（移植自 EUI_Kogotool） |
| 单位框体(快速焦点) | ✅ 已完成 | 修饰键点击聚焦，可选自动标记目标 |
| 单位框体(吸收、职责图标、标签) | ❌ 未移植 | |
| 美化 | ❌ 未移植 | |
| 杂项(游戏栏) | ✅ 已完成 | 系统条：时间/系统信息、14 个可配置按钮、炉石三键、战斗锁定保护，正式服与永恒服双端 |
| 杂项(移动框体、静音、自动操作、跳过动画、法术触发提示等) | ✅ 已完成 | 移动框体、静音、自动操作、跳过动画、法术触发提示、退出深潜按钮、隐藏制造者、公会新闻物品等级、暂停转斜杠等 |
| 杂项(按键别名、预组队列表) | ❌ 未移植 | 依赖 ElvUI 动作条内部结构与 KeystoneInfo |

## ❤️ 鸣谢

- WindTools 原作者:[fang2hou](https://github.com/fang2hou)
- [完整鸣谢列表](CREDITS.md)
