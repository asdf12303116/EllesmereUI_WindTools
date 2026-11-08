local addon = select(2, ...)
local W = addon[1]
local E = addon[3]
local DBGet = addon.DBGet
local DBSet = addon.DBSet
local GetLSMStatusbars = addon.GetLSMStatusbars
local SafeModuleCall = addon.SafeModuleCall

local CHATBAR_STYLE = { BLOCK = "Block", TEXT = "Text" }
local CHATBAR_STYLE_ORDER = { "BLOCK", "TEXT" }

local function BuildChatBar(parent, y)
	local Widgets = EllesmereUI.Widgets
	local L = addon.L
	local _, h
	local db = E.db.WT.social
	local cb = db.chatBar
	local function chatBarOff() return not cb.enable end
	local function chatBarTextOff() return not cb.enable or cb.style ~= "TEXT" end

	local function afterCB()
		C_Timer.After(0, function()
			local rl = EllesmereUI._widgetRefreshList
			if rl then for i = 1, #rl do rl[i]() end end
		end)
		local mod = W:GetModule("ChatBar")
		if mod and mod.UpdateBar then mod:UpdateBar() end
	end

	-- One section: the chat bar is a single bar with a look, so there is nothing
	-- a second heading could separate. The texture dropdown only means something
	-- for block-style buttons, so it stays disabled until that style is picked.
	_, h = Widgets:SectionHeader(parent, L("CHAT"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Toggle the chat bar.",
		  getValue = DBGet(cb, "enable"),
		  setValue = DBSet(cb, "enable", function() SafeModuleCall(W.Modules.ChatBar, "ProfileUpdate") end) },
		{ type = "toggle", text = "Auto Hide", tooltip = "Hide channels that do not exist.",
		  getValue = DBGet(cb, "autoHide"), setValue = DBSet(cb, "autoHide", afterCB), disabled = chatBarOff }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Mouse Over", tooltip = "Only show chat bar when you mouse over it.",
		  getValue = DBGet(cb, "mouseOver"), setValue = DBSet(cb, "mouseOver", afterCB), disabled = chatBarOff },
		{ type = "dropdown", text = "Style",
		  values = CHATBAR_STYLE, order = CHATBAR_STYLE_ORDER,
		  getValue = DBGet(cb, "style"), setValue = DBSet(cb, "style", afterCB), disabled = chatBarOff }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Button Width", min = 2, max = 80, step = 1,
		  getValue = DBGet(cb, "buttonWidth"), setValue = DBSet(cb, "buttonWidth", afterCB), disabled = chatBarOff },
		{ type = "slider", text = "Button Height", min = 2, max = 60, step = 1,
		  getValue = DBGet(cb, "buttonHeight"), setValue = DBSet(cb, "buttonHeight", afterCB), disabled = chatBarOff }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Spacing", min = 0, max = 80, step = 1,
		  getValue = DBGet(cb, "spacing"), setValue = DBSet(cb, "spacing", afterCB), disabled = chatBarOff },
		{ type = "spacer" }
	); y = y - h

	local texLookup = GetLSMStatusbars()
	local texDisplay, texOrder = {}, {}
	for name in pairs(texLookup) do
		texDisplay[name] = name
		texOrder[#texOrder + 1] = name
	end
	table.sort(texOrder)
	texDisplay._menuOpts = {
		itemHeight = 28,
		background = function(key) return texLookup[key] end,
	}
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Texture",
		  values = texDisplay, order = texOrder,
		  getValue = DBGet(cb, "tex"), setValue = DBSet(cb, "tex", afterCB),
		  tooltip = "Texture used for block-style buttons.",
		  disabled = function() return chatBarOff() or cb.style ~= "BLOCK" end },
		{ type = "spacer" }
	); y = y - h

	-- Text style used to be three visible dropdowns under its own header. It is
	-- one row plus a cog now, which is how EllesmereUI hides font pickers.
	local fontValues, fontOrder = EllesmereUI.BuildFontDropdownData()
	local outlineValues = { ["none"] = "Drop Shadow", ["outline"] = "Outline", ["thick"] = "Thick Outline" }
	local outlineOrder = { "none", "outline", "thick" }
	local textRow
	textRow, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Use Color",
		  getValue = DBGet(cb, "color"), setValue = DBSet(cb, "color", afterCB), disabled = chatBarTextOff },
		{ type = "toggle", text = "Text Style",
		  getValue = function() return cb.style == "TEXT" end, setValue = function() end,
		  disabled = chatBarTextOff }
	); y = y - h
	if textRow and textRow._rightRegion then
		addon.AttachCog(textRow._rightRegion, "Text Style", {
			{ type = "dropdown", label = "Font", values = fontValues, order = fontOrder,
			  get = function() return cb.font.name end,
			  set = function(v) cb.font.name = v; afterCB() end },
			{ type = "dropdown", label = "Outline", values = outlineValues, order = outlineOrder,
			  get = function() return cb.font.style end,
			  set = function(v) cb.font.style = v; afterCB() end },
			{ type = "slider", label = "Size", min = 5, max = 60, step = 1,
			  get = function() return cb.font.size end,
			  set = function(v) cb.font.size = v; afterCB() end },
		})
	end

	_, h = Widgets:Button(parent, "Reset Chat Bar Position", y, function()
		local gdb = E.global.WT and E.global.WT.social and E.global.WT.social.chatBar
		if gdb then gdb.position = nil end
		local mod = W:GetModule("ChatBar")
		if mod and mod.ApplyDefaultPosition then mod:ApplyDefaultPosition() end
	end); y = y - h

	return y
end

local function BuildSmartTab(parent, y)
	local Widgets = EllesmereUI.Widgets
	local L = addon.L
	local _, h
	local st = E.db.WT.social.smartTab
	local stDis = function() return not st.enable end

	_, h = Widgets:SectionHeader(parent, L("SMART TAB"), y); y = y - h
	-- The sidebar used to carry this switch; the page owns it now that the
	-- standalone panel is gone. The chat edit hook is installed once at login,
	-- so turning the module back on only takes effect after a reload.
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Toggle the SmartTab module.",
		  getValue = DBGet(st, "enable"),
		  setValue = DBSet(st, "enable", function()
			SafeModuleCall(W.Modules.SmartTab, "ProfileUpdate")
			addon.PromptReload("Smart Tab registers its chat edit box hook at login, so the change applies after a UI reload.")
		  end) },
		{ type = "toggle", text = "Enable Tab Switching",
		  tooltip = "Cycle chat channels with Tab. WARNING: hooks Blizzard's chat edit box; in modern clients this can taint it and block sending chat. Disable if you get chat send failures.",
		  getValue = function()
			local sp = E.private and E.private.WT and E.private.WT.social and E.private.WT.social.smartTab
			return (sp and sp.allowUnsafeChatEditHooks) ~= false
		  end,
		  setValue = function(v)
			local sp = E.private.WT.social.smartTab
			sp.allowUnsafeChatEditHooks = v and true or false
			addon.PromptReload("Smart Tab registers its chat edit box hook at login, so the change applies after a UI reload.")
		  end, disabled = stDis }
	); y = y - h

	local channelItems = {
		{ key = "yell",         label = "Yell" },
		{ key = "battleground", label = "Battleground" },
		{ key = "raidWarning",  label = "Raid Warning" },
		{ key = "officer",      label = "Officer" },
	}
	local channelRow
	channelRow, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Channel", tooltip = "Select which channels Smart Tab should cycle through.",
		  values = { ["_placeholder"] = "..." }, order = { "_placeholder" },
		  getValue = function() return "_placeholder" end,
		  setValue = function() end, disabled = stDis },
		{ type = "spacer" }
	); y = y - h
	do
		local rgn = channelRow._leftRegion
		if rgn._control then rgn._control:Hide() end
		local PP = EllesmereUI.PP or EllesmereUI.PanelPP
		local cbDD, cbDDRefresh = EllesmereUI.BuildVisOptsCBDropdown(
			rgn, 210, rgn:GetFrameLevel() + 2,
			channelItems,
			function(k) return st[k] end,
			function(k, v) st[k] = v end
		)
		PP.Point(cbDD, "RIGHT", rgn, "RIGHT", -20, 0)
		rgn._control = cbDD
		rgn._lastInline = nil
		EllesmereUI.RegisterWidgetRefresh(cbDDRefresh)
	end

	_, h = Widgets:SectionHeader(parent, L("WHISPER"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Whisper Cycle",
		  getValue = DBGet(st, "whisperCycle"), setValue = DBSet(st, "whisperCycle"), disabled = stDis },
		{ type = "slider", text = "Expiration time (min)", min = 1, max = 2400, step = 1,
		  getValue = DBGet(st, "historyLimit"), setValue = DBSet(st, "historyLimit"), disabled = stDis }
	); y = y - h

	return y
end

addon.RegisterOptionBuilder("social", function(parent, y, _, subPage)
	if subPage == "Chat Bar" then return BuildChatBar(parent, y) end
	if subPage == "Smart Tab" then return BuildSmartTab(parent, y) end
	return y
end)
