local addon = select(2, ...)
local W = addon[1]
local E = addon[3]
local DBGet = addon.DBGet
local DBSet = addon.DBSet
local GetLSMFonts = addon.GetLSMFonts
local GetLSMStatusbars = addon.GetLSMStatusbars
local SafeModuleCall = addon.SafeModuleCall
local FONT_OUTLINE_VALUES = addon.FONT_OUTLINE_VALUES
local FONT_OUTLINE_ORDER = addon.FONT_OUTLINE_ORDER

local table_sort = table.sort

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

-- One font stack row, the same triple the item and combat pages use.
local function FontRow(Widgets, parent, y, dbTable, text, after, disabled)
	local fonts = GetLSMFonts()
	local fontOrder = {}
	for name in pairs(fonts) do
		fontOrder[#fontOrder + 1] = name
	end
	table_sort(fontOrder)

	local _, h = Widgets:TripleRow(parent, y,
		{ type = "dropdown", text = text, values = fonts, order = fontOrder,
		  getValue = DBGet(dbTable, "name"), setValue = DBSet(dbTable, "name", after), disabled = disabled },
		{ type = "dropdown", text = "Outline", values = FONT_OUTLINE_VALUES, order = FONT_OUTLINE_ORDER,
		  getValue = DBGet(dbTable, "style"), setValue = DBSet(dbTable, "style", after), disabled = disabled },
		{ type = "slider", text = "Size", min = 5, max = 60, step = 1,
		  getValue = DBGet(dbTable, "size"), setValue = DBSet(dbTable, "size", after), disabled = disabled })
	return y - h
end

local function BuildChatLink(parent, y)
	local Widgets = EllesmereUI.Widgets
	local L = addon.L
	local _, h
	local cl = E.db.WT.social.chatLink
	local function after() SafeModuleCall(W.Modules.ChatLink, "ProfileUpdate") end
	local function off() return not cl.enable end

	_, h = Widgets:SectionHeader(parent, L("CHAT LINK"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  tooltip = "Add extra information on the link, so that you can get basic information but do not need to click.",
		  getValue = DBGet(cl, "enable"), setValue = DBSet(cl, "enable", after) },
		{ type = "spacer" }
	); y = y - h

	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Level", tooltip = "Display the level of the item on the item link.",
		  getValue = DBGet(cl, "level"), setValue = DBSet(cl, "level", after), disabled = off },
		{ type = "toggle", text = "Numerical Quality Tier",
		  tooltip = "Use numerical quality tier rather the icon on the item link.",
		  getValue = DBGet(cl, "numericalQualityTier"), setValue = DBSet(cl, "numericalQualityTier", after), disabled = off }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Translate Item",
		  tooltip = "Translate the name in item links into your language.",
		  getValue = DBGet(cl, "translateItem"), setValue = DBSet(cl, "translateItem", after), disabled = off },
		{ type = "toggle", text = "Icon",
		  getValue = DBGet(cl, "icon"), setValue = DBSet(cl, "icon", after), disabled = off }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Armor Category",
		  getValue = DBGet(cl, "armorCategory"), setValue = DBSet(cl, "armorCategory", after), disabled = off },
		{ type = "toggle", text = "Weapon Category",
		  getValue = DBGet(cl, "weaponCategory"), setValue = DBSet(cl, "weaponCategory", after), disabled = off }
	); y = y - h

	_, h = Widgets:SectionHeader(parent, L("ICONS"), y); y = y - h
	local function iconOff() return off() or not cl.icon end
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Icon Height", min = 10, max = 100, step = 1,
		  getValue = DBGet(cl, "iconHeight"), setValue = DBSet(cl, "iconHeight", after), disabled = iconOff },
		{ type = "slider", text = "Icon Width", min = 10, max = 100, step = 1,
		  getValue = DBGet(cl, "iconWidth"), setValue = DBSet(cl, "iconWidth", after), disabled = iconOff }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Keep Size Ratio",
		  getValue = DBGet(cl, "keepRatio"), setValue = DBSet(cl, "keepRatio", after), disabled = iconOff },
		{ type = "spacer" }
	); y = y - h

	return y
end

local function BuildEmote(parent, y)
	local Widgets = EllesmereUI.Widgets
	local L = addon.L
	local _, h
	local em = E.db.WT.social.emote
	local function after() SafeModuleCall(W.Modules.Emote, "ProfileUpdate") end
	local function off() return not em.enable end

	_, h = Widgets:SectionHeader(parent, L("EMOTE"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Parse emote expression from other players.",
		  getValue = DBGet(em, "enable"), setValue = DBSet(em, "enable", after) },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "slider", text = "Emote Icon Size", min = 5, max = 35, step = 1,
		  getValue = DBGet(em, "size"), setValue = DBSet(em, "size", after), disabled = off },
		{ type = "toggle", text = "Chat Bubbles",
		  getValue = DBGet(em, "chatBubbles"), setValue = DBSet(em, "chatBubbles", after), disabled = off }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Use Emote Panel",
		  tooltip = "Press { to active the emote select window.",
		  getValue = DBGet(em, "panel"), setValue = DBSet(em, "panel", after), disabled = off },
		{ type = "spacer" }
	); y = y - h

	return y
end

local function BuildFriendList(parent, y)
	local Widgets = EllesmereUI.Widgets
	local L = addon.L
	local _, h
	local fl = E.db.WT.social.friendList
	local function after() FriendsFrame_Update() end
	local function off() return not fl.enable end

	_, h = Widgets:SectionHeader(parent, L("FRIEND LIST"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  tooltip = "Add additional information to the friend frame.",
		  getValue = DBGet(fl, "enable"),
		  setValue = DBSet(fl, "enable", function() SafeModuleCall(W.Modules.FriendList, "ProfileUpdate") end) },
		{ type = "spacer" }
	); y = y - h

	_, h = Widgets:SectionHeader(parent, L("TEXTURE REPLACEMENT"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Status Icon Pack",
		  values = { default = "Default", d3 = "Diablo 3", square = "Square" },
		  order = { "default", "d3", "square" },
		  getValue = function() return fl.textures.status end,
		  setValue = function(v) fl.textures.status = v; after() end, disabled = off },
		{ type = "dropdown", text = "Game Icon Style for WoW",
		  values = { BLIZZARD = "Default Blizzard Style", FACTION = "Use faction icon", PATCH = "Use patch icon" },
		  order = { "BLIZZARD", "FACTION", "PATCH" },
		  getValue = function() return fl.textures.gameIcon end,
		  setValue = function(v) fl.textures.gameIcon = v; after() end, disabled = off }
	); y = y - h

	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Level",
		  getValue = DBGet(fl, "level"), setValue = DBSet(fl, "level", after), disabled = off },
		{ type = "toggle", text = "Hide Max Level",
		  getValue = DBGet(fl, "hideMaxLevel"), setValue = DBSet(fl, "hideMaxLevel", after),
		  disabled = function() return off() or not fl.level end }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Use Note As Name",
		  tooltip = "Replace the Real ID or the character name of friends with your notes.",
		  getValue = DBGet(fl, "useNoteAsName"), setValue = DBSet(fl, "useNoteAsName", after), disabled = off },
		{ type = "toggle", text = "Use Client Color",
		  tooltip = "Change the color of the name to the in-playing game style.",
		  getValue = DBGet(fl, "useClientColor"), setValue = DBSet(fl, "useClientColor", after), disabled = off }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Use Class Color",
		  getValue = DBGet(fl, "useClassColor"), setValue = DBSet(fl, "useClassColor", after), disabled = off },
		{ type = "spacer" }
	); y = y - h
	y = FontRow(Widgets, parent, y, fl.nameFont, "Name Font", after, off)

	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Hide Realm", tooltip = "Hide the realm name of friends.",
		  getValue = DBGet(fl, "hideRealm"), setValue = DBSet(fl, "hideRealm", after), disabled = off },
		{ type = "spacer" }
	); y = y - h
	y = FontRow(Widgets, parent, y, fl.infoFont, "Information Font", after, off)
	_, h = Widgets:DualRow(parent, y,
		{ type = "colorpicker", text = "Color", hasAlpha = false,
		  getValue = function()
			local c = fl.areaColor or {}
			return c.r or 1, c.g or 1, c.b or 1, 1
		  end,
		  setValue = function(r, g, b) fl.areaColor = { r = r, g = g, b = b }; after() end,
		  disabled = off },
		{ type = "spacer" }
	); y = y - h

	return y
end

local function BuildContextMenu(parent, y)
	local Widgets = EllesmereUI.Widgets
	local L = addon.L
	local _, h
	local cm = E.db.WT.social.contextMenu
	local function after() SafeModuleCall(W.Modules.ContextMenu, "ProfileUpdate") end
	local function off() return not cm.enable end
	local listSelected

	_, h = Widgets:SectionHeader(parent, L("CONTEXT MENU"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  tooltip = "Add features to context menu based on menu types.",
		  getValue = DBGet(cm, "enable"), setValue = DBSet(cm, "enable", after) },
		{ type = "toggle", text = "Section Title",
		  tooltip = "Add a styled section title to the context menu.",
		  getValue = DBGet(cm, "sectionTitle"), setValue = DBSet(cm, "sectionTitle", after) }
	); y = y - h

	_, h = Widgets:SectionHeader(parent, L("GENERAL"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Guild Invite",
		  getValue = DBGet(cm, "guildInvite"), setValue = DBSet(cm, "guildInvite", after), disabled = off },
		{ type = "toggle", text = "Who",
		  getValue = DBGet(cm, "who"), setValue = DBSet(cm, "who", after), disabled = off }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Report Stats",
		  getValue = DBGet(cm, "reportStats"), setValue = DBSet(cm, "reportStats", after), disabled = off },
		{ type = "spacer" }
	); y = y - h

	local areaValues = { NONE = "Auto-detect", tw = "Taiwan", kr = "Korea", us = "Americas & Oceania", eu = "Europe" }
	local areaOrder = { "NONE", "tw", "kr", "us", "eu" }
	local function serverValues()
		local result, order = {}, {}
		for realm, area in pairs(cm.armoryOverride) do
			result[realm] = realm .. " > " .. (areaValues[area] or area)
			order[#order + 1] = realm
		end
		table_sort(order)
		result._noLoc = true
		return result, order
	end

	_, h = Widgets:SectionHeader(parent, L("ARMORY"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  getValue = DBGet(cm, "armory"), setValue = DBSet(cm, "armory", after), disabled = off },
		{ type = "dropdown", text = "Set Area",
		  tooltip = "If the game language is different from the primary language in this server, you need to specify which area you play on.",
		  values = areaValues, order = areaOrder,
		  getValue = function() return cm.armoryOverride[E.myrealm] or "NONE" end,
		  setValue = function(v)
			if v == "NONE" then cm.armoryOverride[E.myrealm] = nil else cm.armoryOverride[E.myrealm] = v end
			addon.RefreshOptions()
		  end,
		  disabled = off }
	); y = y - h

	local values, order = serverValues()
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Server List", values = values, order = order,
		  getValue = function() return listSelected end,
		  setValue = function(v) listSelected = v end, disabled = off },
		{ type = "labeledButton", text = "", buttonText = "Delete",
		  onClick = function()
			if not listSelected or not cm.armoryOverride[listSelected] then return end
			cm.armoryOverride[listSelected] = nil
			listSelected = nil
			addon.RefreshOptions()
		  end, disabled = off }
	); y = y - h

	return y
end

addon.RegisterOptionBuilder("social", function(parent, y, _, subPage)
	if subPage == "Chat Bar" then return BuildChatBar(parent, y) end
	if subPage == "Smart Tab" then return BuildSmartTab(parent, y) end
	if subPage == "Chat Link" then return BuildChatLink(parent, y) end
	if subPage == "Emote" then return BuildEmote(parent, y) end
	if subPage == "Friend List" then return BuildFriendList(parent, y) end
	if subPage == "Context Menu" then return BuildContextMenu(parent, y) end
	return y
end)
