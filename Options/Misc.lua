local addon = select(2, ...)
local W = addon[1]
local E = addon[3]

local DBGet = addon.DBGet
local DBSet = addon.DBSet
local DBGet2 = addon.DBGet2
local DBSet2 = addon.DBSet2
local L = addon.L
local SafeModuleCall = addon.SafeModuleCall
local PromptReload = addon.PromptReload
local CVarGetBool = addon.CVarGetBool
local CVarSetBool = addon.CVarSetBool
local CVarGetNum = addon.CVarGetNum
local CVarSetNum = addon.CVarSetNum
local CVarGetStr = addon.CVarGetStr
local CVarSetStr = addon.CVarSetStr
local GetLSMFonts = addon.GetLSMFonts
local FONT_OUTLINE_VALUES = addon.FONT_OUTLINE_VALUES
local FONT_OUTLINE_ORDER = addon.FONT_OUTLINE_ORDER

local tinsert = tinsert

local ANIMATION_EASE_VALUES = {
	linear = "Linear Ease",
	quadratic = "Quadratic Ease",
	cubic = "Cubic Ease",
	quartic = "Quartic Ease",
	quintic = "Quintic Ease",
	sinusoidal = "Sinusoidal Ease",
	exponential = "Exponential Ease",
	circular = "Circular Ease",
	bounce = "Bounce Ease",
}
local ANIMATION_EASE_ORDER = {
	"linear", "quadratic", "cubic", "quartic", "quintic",
	"sinusoidal", "exponential", "circular", "bounce",
}

local COLOR_MODE_VALUES = {
	DEFAULT = "Default",
	CLASS = "Class Color",
	VALUE = "Value Color",
	CUSTOM = "Custom",
}
local COLOR_MODE_ORDER = { "DEFAULT", "CLASS", "VALUE", "CUSTOM" }

local ANCHOR_VALUES = {
	TOP = "TOP", BOTTOM = "BOTTOM",
	LEFT = "LEFT", RIGHT = "RIGHT", CENTER = "CENTER",
	TOPLEFT = "TOPLEFT", TOPRIGHT = "TOPRIGHT",
	BOTTOMLEFT = "BOTTOMLEFT", BOTTOMRIGHT = "BOTTOMRIGHT",
}
local ANCHOR_ORDER = {
	"TOP", "BOTTOM", "LEFT", "RIGHT", "CENTER",
	"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT",
}

local SCREENSHOT_FORMAT_VALUES = { jpeg = "JPG", png = "PNG", tga = "TGA" }
local SCREENSHOT_FORMAT_ORDER = { "jpeg", "png", "tga" }

local MOUSE_ACCEL_VALUES = {
	["-1"] = "System Default",
	["0"] = "Disable",
	["1"] = "Raw Mouse Acceleration",
}
local MOUSE_ACCEL_ORDER = { "-1", "0", "1" }

-- Achievements and Legacy Challenges are separate panels that share an icon, and
-- each exists on only one client. Availability is asked of the module that has
-- to click the slot, so the dropdown cannot drift from what the bar can run.
local function IsButtonAvailable(key)
	local GB = W.Modules and W.Modules.GameBar
	if not (GB and GB.IsButtonAvailable) then
		return true
	end
	return GB:IsButtonAvailable(key)
end

local AVAILABLE_BUTTON_VALUES = {
	NONE = "None",
	CHARACTER = "Character",
	SPELLBOOK = "Spellbook",
	TALENTS = "Talents",
	FRIENDS = "Friend List",
	GUILD = "Guild",
	GROUP_FINDER = "Group Finder",
	ACHIEVEMENTS = "Achievements",
	LEGACY_CHALLENGES = "Legacy Challenges",
	ENCOUNTER_JOURNAL = "Encounter Journal",
	COLLECTIONS = "Collections",
	TOY_BOX = "Toy Box",
	PET_JOURNAL = "Pet Journal",
	MISSION_REPORTS = "Mission Reports",
	PROFESSION = "Profession",
	BAGS = "Bags",
	SCREENSHOT = "Screenshot",
	-- Matches the game bar button, which asks for "Housing" because EllesmereUI
	-- binds "Home" to the home latency row of its network panel.
	HOME = "Housing",
	HEARTHSTONE = "Hearthstone",
	BLIZZARD_SHOP = "Blizzard Shop",
	GAMEMENU = "Game Menu",
	VOLUME = "Volume",
}
-- Presentation order for the slot dropdowns; entries the current client cannot
-- run are dropped by GetButtonOrder below.
local AVAILABLE_BUTTON_ORDER = {
	"NONE", "CHARACTER", "SPELLBOOK", "TALENTS", "FRIENDS", "GUILD", "GROUP_FINDER",
	"ACHIEVEMENTS", "LEGACY_CHALLENGES", "ENCOUNTER_JOURNAL", "COLLECTIONS", "TOY_BOX",
	"PET_JOURNAL", "MISSION_REPORTS", "PROFESSION", "BAGS", "SCREENSHOT", "HOME",
	"HEARTHSTONE", "BLIZZARD_SHOP", "GAMEMENU", "VOLUME",
}

local function GetButtonOrder()
	local order = {}
	for _, key in ipairs(AVAILABLE_BUTTON_ORDER) do
		if IsButtonAvailable(key) then
			tinsert(order, key)
		end
	end
	return order
end

local function GetSlotValue(list, index)
	local key = list and list[index]
	-- A profile carried over from the other client can name a panel that does not
	-- exist here; the bar renders that slot empty, so the dropdown shows the same.
	if key and not IsButtonAvailable(key) then
		return "NONE"
	end
	return key
end

local BUTTON_SLOT_TOOLTIP = "Pick the action for this slot. "
	.. "Achievements and Legacy Challenges exist on different clients; "
	.. "Collections and Pets also provide a right click action."

local TOOLTIP_ANCHOR_VALUES = { ANCHOR_TOP = "TOP", ANCHOR_BOTTOM = "BOTTOM" }
local TOOLTIP_ANCHOR_ORDER = { "ANCHOR_TOP", "ANCHOR_BOTTOM" }

-- The category covers two pages: the game bar has its own page, and everything
-- else lands on General, which is where the misc module switches and the CVars
-- editor live. Keybind Alias is still absent on purpose: it hooks ElvUI's action
-- bar internals, and this addon does not load those.
addon.RegisterOptionBuilder("misc", function(parent, y, cat, subPage)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local db = E.db.WT.misc

	if subPage == "Game Bar" then
		local gb = db.gameBar
		local gbDisabled = function() return not gb.enable end
		-- Every Game Bar setting is read when the bar redraws, so pushing the
		-- change straight into the module keeps the bar honest without a reload.
		local gbRefresh = function() SafeModuleCall(W.Modules.GameBar, "ProfileUpdate") end
		local fontValues = GetLSMFonts()
		local fontOrder = {}
		for name in pairs(fontValues) do fontOrder[#fontOrder + 1] = name end
		table.sort(fontOrder)

		-- Sections are one uppercase word each, following the EllesmereUI pages.
		-- Upstream split the same controls over thirteen headers, most of which
		-- held a single row; the settings themselves are unchanged.
		_, h = Widgets:SectionHeader(parent, "GENERAL", y); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Enable", tooltip = "Toggle the game bar.",
			  getValue = DBGet(gb, "enable"), setValue = DBSet(gb, "enable", gbRefresh) },
			{ type = "toggle", text = "Bar Backdrop", tooltip = "Show a backdrop of the bar.",
			  getValue = DBGet(gb, "backdrop"), setValue = DBSet(gb, "backdrop", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Backdrop Spacing", min = 1, max = 30, step = 1,
			  tooltip = "The spacing between the backdrop and the buttons.",
			  getValue = DBGet(gb, "backdropSpacing"), setValue = DBSet(gb, "backdropSpacing", gbRefresh), disabled = gbDisabled },
			{ type = "slider", text = "Button Spacing", min = 1, max = 30, step = 1,
			  tooltip = "The spacing between buttons.",
			  getValue = DBGet(gb, "spacing"), setValue = DBSet(gb, "spacing", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Button Size", min = 2, max = 80, step = 1,
			  tooltip = "The size of the buttons.",
			  getValue = DBGet(gb, "buttonSize"), setValue = DBSet(gb, "buttonSize", gbRefresh), disabled = gbDisabled },
			{ type = "spacer" }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Time Area Width", min = 1, max = 200, step = 1,
			  getValue = DBGet(gb, "timeAreaWidth"), setValue = DBSet(gb, "timeAreaWidth", gbRefresh), disabled = gbDisabled },
			{ type = "slider", text = "Time Area Height", min = 1, max = 100, step = 1,
			  getValue = DBGet(gb, "timeAreaHeight"), setValue = DBSet(gb, "timeAreaHeight", gbRefresh), disabled = gbDisabled }
		); y = y - h

		_, h = Widgets:SectionHeader(parent, "DISPLAY", y); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Mouse Over", tooltip = "Show the bar only when the mouse is hovered over the area.",
			  getValue = DBGet(gb, "mouseOver"), setValue = DBSet(gb, "mouseOver", gbRefresh), disabled = gbDisabled },
			{ type = "toggle", text = "Notification", tooltip = "Add an indicator icon to buttons.",
			  getValue = DBGet(gb, "notification"), setValue = DBSet(gb, "notification", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Fade Time", min = 0, max = 3, step = 0.01,
			  tooltip = "The animation speed.",
			  getValue = DBGet(gb, "fadeTime"), setValue = DBSet(gb, "fadeTime", gbRefresh), disabled = gbDisabled },
			{ type = "dropdown", text = "Tooltip Anchor",
			  values = TOOLTIP_ANCHOR_VALUES, order = TOOLTIP_ANCHOR_ORDER,
			  getValue = DBGet(gb, "tooltipsAnchor"), setValue = DBSet(gb, "tooltipsAnchor", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Duration", min = 0, max = 3, step = 0.01,
			  tooltip = "The duration of the animation in seconds.",
			  getValue = DBGet2(gb, "animation", "duration"), setValue = DBSet2(gb, "animation", "duration", gbRefresh), disabled = gbDisabled },
			{ type = "dropdown", text = "Ease", values = ANIMATION_EASE_VALUES, order = ANIMATION_EASE_ORDER,
			  tooltip = "The easing function used for colorize the button.",
			  getValue = DBGet2(gb, "animation", "ease"), setValue = DBSet2(gb, "animation", "ease", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Invert Ease",
			  getValue = DBGet2(gb, "animation", "easeInvert"), setValue = DBSet2(gb, "animation", "easeInvert", gbRefresh), disabled = gbDisabled },
			{ type = "spacer" }
		); y = y - h

		_, h = Widgets:SectionHeader(parent, "COLORS", y); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "dropdown", text = "Normal Mode", values = COLOR_MODE_VALUES, order = COLOR_MODE_ORDER,
			  getValue = DBGet(gb, "normalColor"), disabled = gbDisabled,
			  setValue = function(value)
				  gb.normalColor = value
				  gbRefresh()
				  -- The custom swatch below only becomes enabled once the mode is
				  -- CUSTOM, and a stale disabled flag would keep it locked.
				  addon.RefreshOptions()
			  end },
			{ type = "dropdown", text = "Hover Mode", values = COLOR_MODE_VALUES, order = COLOR_MODE_ORDER,
			  getValue = DBGet(gb, "hoverColor"), disabled = gbDisabled,
			  setValue = function(value)
				  gb.hoverColor = value
				  gbRefresh()
				  addon.RefreshOptions()
			  end }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "colorpicker", text = "Custom Normal Color", hasAlpha = true,
			  disabled = function() return gbDisabled() or gb.normalColor ~= "CUSTOM" end,
			  getValue = function()
				  local c = gb.customNormalColor or {}
				  return c.r or 1, c.g or 1, c.b or 1, c.a or 1
			  end,
			  setValue = function(r, g, b, a)
				  gb.customNormalColor = gb.customNormalColor or {}
				  gb.customNormalColor.r, gb.customNormalColor.g, gb.customNormalColor.b = r, g, b
				  gb.customNormalColor.a = a
				  gbRefresh()
			  end },
			{ type = "colorpicker", text = "Custom Hover Color", hasAlpha = true,
			  disabled = function() return gbDisabled() or gb.hoverColor ~= "CUSTOM" end,
			  getValue = function()
				  local c = gb.customHoverColor or {}
				  return c.r or 0, c.g or 0.659, c.b or 1, c.a or 1
			  end,
			  setValue = function(r, g, b, a)
				  gb.customHoverColor = gb.customHoverColor or {}
				  gb.customHoverColor.r, gb.customHoverColor.g, gb.customHoverColor.b = r, g, b
				  gb.customHoverColor.a = a
				  gbRefresh()
			  end }
		); y = y - h

		_, h = Widgets:SectionHeader(parent, "TEXT", y); y = y - h
		local at = gb.additionalText
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Enable",
			  getValue = DBGet(at, "enable"), setValue = DBSet(at, "enable", gbRefresh), disabled = gbDisabled },
			{ type = "toggle", text = "Slow Mode",
			  tooltip = "Update the additional text every 10 seconds rather than every 1 second such that the used memory will be lower.",
			  getValue = DBGet(at, "slowMode"), setValue = DBSet(at, "slowMode", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "dropdown", text = "Anchor Point", values = ANCHOR_VALUES, order = ANCHOR_ORDER,
			  getValue = DBGet(at, "anchor"), setValue = DBSet(at, "anchor", gbRefresh), disabled = gbDisabled },
			{ type = "spacer" }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "X-Offset", min = -100, max = 100, step = 1,
			  getValue = DBGet(at, "x"), setValue = DBSet(at, "x", gbRefresh), disabled = gbDisabled },
			{ type = "slider", text = "Y-Offset", min = -100, max = 100, step = 1,
			  getValue = DBGet(at, "y"), setValue = DBSet(at, "y", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:TripleRow(parent, y,
			{ type = "dropdown", text = "Font", values = fontValues, order = fontOrder,
			  getValue = DBGet(at.font, "name"), setValue = DBSet(at.font, "name", gbRefresh) },
			{ type = "dropdown", text = "Outline", values = FONT_OUTLINE_VALUES, order = FONT_OUTLINE_ORDER,
			  getValue = DBGet(at.font, "style"), setValue = DBSet(at.font, "style", gbRefresh) },
			{ type = "slider", text = "Size", min = 5, max = 60, step = 1,
			  getValue = DBGet(at.font, "size"), setValue = DBSet(at.font, "size", gbRefresh) }
		); y = y - h

		_, h = Widgets:SectionHeader(parent, "TIME", y); y = y - h
		local tm = gb.time
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Local Time",
			  getValue = DBGet(tm, "localTime"), setValue = DBSet(tm, "localTime", gbRefresh), disabled = gbDisabled },
			{ type = "toggle", text = "24 Hours",
			  getValue = DBGet(tm, "twentyFour"), setValue = DBSet(tm, "twentyFour", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Flash",
			  getValue = DBGet(tm, "flash"), setValue = DBSet(tm, "flash", gbRefresh), disabled = gbDisabled },
			{ type = "toggle", text = "Avoid Reload in Combat",
			  tooltip = "Disable the middle click UI reloading in combat.",
			  getValue = DBGet(tm, "avoidReloadInCombat"), setValue = DBSet(tm, "avoidReloadInCombat", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Always Show System Info",
			  tooltip = "The system information will be always shown rather than showing only being hovered.",
			  getValue = DBGet(tm, "alwaysSystemInfo"), setValue = DBSet(tm, "alwaysSystemInfo", gbRefresh), disabled = gbDisabled },
			{ type = "slider", text = "Interval", min = 1, max = 60, step = 1,
			  tooltip = "The interval of updating.",
			  getValue = DBGet(tm, "interval"), setValue = DBSet(tm, "interval", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:TripleRow(parent, y,
			{ type = "dropdown", text = "Font", values = fontValues, order = fontOrder,
			  getValue = DBGet(tm.font, "name"), setValue = DBSet(tm.font, "name", gbRefresh) },
			{ type = "dropdown", text = "Outline", values = FONT_OUTLINE_VALUES, order = FONT_OUTLINE_ORDER,
			  getValue = DBGet(tm.font, "style"), setValue = DBSet(tm.font, "style", gbRefresh) },
			{ type = "slider", text = "Size", min = 5, max = 60, step = 1,
			  getValue = DBGet(tm.font, "size"), setValue = DBSet(tm.font, "size", gbRefresh) }
		); y = y - h
		_, h = Widgets:TripleRow(parent, y,
			{ type = "dropdown", text = "System Info Font", values = fontValues, order = fontOrder,
			  getValue = DBGet(tm.systemInfoFont, "name"), setValue = DBSet(tm.systemInfoFont, "name", gbRefresh) },
			{ type = "dropdown", text = "Outline", values = FONT_OUTLINE_VALUES, order = FONT_OUTLINE_ORDER,
			  getValue = DBGet(tm.systemInfoFont, "style"), setValue = DBSet(tm.systemInfoFont, "style", gbRefresh) },
			{ type = "slider", text = "Size", min = 5, max = 60, step = 1,
			  getValue = DBGet(tm.systemInfoFont, "size"), setValue = DBSet(tm.systemInfoFont, "size", gbRefresh) }
		); y = y - h

		_, h = Widgets:SectionHeader(parent, "PANELS", y); y = y - h
		local fr = gb.friends
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Show All Friends",
			  tooltip = "Show all friends rather than only friends who are currently playing WoW.",
			  getValue = DBGet(fr, "showAllFriends"), setValue = DBSet(fr, "showAllFriends", gbRefresh), disabled = gbDisabled },
			{ type = "toggle", text = "Count Sub Accounts",
			  tooltip = "Count active WoW sub accounts rather than Battle.net Accounts.",
			  getValue = DBGet(fr, "countSubAccounts"), setValue = DBSet(fr, "countSubAccounts", gbRefresh), disabled = gbDisabled }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Prefer NetEase Meeting Stone",
			  tooltip = "If Meeting Stone is installed, left click the Group Finder button to open NetEase Meeting Stone instead of the Blizzard one.",
			  getValue = DBGet2(gb, "groupFinder", "preferNetEaseMeetingStone"),
			  setValue = DBSet2(gb, "groupFinder", "preferNetEaseMeetingStone", gbRefresh), disabled = gbDisabled },
			{ type = "spacer" }
		); y = y - h

		-- One row per slot index pairs the two panels, so the fourteen dropdowns
		-- take seven rows instead of the two headers and fourteen rows upstream
		-- spent on them.
		local buttonOrder = GetButtonOrder()
		for i = 1, 7 do
			_, h = Widgets:DualRow(parent, y,
				{ type = "dropdown", text = format("%s #%d", L["Left Panel"], i),
				  values = AVAILABLE_BUTTON_VALUES, order = buttonOrder, tooltip = BUTTON_SLOT_TOOLTIP,
				  getValue = function() return GetSlotValue(gb.left, i) end,
				  setValue = function(value) gb.left = gb.left or {}; gb.left[i] = value; gbRefresh() end,
				  disabled = gbDisabled },
				{ type = "dropdown", text = format("%s #%d", L["Right Panel"], i),
				  values = AVAILABLE_BUTTON_VALUES, order = buttonOrder, tooltip = BUTTON_SLOT_TOOLTIP,
				  getValue = function() return GetSlotValue(gb.right, i) end,
				  setValue = function(value) gb.right = gb.right or {}; gb.right[i] = value; gbRefresh() end,
				  disabled = gbDisabled }
			); y = y - h
		end

		return y
	end

	local pv = E.private.WT.misc
	-- Some of these switches arm a hook or install a CVar once at load, so the
	-- best a setter can do is take the value and offer the reload. The rest are
	-- re-read on every callback and are pushed into their module instead.
	local pvSet = function(key)
		return function(value)
			pv[key] = value
			PromptReload()
		end
	end
	local dbSet = function(key, module, method)
		return function(value)
			db[key] = value
			if module then SafeModuleCall(module, method) end
		end
	end
	local automationDisabled = function() return not db.automation.enable end
	local sa = W.Modules.SpellActivationAlert
	local saUpdate = function() SafeModuleCall(sa, "Update") end
	local saPreview = function()
		SafeModuleCall(sa, "Update")
		SafeModuleCall(sa, "Preview")
	end
	local saDisabled = function() return not db.spellActivationAlert.enable end

	_, h = Widgets:SectionHeader(parent, L["MISC"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Pause to slash"],
		  tooltip = L["Just for Chinese and Korean players"],
		  getValue = DBGet(pv, "pauseToSlash"), setValue = pvSet("pauseToSlash") },
		{ type = "toggle", text = L["Math Without Kanji"],
		  tooltip = L["Use alphabet rather than kanji (Only for Chinese players)"],
		  getValue = DBGet(pv, "noKanjiMath"), setValue = pvSet("noKanjiMath") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Disable Talking Head"],
		  tooltip = L["Disable Blizzard Talking Head."],
		  getValue = DBGet(db, "disableTalkingHead"), setValue = dbSet("disableTalkingHead") },
		{ type = "toggle", text = L["Hide Crafter"],
		  tooltip = L["Hide crafter name in the item tooltip."],
		  getValue = DBGet(db, "hideCrafter"), setValue = dbSet("hideCrafter") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["No Loot Panel"],
		  tooltip = L["Disable Blizzard loot info which auto showing after combat overed."],
		  getValue = DBGet(db, "noLootPanel"),
		  setValue = dbSet("noLootPanel", W.Modules.Misc, "LootPanel") },
		{ type = "toggle", text = L["Guild News IL"],
		  tooltip = L["Show item level of each item in guild news."],
		  getValue = DBGet(pv, "guildNewsItemLevel"), setValue = pvSet("guildNewsItemLevel") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Skip Cut Scene"],
		  getValue = DBGet(pv, "skipCutScene"),
		  setValue = function(value)
			  pv.skipCutScene = value
			  SafeModuleCall(W.Modules.Misc, "SkipCutScene")
			  PromptReload()
		  end },
		{ type = "toggle", text = L["Only Watched"],
		  tooltip = L["Only skip watched cut scene. (some cut scenes can't be skipped)"],
		  disabled = function() return not pv.skipCutScene end,
		  getValue = DBGet(pv, "onlyStopWatched"), setValue = DBSet(pv, "onlyStopWatched") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["View SC Group"],
		  tooltip = L["Let you can view the group created by Simplified Chinese players."],
		  getValue = DBGet(pv, "addCNFilter"), setValue = pvSet("addCNFilter") },
		{ type = "toggle", text = L["Anti-override"],
		  tooltip = L["Unblock the profanity filter and disable model override."],
		  getValue = DBGet(pv, "antiOverride"), setValue = pvSet("antiOverride") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Auto Toggle Chat Bubble"],
		  tooltip = L["Only show chat bubble in instance."],
		  getValue = DBGet(pv, "autoToggleChatBubble"), setValue = pvSet("autoToggleChatBubble") },
		(E.Forever and { type = "spacer" } or
		 { type = "toggle", text = L["Reshii Wraps Upgrade"],
		   tooltip = L["Middle click the character back slot to open the Reshii Wraps upgrade menu."],
		   getValue = DBGet(pv, "reshiiWrapsUpgrade"), setValue = pvSet("reshiiWrapsUpgrade") })
	); y = y - h

	_, h = Widgets:SectionHeader(parent, L["AUTOMATION"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Enable"],
		  getValue = DBGet(db.automation, "enable"),
		  setValue = dbSet("enable", W.Modules.Automation, "ProfileUpdate") },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Auto Hide Map"],
		  tooltip = L["Automatically close world map if player enters combat."],
		  disabled = automationDisabled,
		  getValue = DBGet(db.automation, "hideWorldMapAfterEnteringCombat"),
		  setValue = dbSet("hideWorldMapAfterEnteringCombat") },
		{ type = "toggle", text = L["Auto Hide Bag"],
		  tooltip = L["Automatically close bag if player enters combat."],
		  disabled = automationDisabled,
		  getValue = DBGet(db.automation, "hideBagAfterEnteringCombat"),
		  setValue = dbSet("hideBagAfterEnteringCombat") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Accept Resurrect"],
		  tooltip = L["Accept resurrect from other player automatically when you not in combat."],
		  disabled = automationDisabled,
		  getValue = DBGet(db.automation, "acceptResurrect"),
		  setValue = dbSet("acceptResurrect") },
		{ type = "toggle", text = L["Accept Combat Resurrect"],
		  tooltip = L["Accept resurrect from other player automatically when you in combat."],
		  disabled = automationDisabled,
		  getValue = DBGet(db.automation, "acceptCombatResurrect"),
		  setValue = dbSet("acceptCombatResurrect") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Confirm Summon"],
		  tooltip = L["Confirm summon from other player automatically."],
		  disabled = automationDisabled,
		  getValue = DBGet(db.automation, "confirmSummon"),
		  setValue = dbSet("confirmSummon") },
		{ type = "spacer" }
	); y = y - h

	-- Move Frames walks the whole frame tree once at login, so toggling it has to
	-- go through a reload; the leaf switches are read on demand and do not.
	local mv = pv.moveFrames
	-- A running BlizzMove or MoveAnything owns the frames already, and this file
	-- cannot unseat them, so every row below stays off in that case.
	local mvBlocked = function()
		return (W.Modules.MoveFrames and W.Modules.MoveFrames.StopRunning) and true or false
	end
	local mvDisabled = function() return mvBlocked() or not mv.enable end
	_, h = Widgets:SectionHeader(parent, L["MOVE FRAMES"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Enable"],
		  disabled = mvBlocked,
		  getValue = DBGet(mv, "enable"),
		  setValue = function(value) mv.enable = value; PromptReload() end },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["TSM Compatible"],
		  tooltip = L["Fix the merchant frame showing when you using Trader Skill Master."],
		  disabled = mvDisabled,
		  getValue = DBGet(mv, "tradeSkillMasterCompatible"),
		  setValue = DBSet(mv, "tradeSkillMasterCompatible") },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Remember Positions"], disabled = mvDisabled,
		  getValue = DBGet(mv, "rememberPositions"), setValue = DBSet(mv, "rememberPositions") },
		{ type = "toggle", text = L["Auto Reset Off-screen Frames"],
		  tooltip = L["Automatically clear the remembered position if the frame is off the screen."],
		  disabled = mvDisabled,
		  getValue = DBGet(mv, "autoResetOffScreenFrames"),
		  setValue = DBSet(mv, "autoResetOffScreenFrames") }
	); y = y - h
	_, h = Widgets:Button(parent, L["Clear History"], y, function()
		mv.framePositions = {}
	end); y = y - h

	local mute = pv.mute
	local muteDisabled = function() return not mute.enable end
	local muteSet = function(key)
		return function(value)
			mute[key] = value
			SafeModuleCall(W.Modules.Misc, "Mute")
		end
	end
	_, h = Widgets:SectionHeader(parent, L["MUTE"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Enable"],
		  tooltip = L["Disable some annoying sound effects."],
		  getValue = DBGet(mute, "enable"), setValue = muteSet("enable") },
		{ type = "spacer" }
	); y = y - h
	local mountIDs = { 63796, 229385, 339588, 312762, 40192, 121820 }
	local mountRows = {}
	for _, mountID in ipairs(mountIDs) do
		-- The mount journal already localises these names; fall back to the id
		-- when the API is missing so the row still says something usable.
		local name = "#" .. mountID
		if C_MountJournal and C_MountJournal.GetMountInfoByID then
			local mountName = C_MountJournal.GetMountInfoByID(mountID)
			if mountName and mountName ~= "" then name = mountName end
		end
		mountRows[#mountRows + 1] = { type = "toggle", text = name, disabled = muteDisabled,
			getValue = function() return mute.mount[mountID] end,
			setValue = function(value)
				mute.mount[mountID] = value
				SafeModuleCall(W.Modules.Misc, "Mute")
			end }
	end
	for i = 1, #mountRows, 2 do
		_, h = Widgets:DualRow(parent, y, mountRows[i], mountRows[i + 1] or { type = "spacer" })
		y = y - h
	end
	-- Two of these are item names rather than phrases, so they come from the
	-- item cache; translating them in the catalog would only drift.
	local otherKeys = {
		{ "Tortollan" },
		{ "Crying" },
		{ "Dragon" },
		{ "Jewelcrafting" },
		{ "Smolderheart", 180873 },
		{ "Elegy of the Eternals", 188270 },
	}
	local otherRows = {}
	for _, entry in ipairs(otherKeys) do
		local key, itemID = entry[1], entry[2]
		local text = L[key]
		if itemID then
			local itemName = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID)
			if itemName then text = itemName end
		end
		otherRows[#otherRows + 1] = { type = "toggle", text = text, disabled = muteDisabled,
			getValue = function() return mute.other[key] end,
			setValue = function(value)
				mute.other[key] = value
				SafeModuleCall(W.Modules.Misc, "Mute")
			end }
	end
	for i = 1, #otherRows, 2 do
		_, h = Widgets:DualRow(parent, y, otherRows[i], otherRows[i + 1] or { type = "spacer" })
		y = y - h
	end

	local saDB = db.spellActivationAlert
	_, h = Widgets:SectionHeader(parent, L["SPELL ACTIVATION ALERT"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = L["Enable"], tooltip = L["Spell activation alert frame customizations."],
		  getValue = DBGet(saDB, "enable"),
		  setValue = function(value) saDB.enable = value; saUpdate() end },
		{ type = "toggle", text = L["Visibility"], disabled = saDisabled,
		  getValue = CVarGetBool("displaySpellActivationOverlays"),
		  setValue = CVarSetBool("displaySpellActivationOverlays") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = L["Opacity"], min = 0, max = 1, step = 0.01, disabled = saDisabled,
		  getValue = CVarGetNum("spellActivationOverlayOpacity"),
		  setValue = function(value) CVarSetNum("spellActivationOverlayOpacity")(value); saPreview() end },
		{ type = "slider", text = L["Scale"], min = 0.1, max = 5, step = 0.01, disabled = saDisabled,
		  getValue = DBGet(saDB, "scale"),
		  setValue = function(value) saDB.scale = value; saPreview() end }
	); y = y - h

	if not E.Forever then
		local epd = db.exitPhaseDiving
		local epdDisabled = function() return not epd.enable end
		_, h = Widgets:SectionHeader(parent, L["EXIT PHASE DIVING"], y); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = L["Enable"], tooltip = L["Add a button to exit phase diving."],
			  getValue = DBGet(epd, "enable"),
			  setValue = function(value)
				  epd.enable = value
				  SafeModuleCall(W.Modules.Misc, "UpdateExitPhaseDivingButton")
			  end },
			{ type = "spacer" }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = L["Width"], min = 5, max = 1000, step = 1, disabled = epdDisabled,
			  getValue = DBGet(epd, "width"),
			  setValue = function(value)
				  epd.width = value
				  SafeModuleCall(W.Modules.Misc, "UpdateExitPhaseDivingButton")
			  end },
			{ type = "slider", text = L["Height"], min = 5, max = 1000, step = 1, disabled = epdDisabled,
			  getValue = DBGet(epd, "height"),
			  setValue = function(value)
				  epd.height = value
				  SafeModuleCall(W.Modules.Misc, "UpdateExitPhaseDivingButton")
			  end }
		); y = y - h
	end

	-- Everything below this line writes client CVars rather than addon state.
	_, h = Widgets:SectionHeader(parent, L["CVARS"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Auto Compare", tooltip = "Always compare items when hovering over them.",
		  getValue = CVarGetBool("alwaysCompareItems"), setValue = CVarSetBool("alwaysCompareItems") },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Screenshot Quality", min = 1, max = 10, step = 1,
		  getValue = CVarGetNum("screenshotQuality"), setValue = CVarSetNum("screenshotQuality") },
		{ type = "dropdown", text = "Screenshot Format",
		  values = SCREENSHOT_FORMAT_VALUES, order = SCREENSHOT_FORMAT_ORDER,
		  getValue = CVarGetStr("screenshotFormat"), setValue = CVarSetStr("screenshotFormat") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Glow Effect", getValue = CVarGetBool("ffxGlow"), setValue = CVarSetBool("ffxGlow") },
		{ type = "toggle", text = "Death Effect", getValue = CVarGetBool("ffxDeath"), setValue = CVarSetBool("ffxDeath") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Nether Effect", getValue = CVarGetBool("ffxNether"), setValue = CVarSetBool("ffxNether") },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Raw Mouse",
		  tooltip = "It will fix the problem if your cursor has abnormal movement.",
		  getValue = CVarGetBool("rawMouseEnable"), setValue = CVarSetBool("rawMouseEnable") },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Acceleration Type", values = MOUSE_ACCEL_VALUES, order = MOUSE_ACCEL_ORDER,
		  getValue = CVarGetStr("mouseAcceleration"), setValue = CVarSetStr("mouseAcceleration") },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Action on keydown",
		  tooltip = "Trigger the action when pressing the key down rather than releasing it.",
		  getValue = CVarGetBool("ActionButtonUseKeyDown"), setValue = CVarSetBool("ActionButtonUseKeyDown") },
		{ type = "spacer" }
	); y = y - h

	_, h = Widgets:SectionHeader(parent, "COMBAT", y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Floating Damage Text",
		  getValue = CVarGetBool("floatingCombatTextCombatDamage_v2"),
		  setValue = CVarSetBool("floatingCombatTextCombatDamage_v2") },
		{ type = "toggle", text = "Floating Healing Text",
		  getValue = CVarGetBool("floatingCombatTextCombatHealing_v2"),
		  setValue = CVarSetBool("floatingCombatTextCombatHealing_v2") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Floating Text Scale", min = 0.1, max = 5, step = 0.1,
		  getValue = CVarGetNum("WorldTextScale_v2"), setValue = CVarSetNum("WorldTextScale_v2") },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Spell Queue Window", min = 0, max = 400, step = 1,
		  getValue = CVarGetNum("SpellQueueWindow"), setValue = CVarSetNum("SpellQueueWindow") },
		{ type = "slider", text = "Camera Max Zoom", min = 1, max = 2.6, step = 0.01,
		  getValue = CVarGetNum("cameraDistanceMaxZoomFactor"),
		  setValue = CVarSetNum("cameraDistanceMaxZoomFactor") }
	); y = y - h

	return y
end)
