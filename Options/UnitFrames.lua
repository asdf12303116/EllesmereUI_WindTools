local addon = select(2, ...)
local W = addon[1]
local E = addon[3]
local DBGet = addon.DBGet
local DBSet = addon.DBSet

local MODIFIER_VALUES = { shift = "Shift Key", ctrl = "Ctrl Key", alt = "Alt Key" }
local MODIFIER_ORDER = { "shift", "ctrl", "alt" }

local BUTTON_VALUES = {
	BUTTON1 = "Left Button", BUTTON2 = "Right Button", BUTTON3 = "Middle Button",
	BUTTON4 = "Side Button 4", BUTTON5 = "Side Button 5",
}
local BUTTON_ORDER = { "BUTTON1", "BUTTON2", "BUTTON3", "BUTTON4", "BUTTON5" }

local MARK_VALUES = {
	[1] = "Star", [2] = "Circle", [3] = "Diamond", [4] = "Triangle",
	[5] = "Moon", [6] = "Square", [7] = "Cross", [8] = "Skull",
}
local MARK_ORDER = { 1, 2, 3, 4, 5, 6, 7, 8 }

local function UpdateQuickFocus()
	addon.SafeModuleCall(W.Modules.QuickFocus, "ProfileUpdate")
end

local function ToggleQuickFocus()
	UpdateQuickFocus()
	if addon.RefreshOptions then
		addon.RefreshOptions()
	end
end

local function UpdateFriendlyNameplateOutline()
	addon.SafeModuleCall(W.Modules.FriendlyNameplateOutline, "ProfileUpdate")
end

local function BuildQuickFocus(parent, y, cat)
	local MH = function(mod, sub) return addon.MakeHeader(cat, mod, sub) end
	local Widgets = EllesmereUI.Widgets
	local _, h
	local qf = E.private.WT.unitFrames.quickFocus
	local qfDis = function() return not qf.enable end
	_, h = Widgets:SectionHeader(parent, MH("Quick Focus"), y); y = y - h
	_, h = Widgets:Toggle(parent, "Enable", y,
		DBGet(qf, "enable"), DBSet(qf, "enable", ToggleQuickFocus),
		"Focus the mouseover unit with a modifier key + mouse button."); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Modifier Key",
		  values = MODIFIER_VALUES, order = MODIFIER_ORDER,
		  getValue = DBGet(qf, "modifier"), setValue = DBSet(qf, "modifier", UpdateQuickFocus), disabled = qfDis },
		{ type = "dropdown", text = "Button",
		  values = BUTTON_VALUES, order = BUTTON_ORDER,
		  getValue = DBGet(qf, "button"), setValue = DBSet(qf, "button", UpdateQuickFocus), disabled = qfDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Set Mark", tooltip = "Set the raid marker on the quick focused target if possible.",
		  getValue = DBGet(qf, "setMark"), setValue = DBSet(qf, "setMark", UpdateQuickFocus), disabled = qfDis },
		{ type = "dropdown", text = "Mark",
		  values = MARK_VALUES, order = MARK_ORDER,
		  getValue = DBGet(qf, "markNumber"), setValue = DBSet(qf, "markNumber", UpdateQuickFocus), disabled = qfDis }
	); y = y - h
	return y
end

local function BuildFriendlyNameplateOutline(parent, y, cat)
	local MH = function(mod, sub) return addon.MakeHeader(cat, mod, sub) end
	local Widgets = EllesmereUI.Widgets
	local _, h
	local fn = E.db.WT.unitFrames.friendlyNameplateOutline
	_, h = Widgets:SectionHeader(parent, MH("Friendly Nameplate Outline"), y); y = y - h
	_, h = Widgets:Toggle(parent, "Enable", y,
		DBGet(fn, "enable"), DBSet(fn, "enable", UpdateFriendlyNameplateOutline),
		"Sync the EllesmereUI friendly nameplate outline style to the system nameplate fonts, and keep friendly nameplates visible in follower dungeons. Requires the EllesmereUI nameplates module with friendly Name Only mode."); y = y - h
	return y
end

-- Only Quick Focus and Friendly Nameplate Outline are loaded (see
-- Modules/Load_Modules.xml). Absorb, Role Icon and Name Clip used to be built
-- here as disabled groups; they are gone instead, so the page offers nothing it
-- cannot deliver.
addon.RegisterOptionBuilder("unitFrames", function(parent, y, cat)
	local Widgets = EllesmereUI.Widgets
	y = BuildQuickFocus(parent, y, cat)
	local _, sh = Widgets:Spacer(parent, y, 8); y = y - sh
	return BuildFriendlyNameplateOutline(parent, y, cat)
end)
