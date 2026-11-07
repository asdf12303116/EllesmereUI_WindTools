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
addon.RegisterOptionBuilder("advanced", function(parent, y, cat)
	local MH = function(mod, sub) return addon.MakeHeader(cat, mod, sub) end
	local Widgets = EllesmereUI.Widgets
	local _, h
	local gdb = E.global.WT

	_, h = Widgets:SectionHeader(parent, MH("Core"), y); y = y - h
	do
		_, h = Widgets:Toggle(parent, "Login Message", y,
			function() return gdb.core and gdb.core.loginMessage end,
			function(v) gdb.core = gdb.core or {}; gdb.core.loginMessage = v end,
			"The message will be shown in chat when you first login."); y = y - h
		_, h = Widgets:Toggle(parent, "Changelog Popup", y,
			function() return gdb.core and gdb.core.changlogPopup end,
			function(v) gdb.core = gdb.core or {}; gdb.core.changlogPopup = v end,
			"Show the changelog popup rather than chat message after every update."); y = y - h
	end

	_, h = Widgets:SectionHeader(parent, MH("Developer"), y); y = y - h
	_, h = Widgets:Dropdown(parent, "Log Level", y,
		LOG_LEVEL_VALUES,
		function() return gdb.developer and gdb.developer.logLevel end,
		function(v) gdb.developer = gdb.developer or {}; gdb.developer.logLevel = v end,
		LOG_LEVEL_ORDER,
		"Only display log message that the level is higher than you choose."); y = y - h

	return y
end)
