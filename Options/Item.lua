local addon = select(2, ...)
local E = addon[3]
local DBGet = addon.DBGet
local DBSet = addon.DBSet
local GetLSMFonts = addon.GetLSMFonts
local FONT_OUTLINE_VALUES = addon.FONT_OUTLINE_VALUES
local FONT_OUTLINE_ORDER = addon.FONT_OUTLINE_ORDER

local ALREADY_KNOWN_MODE = { COLOR = "Custom Color", MONOCHROME = "Monochrome" }
local ALREADY_KNOWN_MODE_ORDER = { "COLOR", "MONOCHROME" }

local DELETE_FILL_VALUES = { NONE = "Disable", CLICK = "Fill by click", AUTO = "Auto Fill" }
local DELETE_FILL_ORDER = { "NONE", "CLICK", "AUTO" }

local CONTACTS_PAGE_VALUES = {
	ALTS = "Alternate Character",
	FRIENDS = "Online Friends",
	GUILD = "Guild Members",
	FAVORITE = "My Favorites",
}
local CONTACTS_PAGE_ORDER = { "ALTS", "FRIENDS", "GUILD", "FAVORITE" }

-- Section headers are one uppercase word each, following the EllesmereUI pages.
-- Upstream gave every module a header of its own and then a second one for its
-- "Lists" or "Slot" slice; the controls are unchanged, they just sit together
-- now. TEXT and ICONS are EllesmereUI's own keys, so they are not redefined in
-- Locales/ (the shared locale table would overwrite EUI's translation).
local function FontRow(Widgets, parent, y, dbTable, text)
	local fonts = GetLSMFonts()
	local fontOrder = {}
	for name in pairs(fonts) do fontOrder[#fontOrder + 1] = name end
	table.sort(fontOrder)

	local _, h = Widgets:TripleRow(parent, y,
		{ type = "dropdown", text = text, values = fonts, order = fontOrder,
		  getValue = DBGet(dbTable, "name"), setValue = DBSet(dbTable, "name") },
		{ type = "dropdown", text = "Outline", values = FONT_OUTLINE_VALUES, order = FONT_OUTLINE_ORDER,
		  getValue = DBGet(dbTable, "style"), setValue = DBSet(dbTable, "style") },
		{ type = "slider", text = "Size", min = 5, max = 60, step = 1,
		  getValue = DBGet(dbTable, "size"), setValue = DBSet(dbTable, "size") })
	return y - h
end

-- =========================================================================
--  Sub-page: Loot & Trade  (Delete Item + Fast Loot + Trade + Merchant)
-- =========================================================================
local function BuildLootTrade(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local db = E.db.WT.item

	_, h = Widgets:SectionHeader(parent, "LOOT", y); y = y - h
	do
		local dl, fl = db.delete, db.fastLoot
		local flDis = function() return not fl.enable end
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Delete Item",
			  tooltip = "This module provides several easy-to-use methods of deleting items.",
			  getValue = DBGet(dl, "enable"), setValue = DBSet(dl, "enable") },
			{ type = "toggle", text = "Fast Loot",
			  tooltip = "This module will accelerate the speed of loot.",
			  getValue = DBGet(fl, "enable"), setValue = DBSet(fl, "enable") }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Use Delete Key",
			  tooltip = "Allow you to use Delete Key for confirming deleting.",
			  getValue = DBGet(dl, "delKey"), setValue = DBSet(dl, "delKey"),
			  disabled = function() return not dl.enable end },
			{ type = "dropdown", text = "Fill In",
			  values = DELETE_FILL_VALUES, order = DELETE_FILL_ORDER,
			  getValue = DBGet(dl, "fillIn"), setValue = DBSet(dl, "fillIn"),
			  disabled = function() return not dl.enable end }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Limit", min = 0.05, max = 0.5, step = 0.01,
			  tooltip = "The time delay between every loot operations. (Default is 0.3)",
			  getValue = DBGet(fl, "limit"), setValue = DBSet(fl, "limit"), disabled = flDis },
			{ type = "spacer" }
		); y = y - h
	end

	_, h = Widgets:SectionHeader(parent, "TRADE", y); y = y - h
	do
		local td = db.trade
		local tdDis = function() return not td.enable end
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Enable",
			  tooltip = "Add some features on Trade Frame.",
			  getValue = DBGet(td, "enable"), setValue = DBSet(td, "enable") },
			{ type = "toggle", text = "Thanks Button",
			  getValue = DBGet(td, "thanksButton"), setValue = DBSet(td, "thanksButton"),
			  disabled = tdDis }
		); y = y - h
	end

	_, h = Widgets:SectionHeader(parent, "MERCHANT", y); y = y - h
	do
		local emp = E.private.WT.item.extendMerchantPages
		local empDis = function() return not emp.enable end
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Enable",
			  tooltip = "Extends the merchant page to show more items.",
			  getValue = DBGet(emp, "enable"), setValue = DBSet(emp, "enable") },
			{ type = "slider", text = "Number of Pages", min = 2, max = 6, step = 1,
			  tooltip = "The number of pages shown in the merchant frame.",
			  getValue = DBGet(emp, "numberOfPages"), setValue = DBSet(emp, "numberOfPages"),
			  disabled = empDis }
		); y = y - h
	end

	return y
end

-- =========================================================================
--  Sub-page: Display  (Already Known + Contacts)
-- =========================================================================
local function BuildDisplay(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local db = E.db.WT.item

	_, h = Widgets:SectionHeader(parent, "ALREADY KNOWN", y); y = y - h
	do
		local ak = db.alreadyKnown
		local akDis = function() return not ak.enable end
		local customDis = function() return akDis() or ak.mode ~= "COLOR" end
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Enable",
			  tooltip = "Puts a overlay on already known learnable items on vendors and AH.",
			  getValue = DBGet(ak, "enable"), setValue = DBSet(ak, "enable") },
			{ type = "dropdown", text = "Mode",
			  values = ALREADY_KNOWN_MODE, order = ALREADY_KNOWN_MODE_ORDER,
			  getValue = DBGet(ak, "mode"), disabled = akDis,
			  -- The swatch below only unlocks once the mode is COLOR, and the
			  -- page is not rebuilt by a plain assignment.
			  setValue = function(value)
				  ak.mode = value
				  addon.RefreshOptions()
			  end }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "colorpicker", text = "Custom Color", disabled = customDis,
			  getValue = function()
				  local c = ak.color or {}
				  return c.r or 0, c.g or 1, c.b or 0, 1
			  end,
			  setValue = function(r, g, b)
				  ak.color = ak.color or {}
				  ak.color.r, ak.color.g, ak.color.b = r, g, b
			  end },
			{ type = "spacer" }
		); y = y - h
	end

	_, h = Widgets:SectionHeader(parent, "CONTACTS", y); y = y - h
	do
		local ct = db.contacts
		local ctDis = function() return not ct.enable end
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Enable",
			  tooltip = "Add a contact frame beside the mail frame.",
			  getValue = DBGet(ct, "enable"), setValue = DBSet(ct, "enable") },
			{ type = "toggle", text = "Update Alts",
			  tooltip = "Update the alt list when you log in.",
			  getValue = function() return E.global.WT.item.contacts.updateAlts end,
			  setValue = function(v) E.global.WT.item.contacts.updateAlts = v end,
			  disabled = ctDis }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "dropdown", text = "Default Page",
			  values = CONTACTS_PAGE_VALUES, order = CONTACTS_PAGE_ORDER,
			  getValue = DBGet(ct, "defaultPage"), setValue = DBSet(ct, "defaultPage"),
			  disabled = ctDis },
			{ type = "spacer" }
		); y = y - h
	end

	return y
end

-- =========================================================================
--  Sub-page: Inspect  (Inspect + Item Level)
-- =========================================================================
local function BuildInspect(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local db = E.db.WT.item
	local is = db.inspect
	local isDis = function() return not is.enable end
	local inspectOnlyDis = function() return isDis() or not is.inspect end

	_, h = Widgets:SectionHeader(parent, "INSPECT", y); y = y - h
	-- The sidebar used to carry this switch; the page owns it now that the
	-- standalone panel is gone.
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Toggle the inspect module.",
		  getValue = DBGet(is, "enable"), setValue = DBSet(is, "enable") },
		{ type = "toggle", text = "Always Show Mine",
		  tooltip = "Display character equipments list when you inspect someone.",
		  getValue = DBGet(is, "playerOnInspect"), setValue = DBSet(is, "playerOnInspect"),
		  disabled = inspectOnlyDis }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Player", tooltip = "Add a frame to your character panel.",
		  getValue = DBGet(is, "player"), setValue = DBSet(is, "player"), disabled = isDis },
		{ type = "toggle", text = "Inspect", tooltip = "Add a frame to Inspect Frame.",
		  getValue = DBGet(is, "inspect"), setValue = DBSet(is, "inspect"), disabled = isDis }
	); y = y - h

	_, h = Widgets:SectionHeader(parent, "TEXT", y); y = y - h
	do
		local ii, gi, ei = is.itemIcon, is.gemIcon, is.enchantIcon
		local iiDis = function() return isDis() or not ii.enable end
		local giDis = function() return isDis() or not gi.enable end
		local eiDis = function() return isDis() or not ei.enable end
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Item Icon", tooltip = "Show the item icon in the inspect list.",
			  getValue = DBGet(ii, "enable"), setValue = DBSet(ii, "enable"), disabled = isDis },
			{ type = "toggle", text = "Quality Border",
			  tooltip = "Show the quality border on the icon.",
			  getValue = DBGet(ii, "qualityBorder"), setValue = DBSet(ii, "qualityBorder"), disabled = iiDis }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Width", min = 5, max = 40, step = 1,
			  getValue = DBGet(ii, "width"), setValue = DBSet(ii, "width"), disabled = iiDis },
			{ type = "slider", text = "Height", min = 5, max = 40, step = 1,
			  getValue = DBGet(ii, "height"), setValue = DBSet(ii, "height"), disabled = iiDis }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Indicator",
			  tooltip = "Show the special mark on the icon to indicate the crafting quality, tier set, etc.",
			  getValue = DBGet(ii, "indicator"), setValue = DBSet(ii, "indicator"), disabled = iiDis },
			{ type = "spacer" }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Gem Icon",
			  getValue = DBGet(gi, "enable"), setValue = DBSet(gi, "enable"), disabled = isDis },
			{ type = "toggle", text = "Show Addable Sockets",
			  tooltip = "Show the icon of addable sockets if the item has empty sockets.",
			  getValue = DBGet(gi, "showAddableSockets"), setValue = DBSet(gi, "showAddableSockets"),
			  disabled = giDis }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "slider", text = "Size", min = 5, max = 30, step = 1,
			  getValue = DBGet(gi, "size"), setValue = DBSet(gi, "size"), disabled = giDis },
			{ type = "spacer" }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Enchant Icon",
			  getValue = DBGet(ei, "enable"), setValue = DBSet(ei, "enable"), disabled = isDis },
			{ type = "slider", text = "Size", min = 5, max = 30, step = 1,
			  getValue = DBGet(ei, "size"), setValue = DBSet(ei, "size"), disabled = eiDis }
		); y = y - h
	end

	_, h = Widgets:SectionHeader(parent, "ITEM LEVEL", y); y = y - h
	do
		local il = db.itemLevel
		local ilDis = function() return not il.enable end
		local fo, sm = il.flyout, il.scrappingMachine
		-- The sidebar used to carry this switch; the page owns it now that the
		-- standalone panel is gone.
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Enable", tooltip = "Toggle the item level module.",
			  getValue = DBGet(il, "enable"), setValue = DBSet(il, "enable") },
			{ type = "spacer" }
		); y = y - h
		_, h = Widgets:DualRow(parent, y,
			{ type = "toggle", text = "Flyout Button",
			  getValue = DBGet(fo, "enable"), setValue = DBSet(fo, "enable"), disabled = ilDis },
			{ type = "toggle", text = "Scrapping Machine",
			  getValue = DBGet(sm, "enable"), setValue = DBSet(sm, "enable"), disabled = ilDis }
		); y = y - h
		y = FontRow(Widgets, parent, y, fo.font, "Flyout Button")
		y = FontRow(Widgets, parent, y, sm.font, "Scrapping Machine")
	end

	return y
end

-- =========================================================================
--  Single builder with sub-page dispatch (EUI pattern)
-- =========================================================================
addon.RegisterOptionBuilder("item", function(parent, y, _, subPage)
	if subPage == "Loot & Trade" then
		return BuildLootTrade(parent, y)
	elseif subPage == "Display" then
		return BuildDisplay(parent, y)
	elseif subPage == "Inspect" then
		return BuildInspect(parent, y)
	end
	return y
end)
