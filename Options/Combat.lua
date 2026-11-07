local addon = select(2, ...)
local W = addon[1]
local E = addon[3]
local DBGet = addon.DBGet
local DBSet = addon.DBSet

local ORIENTATION_VALUES = { HORIZONTAL = "Horizontal", VERTICAL = "Vertical" }
local ORIENTATION_ORDER = { "HORIZONTAL", "VERTICAL" }

local VISIBILITY_VALUES = { DEFAULT = "Default", INPARTY = "In Party", ALWAYS = "Always Display" }
local VISIBILITY_ORDER = { "DEFAULT", "INPARTY", "ALWAYS" }

local MODIFIER_VALUES = { shift = "Shift Key", ctrl = "Ctrl Key", alt = "Alt Key" }
local MODIFIER_ORDER = { "shift", "ctrl", "alt" }

local function DBGetDefault(t, k, default)
	return function()
		local v = t and t[k]
		if v == nil then return default end
		return v
	end
end

local function UpdateRaidMarkers()
	addon.SafeModuleCall(W.Modules.RaidMarkers, "ProfileUpdate")
end

local function ToggleRaidMarkers()
	UpdateRaidMarkers()
	if addon.RefreshOptions then
		addon.RefreshOptions()
	end
end

-- Only Raid Markers is loaded (see Modules/Load_Modules.xml). Combat Alert,
-- Quick Tools and Damage Meter Layout used to be built here as disabled groups;
-- they are gone instead, so the page offers nothing it cannot deliver.
local function BuildRaidMarkers(parent, y, cat)
	local Widgets = EllesmereUI.Widgets
	local MH = function(mod, sub) return addon.MakeHeader(cat, mod, sub) end
	local _, h
	local rm = E.db.WT.combat.raidMarkers
	local rmDis = function() return not rm.enable end
	_, h = Widgets:SectionHeader(parent, MH("Raid Markers"), y); y = y - h
	_, h = Widgets:Toggle(parent, "Enable", y,
		DBGet(rm, "enable"), DBSet(rm, "enable", ToggleRaidMarkers),
		"Enable the raid markers bar."); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Inverse Mode",
		  getValue = DBGet(rm, "inverse"), setValue = DBSet(rm, "inverse", UpdateRaidMarkers),
		  tooltip = "Swap the functionality of normal click and click with modifier keys.",
		  disabled = rmDis },
		{ type = "spacer" }); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Button Size", min = 15, max = 80, step = 1,
		  getValue = DBGetDefault(rm, "buttonSize", 30), setValue = DBSet(rm, "buttonSize", UpdateRaidMarkers),
		  tooltip = "Size of the marker buttons.", disabled = rmDis },
		{ type = "slider", text = "Button Spacing", min = 1, max = 30, step = 1,
		  getValue = DBGetDefault(rm, "spacing", 4), setValue = DBSet(rm, "spacing", UpdateRaidMarkers),
		  tooltip = "Spacing between the marker buttons.", disabled = rmDis }
	); y = y - h
	_, h = Widgets:SectionHeader(parent, MH("Raid Markers", "Visibility"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Visibility",
		  values = VISIBILITY_VALUES, order = VISIBILITY_ORDER,
		  getValue = DBGetDefault(rm, "visibility", "DEFAULT"), setValue = DBSet(rm, "visibility", UpdateRaidMarkers),
		  disabled = rmDis },
		{ type = "spacer" }); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Mouse Over", tooltip = "Only show raid markers bar when you mouse over it.",
		  getValue = DBGet(rm, "mouseOver"), setValue = DBSet(rm, "mouseOver", UpdateRaidMarkers), disabled = rmDis },
		{ type = "toggle", text = "Tooltip", tooltip = "Show the tooltip when you mouse over the button.",
		  getValue = DBGet(rm, "tooltip"), setValue = DBSet(rm, "tooltip", UpdateRaidMarkers), disabled = rmDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Modifier Key",
		  values = MODIFIER_VALUES, order = MODIFIER_ORDER,
		  getValue = DBGet(rm, "modifier"), setValue = DBSet(rm, "modifier", UpdateRaidMarkers),
		  tooltip = "Set the modifier key for placing world markers.", disabled = rmDis },
		{ type = "spacer" }); y = y - h
	_, h = Widgets:SectionHeader(parent, MH("Raid Markers", "Bar"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Bar Backdrop",
		  getValue = DBGet(rm, "backdrop"), setValue = DBSet(rm, "backdrop", UpdateRaidMarkers),
		  tooltip = "Show a backdrop of the bar.", disabled = rmDis },
		{ type = "spacer" }); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Backdrop Spacing", min = 1, max = 30, step = 1,
		  getValue = DBGetDefault(rm, "backdropSpacing", 3), setValue = DBSet(rm, "backdropSpacing", UpdateRaidMarkers), disabled = rmDis },
		{ type = "dropdown", text = "Orientation",
		  values = ORIENTATION_VALUES, order = ORIENTATION_ORDER,
		  getValue = DBGetDefault(rm, "orientation", "HORIZONTAL"), setValue = DBSet(rm, "orientation", UpdateRaidMarkers), disabled = rmDis }
	); y = y - h
	_, h = Widgets:SectionHeader(parent, MH("Raid Markers", "Buttons"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Ready Check / Advanced Combat Logging",
		  getValue = DBGet(rm, "readyCheck"), setValue = DBSet(rm, "readyCheck", UpdateRaidMarkers),
		  disabled = rmDis },
		{ type = "spacer" }); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Count Down",
		  getValue = DBGet(rm, "countDown"), setValue = DBSet(rm, "countDown", UpdateRaidMarkers), disabled = rmDis },
		{ type = "slider", text = "Count Down Time", min = 1, max = 10, step = 1,
		  getValue = DBGetDefault(rm, "countDownTime", 5), setValue = DBSet(rm, "countDownTime", UpdateRaidMarkers),
		  tooltip = "Count down time in seconds.", disabled = rmDis }
	); y = y - h
	_, h = Widgets:SectionHeader(parent, MH("Raid Markers", "Button Layout"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Button Backdrop",
		  getValue = DBGet(rm, "buttonBackdrop"), setValue = DBSet(rm, "buttonBackdrop", UpdateRaidMarkers), disabled = rmDis },
		{ type = "toggle", text = "Button Animation",
		  getValue = DBGet(rm, "buttonAnimation"), setValue = DBSet(rm, "buttonAnimation", UpdateRaidMarkers), disabled = rmDis }
	); y = y - h
	if rm.buttonAnimation then
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Animation Duration", min = 0.01, max = 2, step = 0.01,
			  getValue = DBGetDefault(rm, "buttonAnimationDuration", 0.2), setValue = DBSet(rm, "buttonAnimationDuration", UpdateRaidMarkers), disabled = rmDis },
			{ type = "slider", text = "Animation Scale", min = 0.01, max = 5, step = 0.01,
			  getValue = DBGetDefault(rm, "buttonAnimationScale", 1.33), setValue = DBSet(rm, "buttonAnimationScale", UpdateRaidMarkers), disabled = rmDis }
		); y = y - h
	end
	return y
end

addon.RegisterOptionBuilder("combat", function(parent, y, cat)
	return BuildRaidMarkers(parent, y, cat)
end)
