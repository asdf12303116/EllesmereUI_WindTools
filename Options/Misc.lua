local addon = select(2, ...)
local W = addon[1]
local E = addon[3]

local DBGet = addon.DBGet
local DBSet = addon.DBSet
local DBGet2 = addon.DBGet2
local DBSet2 = addon.DBSet2
local SafeModuleCall = addon.SafeModuleCall
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
	HOME = "Home",
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

local function FontSection(Widgets, parent, y, dbTable)
	local _, h
	local fonts = GetLSMFonts()
	local fontOrder = {}
	for k in pairs(fonts) do fontOrder[#fontOrder + 1] = k end
	table.sort(fontOrder)
	_, h = Widgets:Dropdown(parent, "Font", y, fonts, DBGet(dbTable, "name"), DBSet(dbTable, "name"), fontOrder); y = y - h
	_, h = Widgets:Dropdown(parent, "Outline", y,
		FONT_OUTLINE_VALUES,
		DBGet(dbTable, "style"), DBSet(dbTable, "style"),
		FONT_OUTLINE_ORDER); y = y - h
	_, h = Widgets:Slider(parent, "Size", y, 5, 60, 1,
		DBGet(dbTable, "size"), DBSet(dbTable, "size")); y = y - h
	return y
end

-- The category still covers two pages: the CVars editor belongs to General and
-- the game bar to its own page. Everything else this file used to build belongs
-- to modules that are not loaded (Move Frames, Mute, LFG List, Spell Activation
-- Alert, Keybind Alias), so those sections are gone rather than greyed out: a
-- control with no module behind it would only lie about what the addon does.
addon.RegisterOptionBuilder("misc", function(parent, y, cat, subPage)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local db = E.db.WT.misc
	local MH = function(mod, sub) return addon.MakeHeader(cat, mod, sub) end

	if subPage == "Game Bar" then
		_, h = Widgets:SectionHeader(parent, MH("Game Bar"), y); y = y - h
		do
			local gb = db.gameBar
			local gbDisabled = function() return not gb.enable end
			-- Every Game Bar setting is read when the bar redraws, so pushing the
			-- change straight into the module keeps the bar honest without a reload.
			local gbRefresh = function() SafeModuleCall(W.Modules.GameBar, "ProfileUpdate") end
			_, h = Widgets:Toggle(parent, "Enable", y,
				DBGet(gb, "enable"), DBSet(gb, "enable", gbRefresh),
				"Toggle the game bar."); y = y - h

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "General"), y); y = y - h
			_, h = Widgets:Toggle(parent, "Bar Backdrop", y,
				DBGet(gb, "backdrop"), DBSet(gb, "backdrop", gbRefresh), "Show a backdrop of the bar."); y = y - h
			_, h = Widgets:DualRow(parent, y,
				{ type = "slider", text = "Backdrop Spacing", min = 1, max = 30, step = 1,
				  getValue = DBGet(gb, "backdropSpacing"), setValue = DBSet(gb, "backdropSpacing", gbRefresh),
				  tooltip = "The spacing between the backdrop and the buttons.", disabled = gbDisabled },
				{ type = "slider", text = "Button Spacing", min = 1, max = 30, step = 1,
				  getValue = DBGet(gb, "spacing"), setValue = DBSet(gb, "spacing", gbRefresh),
				  tooltip = "The spacing between buttons.", disabled = gbDisabled }
			); y = y - h
			_, h = Widgets:DualRow(parent, y,
				{ type = "slider", text = "Time Area Width", min = 1, max = 200, step = 1,
				  getValue = DBGet(gb, "timeAreaWidth"), setValue = DBSet(gb, "timeAreaWidth", gbRefresh), disabled = gbDisabled },
				{ type = "slider", text = "Time Area Height", min = 1, max = 100, step = 1,
				  getValue = DBGet(gb, "timeAreaHeight"), setValue = DBSet(gb, "timeAreaHeight", gbRefresh), disabled = gbDisabled }
			); y = y - h
			_, h = Widgets:Slider(parent, "Button Size", y, 2, 80, 1,
				DBGet(gb, "buttonSize"), DBSet(gb, "buttonSize", gbRefresh),
				"The size of the buttons."); y = y - h

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Display"), y); y = y - h
			_, h = Widgets:DualRow(parent, y,
				{ type = "toggle", text = "Mouse Over", tooltip = "Show the bar only when the mouse is hovered over the area.",
				  getValue = DBGet(gb, "mouseOver"), setValue = DBSet(gb, "mouseOver", gbRefresh), disabled = gbDisabled },
				{ type = "toggle", text = "Notification", tooltip = "Add an indicator icon to buttons.",
				  getValue = DBGet(gb, "notification"), setValue = DBSet(gb, "notification", gbRefresh), disabled = gbDisabled }
			); y = y - h
			_, h = Widgets:DualRow(parent, y,
				{ type = "slider", text = "Fade Time", min = 0, max = 3, step = 0.01,
				  getValue = DBGet(gb, "fadeTime"), setValue = DBSet(gb, "fadeTime", gbRefresh),
				  tooltip = "The animation speed.", disabled = gbDisabled },
				{ type = "dropdown", text = "Tooltip Anchor",
				  values = TOOLTIP_ANCHOR_VALUES, order = TOOLTIP_ANCHOR_ORDER,
				  getValue = DBGet(gb, "tooltipsAnchor"), setValue = DBSet(gb, "tooltipsAnchor", gbRefresh), disabled = gbDisabled }
			); y = y - h

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Animation"), y); y = y - h
			_, h = Widgets:Slider(parent, "Duration", y, 0, 3, 0.01,
				DBGet2(gb, "animation", "duration"), DBSet2(gb, "animation", "duration", gbRefresh),
				"The duration of the animation in seconds."); y = y - h
			_, h = Widgets:DualRow(parent, y,
				{ type = "dropdown", text = "Ease",
				  values = ANIMATION_EASE_VALUES, order = ANIMATION_EASE_ORDER,
				  getValue = DBGet2(gb, "animation", "ease"),
				  setValue = DBSet2(gb, "animation", "ease", gbRefresh),
				  tooltip = "The easing function used for colorize the button." },
				{ type = "toggle", text = "Invert Ease",
				  getValue = DBGet2(gb, "animation", "easeInvert"),
				  setValue = DBSet2(gb, "animation", "easeInvert", gbRefresh) }
			); y = y - h

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Normal Color"), y); y = y - h
			_, h = Widgets:Dropdown(parent, "Mode", y,
				COLOR_MODE_VALUES,
				DBGet(gb, "normalColor"), DBSet(gb, "normalColor", gbRefresh),
				COLOR_MODE_ORDER); y = y - h
			if gb.normalColor == "CUSTOM" then
				_, h = Widgets:ColorPicker(parent, "Custom Color", y,
					function()
						local c = gb.customNormalColor or {}
						return c.r or 1, c.g or 1, c.b or 1, c.a or 1
					end,
					function(r, g, b, a)
						gb.customNormalColor = gb.customNormalColor or {}
						gb.customNormalColor.r, gb.customNormalColor.g, gb.customNormalColor.b = r, g, b
						gb.customNormalColor.a = a
					end, true); y = y - h
			end

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Hover Color"), y); y = y - h
			_, h = Widgets:Dropdown(parent, "Mode", y,
				COLOR_MODE_VALUES,
				DBGet(gb, "hoverColor"), DBSet(gb, "hoverColor", gbRefresh),
				COLOR_MODE_ORDER); y = y - h
			if gb.hoverColor == "CUSTOM" then
				_, h = Widgets:ColorPicker(parent, "Custom Color", y,
					function()
						local c = gb.customHoverColor or {}
						return c.r or 0, c.g or 0.659, c.b or 1, c.a or 1
					end,
					function(r, g, b, a)
						gb.customHoverColor = gb.customHoverColor or {}
						gb.customHoverColor.r, gb.customHoverColor.g, gb.customHoverColor.b = r, g, b
						gb.customHoverColor.a = a
					end, true); y = y - h
			end

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Additional Text"), y); y = y - h
			do
				local at = gb.additionalText
				_, h = Widgets:DualRow(parent, y,
					{ type = "toggle", text = "Enable",
					  getValue = DBGet(at, "enable"), setValue = DBSet(at, "enable", gbRefresh), disabled = gbDisabled },
					{ type = "toggle", text = "Slow Mode", tooltip = "Update the additional text every 10 seconds rather than every 1 second such that the used memory will be lower.",
					  getValue = DBGet(at, "slowMode"), setValue = DBSet(at, "slowMode", gbRefresh), disabled = gbDisabled }
				); y = y - h
				_, h = Widgets:DualRow(parent, y,
					{ type = "dropdown", text = "Anchor Point",
					  values = ANCHOR_VALUES, order = ANCHOR_ORDER,
					  getValue = DBGet(at, "anchor"), setValue = DBSet(at, "anchor", gbRefresh), disabled = gbDisabled },
					{ type = "spacer" }
				); y = y - h
				_, h = Widgets:DualRow(parent, y,
					{ type = "slider", text = "X-Offset", min = -100, max = 100, step = 1,
					  getValue = DBGet(at, "x"), setValue = DBSet(at, "x", gbRefresh), disabled = gbDisabled },
					{ type = "slider", text = "Y-Offset", min = -100, max = 100, step = 1,
					  getValue = DBGet(at, "y"), setValue = DBSet(at, "y", gbRefresh), disabled = gbDisabled }
				); y = y - h
				y = FontSection(Widgets, parent, y, at.font)
			end

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Time"), y); y = y - h
			do
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
					{ type = "toggle", text = "Avoid Reload in Combat", tooltip = "Disable the middle click UI reloading in combat.",
					  getValue = DBGet(tm, "avoidReloadInCombat"), setValue = DBSet(tm, "avoidReloadInCombat", gbRefresh), disabled = gbDisabled }
				); y = y - h
				_, h = Widgets:DualRow(parent, y,
					{ type = "toggle", text = "Always Show System Info", tooltip = "The system information will be always shown rather than showing only being hovered.",
					  getValue = DBGet(tm, "alwaysSystemInfo"), setValue = DBSet(tm, "alwaysSystemInfo", gbRefresh), disabled = gbDisabled },
					{ type = "slider", text = "Interval", min = 1, max = 60, step = 1,
					  getValue = DBGet(tm, "interval"), setValue = DBSet(tm, "interval", gbRefresh),
					  tooltip = "The interval of updating.", disabled = gbDisabled }
				); y = y - h
				y = FontSection(Widgets, parent, y, tm.font)
				_, h = Widgets:SectionHeader(parent, MH("Game Bar", "System Info Font"), y); y = y - h
				y = FontSection(Widgets, parent, y, tm.systemInfoFont)
			end

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Friends"), y); y = y - h
			do
				local fr = gb.friends
				_, h = Widgets:DualRow(parent, y,
					{ type = "toggle", text = "Show All Friends", tooltip = "Show all friends rather than only friends who are currently playing WoW.",
					  getValue = DBGet(fr, "showAllFriends"), setValue = DBSet(fr, "showAllFriends", gbRefresh), disabled = gbDisabled },
					{ type = "toggle", text = "Count Sub Accounts", tooltip = "Count active WoW sub accounts rather than Battle.net Accounts.",
					  getValue = DBGet(fr, "countSubAccounts"), setValue = DBSet(fr, "countSubAccounts", gbRefresh), disabled = gbDisabled }
				); y = y - h
			end

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Group Finder"), y); y = y - h
			_, h = Widgets:Toggle(parent, "Prefer NetEase Meeting Stone", y,
				DBGet2(gb, "groupFinder", "preferNetEaseMeetingStone"),
				DBSet2(gb, "groupFinder", "preferNetEaseMeetingStone", gbRefresh),
				"If Meeting Stone is installed, left click the Group Finder button to open NetEase Meeting Stone instead of the Blizzard one."); y = y - h

			local buttonOrder = GetButtonOrder()

			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Left Panel"), y); y = y - h
			for i = 1, 7 do
				_, h = Widgets:Dropdown(parent, ("Button #%d"):format(i), y,
					AVAILABLE_BUTTON_VALUES,
					function() return GetSlotValue(gb.left, i) end,
					function(v) gb.left = gb.left or {}; gb.left[i] = v; gbRefresh() end,
					buttonOrder, BUTTON_SLOT_TOOLTIP); y = y - h
			end
			_, h = Widgets:SectionHeader(parent, MH("Game Bar", "Right Panel"), y); y = y - h
			for i = 1, 7 do
				_, h = Widgets:Dropdown(parent, ("Button #%d"):format(i), y,
					AVAILABLE_BUTTON_VALUES,
					function() return GetSlotValue(gb.right, i) end,
					function(v) gb.right = gb.right or {}; gb.right[i] = v; gbRefresh() end,
					buttonOrder, BUTTON_SLOT_TOOLTIP); y = y - h
			end
		end

		return y
	end

	-- General page: the CVars editor is the only part of this file with a real
	-- backend, because it writes client CVars rather than addon module state.
	_, h = Widgets:SectionHeader(parent, MH("CVars Editor"), y); y = y - h
	do
		_, h = Widgets:SectionHeader(parent, MH("CVars Editor", "General"), y); y = y - h
		_, h = Widgets:Toggle(parent, "Auto Compare", y,
			CVarGetBool("alwaysCompareItems"), CVarSetBool("alwaysCompareItems"),
			"Always compare items when hovering over them."); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Screenshot Quality", min = 1, max = 10, step = 1,
			  getValue = CVarGetNum("screenshotQuality"), setValue = CVarSetNum("screenshotQuality") },
			{ type = "dropdown", text = "Screenshot Format",
			  values = SCREENSHOT_FORMAT_VALUES, order = SCREENSHOT_FORMAT_ORDER,
			  getValue = CVarGetStr("screenshotFormat"), setValue = CVarSetStr("screenshotFormat") }
		); y = y - h

		_, h = Widgets:SectionHeader(parent, MH("CVars Editor", "Combat"), y); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Floating Damage Text",
			  getValue = CVarGetBool("floatingCombatTextCombatDamage_v2"),
			  setValue = CVarSetBool("floatingCombatTextCombatDamage_v2") },
			{ type = "toggle", text = "Floating Healing Text",
			  getValue = CVarGetBool("floatingCombatTextCombatHealing_v2"),
			  setValue = CVarSetBool("floatingCombatTextCombatHealing_v2") }
		); y = y - h
		_, h = Widgets:Slider(parent, "Floating Text Scale", y, 0.1, 5, 0.1,
			CVarGetNum("WorldTextScale_v2"), CVarSetNum("WorldTextScale_v2")); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Spell Queue Window", min = 0, max = 400, step = 1,
			  getValue = CVarGetNum("SpellQueueWindow"), setValue = CVarSetNum("SpellQueueWindow") },
			{ type = "slider", text = "Camera Max Zoom", min = 1, max = 2.6, step = 0.01,
			  getValue = CVarGetNum("cameraDistanceMaxZoomFactor"),
			  setValue = CVarSetNum("cameraDistanceMaxZoomFactor") }
		); y = y - h

		_, h = Widgets:SectionHeader(parent, MH("CVars Editor", "Visual Effect"), y); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Glow Effect", getValue = CVarGetBool("ffxGlow"), setValue = CVarSetBool("ffxGlow") },
			{ type = "toggle", text = "Death Effect", getValue = CVarGetBool("ffxDeath"), setValue = CVarSetBool("ffxDeath") }
		); y = y - h
		_, h = Widgets:Toggle(parent, "Nether Effect", y,
			CVarGetBool("ffxNether"), CVarSetBool("ffxNether")); y = y - h

		_, h = Widgets:SectionHeader(parent, MH("CVars Editor", "Control"), y); y = y - h
		_, h = Widgets:Toggle(parent, "Raw Mouse", y,
			CVarGetBool("rawMouseEnable"), CVarSetBool("rawMouseEnable"),
			"It will fix the problem if your cursor has abnormal movement."); y = y - h
		_, h = Widgets:Dropdown(parent, "Acceleration Type", y,
			MOUSE_ACCEL_VALUES,
			CVarGetStr("mouseAcceleration"), CVarSetStr("mouseAcceleration"),
			MOUSE_ACCEL_ORDER); y = y - h
		_, h = Widgets:Toggle(parent, "Action on keydown", y,
			CVarGetBool("ActionButtonUseKeyDown"), CVarSetBool("ActionButtonUseKeyDown"),
			"Trigger the action when pressing the key down rather than releasing it."); y = y - h
	end

	return y
end)
