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

-- The page drops the "Raid Markers" prefix every heading used to carry, so two
-- sections do the work five did. Controls are the same set, in the order they
-- are reached while setting the bar up: what it does first, how it looks second.
local function BuildRaidMarkers(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local rm = E.db.WT.combat.raidMarkers
	local rmDis = function() return not rm.enable end

	_, h = Widgets:SectionHeader(parent, "RAID MARKERS", y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Enable the raid markers bar.",
		  getValue = DBGet(rm, "enable"), setValue = DBSet(rm, "enable", ToggleRaidMarkers) },
		{ type = "spacer" }); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Inverse Mode",
		  getValue = DBGet(rm, "inverse"), setValue = DBSet(rm, "inverse", UpdateRaidMarkers),
		  tooltip = "Swap the functionality of normal click and click with modifier keys.",
		  disabled = rmDis },
		{ type = "spacer" }); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Modifier Key",
		  values = MODIFIER_VALUES, order = MODIFIER_ORDER,
		  getValue = DBGet(rm, "modifier"), setValue = DBSet(rm, "modifier", UpdateRaidMarkers),
		  tooltip = "Set the modifier key for placing world markers.", disabled = rmDis },
		{ type = "spacer" }); y = y - h
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
		{ type = "toggle", text = "Count Down",
		  getValue = DBGet(rm, "countDown"), setValue = DBSet(rm, "countDown", UpdateRaidMarkers), disabled = rmDis },
		{ type = "slider", text = "Count Down Time", min = 1, max = 10, step = 1,
		  getValue = DBGetDefault(rm, "countDownTime", 5), setValue = DBSet(rm, "countDownTime", UpdateRaidMarkers),
		  tooltip = "Count down time in seconds.", disabled = rmDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Ready Check / Advanced Combat Logging",
		  getValue = DBGet(rm, "readyCheck"), setValue = DBSet(rm, "readyCheck", UpdateRaidMarkers),
		  disabled = rmDis },
		{ type = "spacer" }); y = y - h

	_, h = Widgets:SectionHeader(parent, "APPEARANCE", y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Button Size", min = 15, max = 80, step = 1,
		  getValue = DBGetDefault(rm, "buttonSize", 30), setValue = DBSet(rm, "buttonSize", UpdateRaidMarkers),
		  tooltip = "Size of the marker buttons.", disabled = rmDis },
		{ type = "slider", text = "Button Spacing", min = 1, max = 30, step = 1,
		  getValue = DBGetDefault(rm, "spacing", 4), setValue = DBSet(rm, "spacing", UpdateRaidMarkers),
		  tooltip = "Spacing between the marker buttons.", disabled = rmDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Bar Backdrop",
		  getValue = DBGet(rm, "backdrop"), setValue = DBSet(rm, "backdrop", UpdateRaidMarkers),
		  tooltip = "Show a backdrop of the bar.", disabled = rmDis },
		{ type = "toggle", text = "Button Backdrop",
		  getValue = DBGet(rm, "buttonBackdrop"), setValue = DBSet(rm, "buttonBackdrop", UpdateRaidMarkers),
		  disabled = rmDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Backdrop Spacing", min = 1, max = 30, step = 1,
		  getValue = DBGetDefault(rm, "backdropSpacing", 3), setValue = DBSet(rm, "backdropSpacing", UpdateRaidMarkers),
		  disabled = rmDis },
		{ type = "dropdown", text = "Orientation",
		  values = ORIENTATION_VALUES, order = ORIENTATION_ORDER,
		  getValue = DBGetDefault(rm, "orientation", "HORIZONTAL"), setValue = DBSet(rm, "orientation", UpdateRaidMarkers),
		  disabled = rmDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Button Animation",
		  getValue = DBGet(rm, "buttonAnimation"), setValue = DBSet(rm, "buttonAnimation", UpdateRaidMarkers),
		  disabled = rmDis },
		{ type = "slider", text = "Animation Duration", min = 0.01, max = 2, step = 0.01,
		  getValue = DBGetDefault(rm, "buttonAnimationDuration", 0.2),
		  setValue = DBSet(rm, "buttonAnimationDuration", UpdateRaidMarkers),
		  disabled = function() return rmDis() or not rm.buttonAnimation end }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Animation Scale", min = 0.01, max = 5, step = 0.01,
		  getValue = DBGetDefault(rm, "buttonAnimationScale", 1.33),
		  setValue = DBSet(rm, "buttonAnimationScale", UpdateRaidMarkers),
		  disabled = function() return rmDis() or not rm.buttonAnimation end },
		{ type = "spacer" }
	); y = y - h

	return y
end

addon.RegisterOptionBuilder("combat", function(parent, y)
	return BuildRaidMarkers(parent, y)
end)
