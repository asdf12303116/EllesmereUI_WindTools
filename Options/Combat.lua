local addon = select(2, ...)
local W = addon[1]
local E = addon[3]
local L = addon.L
local DBGet = addon.DBGet
local DBSet = addon.DBSet
local SafeModuleCall = addon.SafeModuleCall
local PromptReload = addon.PromptReload
local GetLSMFonts = addon.GetLSMFonts
local FONT_OUTLINE_VALUES = addon.FONT_OUTLINE_VALUES
local FONT_OUTLINE_ORDER = addon.FONT_OUTLINE_ORDER

local format = format
local pairs = pairs
local table_sort = table.sort

local ORIENTATION_VALUES = { HORIZONTAL = "Horizontal", VERTICAL = "Vertical" }
local ORIENTATION_ORDER = { "HORIZONTAL", "VERTICAL" }

local VISIBILITY_VALUES = { DEFAULT = "Default", INPARTY = "In Party", ALWAYS = "Always Display" }
local VISIBILITY_ORDER = { "DEFAULT", "INPARTY", "ALWAYS" }

local MODIFIER_VALUES = { shift = "Shift Key", ctrl = "Ctrl Key", alt = "Alt Key" }
local MODIFIER_ORDER = { "shift", "ctrl", "alt" }

local SOUND_CHANNEL_VALUES = { Master = "Master", Music = "Music", SFX = "SFX", Ambience = "Ambience", Dialog = "Dialog" }
local SOUND_CHANNEL_ORDER = { "Master", "Music", "SFX", "Ambience", "Dialog" }

-- Blizzard exposes MAX_TOTEMS as a runtime constant, but the page is built long
-- before it needs a value the player can see, and totem slots have been four
-- since the system existed. Keeping it local also keeps the options file free
-- of a global that only the shaman code paths could rely on.
local TOTEM_SLOTS = 4

local function DBGetDefault(t, k, default)
	return function()
		local v = t and t[k]
		if v == nil then return default end
		return v
	end
end

-- The alert module only plays sounds that LibSharedMedia knows by name, so the
-- dropdown has to offer those names and nothing else. A build with no LSM
-- registered (another addon owning it went missing) keeps the stored value
-- selectable instead of leaving an empty menu behind.
local function GetLSMSounds()
	local LSM = E.Libs and E.Libs.LSM
	local sounds = LSM and LSM:HashTable("sound")
	if not sounds then return { None = "None" }, { "None" } end

	local order = {}
	for name in pairs(sounds) do
		order[#order + 1] = name
	end
	if #order == 0 then return { None = "None" }, { "None" } end
	table_sort(order)
	return sounds, order
end

local function UpdateRaidMarkers()
	SafeModuleCall(W.Modules.RaidMarkers, "ProfileUpdate")
end

local function ToggleRaidMarkers()
	UpdateRaidMarkers()
	if addon.RefreshOptions then
		addon.RefreshOptions()
	end
end

local function UpdateCombatAlert()
	SafeModuleCall(W.Modules.CombatAlert, "ProfileUpdate")
end

local function PreviewCombatAlert()
	SafeModuleCall(W.Modules.CombatAlert, "Preview")
end

local function ToggleDestroyTotem()
	PromptReload()
	if addon.RefreshOptions then
		addon.RefreshOptions()
	end
end

local function UpdateQuickKeystone()
	SafeModuleCall(W.Modules.QuickKeystone, "ProfileUpdate")
end

local function UpdateDamageMeterLayout()
	SafeModuleCall(W.Modules.DamageMeterLayout, "ProfileUpdate")
end

local function ApplyDamageMeterRules()
	SafeModuleCall(W.Modules.DamageMeterLayout, "AutoSwitch", true)
end

local function IsDamageMeterPreviewing()
	local DL = W.Modules.DamageMeterLayout
	return DL and DL.IsPreviewing and DL:IsPreviewing() or false
end

-- The label flips between start and stop, and a plain setting write does not
-- rebuild the page, so the click refreshes the builder to repaint the caption.
local function ToggleDamageMeterPreview()
	local DL = W.Modules.DamageMeterLayout
	if not DL then return end
	if IsDamageMeterPreviewing() then
		SafeModuleCall(DL, "StopPreview")
	else
		SafeModuleCall(DL, "Preview", DL.previewLayoutIndex or E.db.WT.combat.damageMeterLayout.activeLayout)
	end
	if addon.RefreshOptions then
		addon.RefreshOptions()
	end
end

local function DamageMeterPreviewText()
	if IsDamageMeterPreviewing() then return L["Stop Preview Mode"] end
	return L["Start Preview Mode"]
end

local function GetDamageMeterLayoutValues(includeNone)
	local values, order = {}, {}
	if includeNone then
		values[0] = "None"
		order[#order + 1] = 0
	end
	local layouts = E.db.WT.combat.damageMeterLayout.layouts
	for i = 1, #layouts do
		values[i] = layouts[i].name or format(L["Layout %d"], i)
		order[#order + 1] = i
	end
	return values, order
end

-- One font stack row: family, outline and size, the same triple the item pages
-- use so the two places do not drift apart.
local function FontRow(Widgets, parent, y, dbTable, text, after)
	local fonts = GetLSMFonts()
	local fontOrder = {}
	for name in pairs(fonts) do
		fontOrder[#fontOrder + 1] = name
	end
	table_sort(fontOrder)

	local _, h = Widgets:TripleRow(parent, y,
		{ type = "dropdown", text = text, values = fonts, order = fontOrder,
		  getValue = DBGet(dbTable, "name"), setValue = DBSet(dbTable, "name", after) },
		{ type = "dropdown", text = "Outline", values = FONT_OUTLINE_VALUES, order = FONT_OUTLINE_ORDER,
		  getValue = DBGet(dbTable, "style"), setValue = DBSet(dbTable, "style", after) },
		{ type = "slider", text = "Size", min = 5, max = 60, step = 1,
		  getValue = DBGet(dbTable, "size"), setValue = DBSet(dbTable, "size", after) })
	return y - h
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

-- Combat Alert: shape, then lettering, then the sounds that go with it. The
-- four gradient stops live on the cog of the text row they belong to, because
-- a row only holds two swatches and each side needs two colours.
local function BuildCombatAlert(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local ca = E.db.WT.combat.combatAlert
	local caDis = function() return not ca.enable end
	local animDis = function() return caDis() or not ca.animation end
	local textDis = function() return caDis() or not ca.text end

	local function GetStop(stop, key)
		return function()
			local c = stop and stop[key]
			return c and c.r or 1, c and c.g or 1, c and c.b or 1, 1
		end
	end
	local function SetStop(stop, key)
		return function(r, g, b)
			if not stop or not stop[key] then return end
			stop[key].r, stop[key].g, stop[key].b = r, g, b
			UpdateCombatAlert()
		end
	end

	_, h = Widgets:SectionHeader(parent, L["COMBAT ALERT"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  tooltip = "Show a alert when you enter or leave combat.",
		  getValue = DBGet(ca, "enable"), setValue = DBSet(ca, "enable", UpdateCombatAlert) },
		{ type = "slider", text = "Speed", min = 0.1, max = 4, step = 0.01,
		  tooltip = "The speed of the alert.",
		  getValue = DBGetDefault(ca, "speed", 1), setValue = DBSet(ca, "speed", UpdateCombatAlert), disabled = caDis }
	); y = y - h
	_, h = Widgets:Button(parent, "Preview", y, function()
		if ca.enable then PreviewCombatAlert() end
	end); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Animation",
		  tooltip = "Display an animation when you enter or leave combat.",
		  getValue = DBGet(ca, "animation"), setValue = DBSet(ca, "animation", UpdateCombatAlert), disabled = caDis },
		{ type = "slider", text = "Animation Size", min = 0.1, max = 3, step = 0.01,
		  getValue = DBGetDefault(ca, "animationSize", 1), setValue = DBSet(ca, "animationSize", UpdateCombatAlert),
		  disabled = animDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Text",
		  tooltip = "Display a text when you enter or leave combat.",
		  getValue = DBGet(ca, "text"), setValue = DBSet(ca, "text", UpdateCombatAlert), disabled = caDis },
		{ type = "spacer" }); y = y - h

	local textRow, textH = Widgets:DualRow(parent, y,
		{ type = "input", text = "Enter Text", inputWidth = 140,
		  getValue = DBGet(ca, "enterText"), setValue = DBSet(ca, "enterText", UpdateCombatAlert), disabled = textDis },
		{ type = "input", text = "Leave Text", inputWidth = 140,
		  getValue = DBGet(ca, "leaveText"), setValue = DBSet(ca, "leaveText", UpdateCombatAlert), disabled = textDis }
	); y = y - textH

	local enterRow, leaveRow = textRow._leftRegion, textRow._rightRegion
	addon.AttachCog(enterRow, "Gradient", {
		{ type = "colorpicker", label = "Gradient Color 1", hasAlpha = false,
		  get = GetStop(ca.enterColor, "left"), set = SetStop(ca.enterColor, "left"), disabled = textDis },
		{ type = "colorpicker", label = "Gradient Color 2", hasAlpha = false,
		  get = GetStop(ca.enterColor, "right"), set = SetStop(ca.enterColor, "right"), disabled = textDis },
	})
	addon.AttachCog(leaveRow, "Gradient", {
		{ type = "colorpicker", label = "Gradient Color 1", hasAlpha = false,
		  get = GetStop(ca.leaveColor, "left"), set = SetStop(ca.leaveColor, "left"), disabled = textDis },
		{ type = "colorpicker", label = "Gradient Color 2", hasAlpha = false,
		  get = GetStop(ca.leaveColor, "right"), set = SetStop(ca.leaveColor, "right"), disabled = textDis },
	})

	y = FontRow(Widgets, parent, y, ca.font, "Font Setting", UpdateCombatAlert)

	local soundValues, soundOrder = GetLSMSounds()
	_, h = Widgets:SectionHeader(parent, L["SOUND"], y); y = y - h
	_, h = Widgets:TripleRow(parent, y,
		{ type = "toggle", text = "Enter Combat",
		  getValue = DBGet(ca.enterSound, "enable"), setValue = DBSet(ca.enterSound, "enable") },
		{ type = "dropdown", text = "Sound", values = soundValues, order = soundOrder,
		  getValue = DBGet(ca.enterSound, "sound"), setValue = DBSet(ca.enterSound, "sound"),
		  disabled = function() return not ca.enterSound.enable end },
		{ type = "dropdown", text = "Sound Channel", values = SOUND_CHANNEL_VALUES, order = SOUND_CHANNEL_ORDER,
		  getValue = DBGet(ca.enterSound, "channel"), setValue = DBSet(ca.enterSound, "channel"),
		  disabled = function() return not ca.enterSound.enable end },
		{ 0.30, 0.30 }); y = y - h
	_, h = Widgets:TripleRow(parent, y,
		{ type = "toggle", text = "Leave Combat",
		  getValue = DBGet(ca.leaveSound, "enable"), setValue = DBSet(ca.leaveSound, "enable") },
		{ type = "dropdown", text = "Sound", values = soundValues, order = soundOrder,
		  getValue = DBGet(ca.leaveSound, "sound"), setValue = DBSet(ca.leaveSound, "sound"),
		  disabled = function() return not ca.leaveSound.enable end },
		{ type = "dropdown", text = "Sound Channel", values = SOUND_CHANNEL_VALUES, order = SOUND_CHANNEL_ORDER,
		  getValue = DBGet(ca.leaveSound, "channel"), setValue = DBSet(ca.leaveSound, "channel"),
		  disabled = function() return not ca.leaveSound.enable end },
		{ 0.30, 0.30 }); y = y - h

	return y
end

-- Destroy Totem is private settings, so every write that the running module
-- cannot pick up on its own asks for the reload instead of silently doing
-- nothing. Key combinations are the exception: they are real overrides and can
-- be rebound while the game keeps running.
local function BuildDestroyTotem(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local dt = E.private.WT.combat.destroyTotem
	local dtDis = function() return not dt.enable end
	local module = W.Modules.DestroyTotem

	-- SafeModuleCall hands back the xpcall result rather than the module's
	-- return values, so reading a macro string goes straight to the module.
	local function GetMacroText(slot)
		if not module or type(module.GetMacroText) ~= "function" then return "" end
		return module:GetMacroText(slot) or ""
	end

	local function SetKey(slot)
		return function(v)
			dt.keys = dt.keys or {}
			dt.keys[slot] = v
			-- Binding a key only takes effect against the module's action buttons,
			-- which are created at login. Without them the change waits for the
			-- reload that enabling the switch already asked for.
			if dt.enable and module and module.Buttons and module.Buttons[1] then
				SafeModuleCall(module, "SetupKeyBindings")
			else
				PromptReload()
			end
		end
	end

	_, h = Widgets:SectionHeader(parent, L["DESTROY TOTEM"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  tooltip = "Use key bindings or macro to destroy your totems quickly.",
		  getValue = DBGet(dt, "enable"), setValue = DBSet(dt, "enable", ToggleDestroyTotem) },
		{ type = "spacer" }); y = y - h

	_, h = Widgets:SectionHeader(parent, L["KEY BINDINGS"], y); y = y - h
	for slot = 1, TOTEM_SLOTS, 2 do
		local partner = slot + 1 <= TOTEM_SLOTS and slot + 1 or nil
		local row, rowH = Widgets:DualRow(parent, y,
			{ type = "label", text = format(L["Destroy Totem %s"], slot) },
			partner and { type = "label", text = format(L["Destroy Totem %s"], partner) } or { type = "spacer" })
		y = y - rowH

		-- The keybind button anchors itself next to the bare label; a build in
		-- progress must not create it, or the capture pass would see a control
		-- that no longer belongs to the page it is scanning.
		if not EllesmereUI._prebuilding then
			local PP = EllesmereUI.PanelPP
			local function AddKeybind(region, bindSlot)
				if not region then return end
				local button, refresh = EllesmereUI.BuildKeybindButton(region, {
					w = 126, h = 29, level = 4, mouse = true,
					get = function() return dt.keys and dt.keys[bindSlot] end,
					set = SetKey(bindSlot),
					disabled = dtDis,
					disabledTip = "Enable",
				})
				PP.Point(button, "RIGHT", region, "RIGHT", -20, 0)
				EllesmereUI.RegisterWidgetRefresh(refresh)
				EllesmereUI.AddCaptureAccessor(region, {
					type = "keybind",
					text = region._label and region._label:GetText() or format(L["Destroy Totem %s"], bindSlot),
					getValue = function() return dt.keys and dt.keys[bindSlot] end,
					setValue = function(v)
						SetKey(bindSlot)(v)
						if refresh then refresh() end
					end,
				})
			end
			AddKeybind(row._leftRegion, slot)
			if partner then AddKeybind(row._rightRegion, partner) end
		end
	end

	if dt.enable then
		_, h = Widgets:SectionHeader(parent, L["MACRO TEXT"], y); y = y - h
		for slot = 1, TOTEM_SLOTS, 2 do
			local partner = slot + 1 <= TOTEM_SLOTS and slot + 1 or nil
			_, h = Widgets:DualRow(parent, y,
				{ type = "input", text = format(L["Destroy Totem %s"], slot), inputWidth = 240,
				  getValue = function() return GetMacroText(slot) end,
				  setValue = function() end, disabled = dtDis },
				partner and { type = "input", text = format(L["Destroy Totem %s"], partner), inputWidth = 240,
				  getValue = function() return GetMacroText(partner) end,
				  setValue = function() end, disabled = dtDis } or { type = "spacer" }
			); y = y - h
		end
	end

	return y
end

local function BuildQuickKeystone(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local qk = E.db.WT.combat.quickKeystone

	_, h = Widgets:SectionHeader(parent, L["QUICK KEYSTONE"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  tooltip = "Put the keystone from bag automatically.",
		  getValue = DBGet(qk, "enable"), setValue = DBSet(qk, "enable", UpdateQuickKeystone) },
		{ type = "spacer" }); y = y - h

	return y
end

-- Damage Meter: the container first, the automatic switching rules last. The
-- recommended skin button the upstream page carried is gone with the rest of
-- the skinning layer.
local function BuildDamageMeter(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local db = E.db.WT.combat.damageMeterLayout
	local dmDis = function() return not db.enable end
	local rulesDis = function() return dmDis() or not db.autoSwitch.enable end

	local values, order = GetDamageMeterLayoutValues(false)
	local noneValues, noneOrder = GetDamageMeterLayoutValues(true)

	local function GetRule(key)
		return function()
			return db.autoSwitch.rules[key] or 0
		end
	end
	local function SetRule(key)
		return function(v)
			db.autoSwitch.rules[key] = (v == 0) and nil or v
			ApplyDamageMeterRules()
		end
	end

	_, h = Widgets:SectionHeader(parent, L["DAMAGE METER"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  tooltip = "Manage Blizzard Damage Meter windows with reusable layouts.",
		  getValue = DBGet(db, "enable"), setValue = DBSet(db, "enable", UpdateDamageMeterLayout) },
		{ type = "dropdown", text = "Active Layout", values = values, order = order,
		  getValue = DBGet(db, "activeLayout"),
		  setValue = function(v)
				db.activeLayout = v
				local DL = W.Modules.DamageMeterLayout
				if DL and DL.IsPreviewing and DL:IsPreviewing() then
					SafeModuleCall(DL, "Preview", v)
				else
					SafeModuleCall(DL, "UpdateLayout", v)
				end
			end,
		  disabled = dmDis }
	); y = y - h
	_, h = Widgets:Button(parent, DamageMeterPreviewText(), y, function()
		if db.enable then ToggleDamageMeterPreview() end
	end); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Width", min = 200, max = 1600, step = 1,
		  getValue = DBGetDefault(db, "width", 400), setValue = DBSet(db, "width", UpdateDamageMeterLayout), disabled = dmDis },
		{ type = "slider", text = "Height", min = 120, max = 1000, step = 1,
		  getValue = DBGetDefault(db, "height", 300), setValue = DBSet(db, "height", UpdateDamageMeterLayout), disabled = dmDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Backdrop",
		  getValue = DBGet(db, "backdrop"), setValue = DBSet(db, "backdrop", UpdateDamageMeterLayout), disabled = dmDis },
		{ type = "toggle", text = "Shadow",
		  getValue = DBGet(db, "shadow"), setValue = DBSet(db, "shadow", UpdateDamageMeterLayout), disabled = dmDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Animation",
		  tooltip = "Fade in/out the damage meters when switching layouts.",
		  getValue = DBGet(db.animation, "enable"), setValue = DBSet(db.animation, "enable", UpdateDamageMeterLayout),
		  disabled = dmDis },
		{ type = "slider", text = "Animation Duration", min = 0, max = 2, step = 0.01,
		  tooltip = "Values below 0.05 are treated as disabled.",
		  getValue = DBGetDefault(db.animation, "duration", 0.37),
		  setValue = DBSet(db.animation, "duration", UpdateDamageMeterLayout),
		  disabled = function() return dmDis() or not db.animation.enable end }
	); y = y - h

	_, h = Widgets:SectionHeader(parent, L["AUTO SWITCH"], y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  tooltip = "Automatically switch damage meter layouts based on different combat scenarios.",
		  getValue = DBGet(db.autoSwitch, "enable"),
		  setValue = DBSet(db.autoSwitch, "enable", ApplyDamageMeterRules),
		  disabled = dmDis },
		{ type = "spacer" }); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Raid", values = noneValues, order = noneOrder,
		  getValue = GetRule("raid"), setValue = SetRule("raid"), disabled = rulesDis },
		{ type = "dropdown", text = "Mythic Plus", values = noneValues, order = noneOrder,
		  getValue = GetRule("mythicPlus"), setValue = SetRule("mythicPlus"), disabled = rulesDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Delves", values = noneValues, order = noneOrder,
		  getValue = GetRule("delve"), setValue = SetRule("delve"), disabled = rulesDis },
		{ type = "dropdown", text = "In Combat", values = noneValues, order = noneOrder,
		  getValue = GetRule("combat"), setValue = SetRule("combat"), disabled = rulesDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Out of Combat", values = noneValues, order = noneOrder,
		  getValue = GetRule("outOfCombat"), setValue = SetRule("outOfCombat"), disabled = rulesDis },
		{ type = "spacer" }); y = y - h

	return y
end

addon.RegisterOptionBuilder("combat", function(parent, y)
	y = BuildRaidMarkers(parent, y)
	y = BuildCombatAlert(parent, y)
	y = BuildDestroyTotem(parent, y)
	-- Keystone swapping is a retail-only feature; the eternal realm has no
	-- keystone system to put anything into, so the section is not built there.
	if not E.Forever then
		y = BuildQuickKeystone(parent, y)
	end
	y = BuildDamageMeter(parent, y)
	return y
end)
