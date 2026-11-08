local addon = select(2, ...)
local E = addon[3]

local LOG_LEVEL_VALUES = {
	[1] = "1 - ERROR", [2] = "2 - WARNING", [3] = "3 - INFO", [4] = "4 - DEBUG",
}
local LOG_LEVEL_ORDER = { 1, 2, 3, 4 }

-- Only the parts of this page with a live consumer are built: Login Message and
-- Changelog Popup are read in Initialize.lua and Core/Core.lua, and the log level
-- is read by Core/Functions/Developer.lua. The game fix toggles (W:GameFixing is
-- never called), the compatibility check (Core/Compatibility.lua is not in any
-- load list) and the table attribute display (only read by the unloaded Skins
-- module) had nothing behind them, so they are gone rather than greyed out.
addon.RegisterOptionBuilder("advanced", function(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local gdb = E.global.WT

	_, h = Widgets:SectionHeader(parent, "CORE", y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Login Message",
		  tooltip = "The message will be shown in chat when you first login.",
		  getValue = function() return gdb.core and gdb.core.loginMessage end,
		  setValue = function(v) gdb.core = gdb.core or {}; gdb.core.loginMessage = v end },
		{ type = "spacer" }); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Changelog Popup",
		  tooltip = "Show the changelog popup rather than chat message after every update.",
		  getValue = function() return gdb.core and gdb.core.changlogPopup end,
		  setValue = function(v) gdb.core = gdb.core or {}; gdb.core.changlogPopup = v end },
		{ type = "spacer" }); y = y - h

	_, h = Widgets:SectionHeader(parent, "DEVELOPER", y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Log Level",
		  values = LOG_LEVEL_VALUES, order = LOG_LEVEL_ORDER,
		  tooltip = "Only display log message that the level is higher than you choose.",
		  getValue = function() return gdb.developer and gdb.developer.logLevel end,
		  setValue = function(v) gdb.developer = gdb.developer or {}; gdb.developer.logLevel = v end },
		{ type = "spacer" }); y = y - h

	return y
end)
