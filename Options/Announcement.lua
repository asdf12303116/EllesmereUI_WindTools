local addon = select(2, ...)
local W = addon[1]
local E = addon[3]
local L = addon.L
local DBGet = addon.DBGet
local DBSet = addon.DBSet
local DBGet2 = addon.DBGet2
local DBSet2 = addon.DBSet2
local SafeModuleCall = addon.SafeModuleCall

-- The profile defaults carry the shipped sentences, which is what the "Default"
-- buttons write back. Keeping the table here instead of repeating the strings
-- means a sentence only ever lives in one place.
local P = addon[6]
local Color = W.Utilities.Color

local format = format
local geterrorhandler = geterrorhandler
local ipairs = ipairs
local pairs = pairs
local strfind = strfind
local strlower = strlower
local table_concat = table.concat
local table_sort = table.sort
local type = type
local xpcall = xpcall

local CHANNEL_PARTY = {
	NONE = "None", SELF = "Self (Chat Frame)", EMOTE = "Emote",
	PARTY = "Party", YELL = "Yell", SAY = "Say",
}
local CHANNEL_PARTY_ORDER = { "NONE", "SELF", "EMOTE", "PARTY", "YELL", "SAY" }

local CHANNEL_INSTANCE = {
	NONE = "None", PARTY = "Party", SELF = "Self (Chat Frame)", EMOTE = "Emote",
	INSTANCE_CHAT = "Instance", YELL = "Yell", SAY = "Say",
}
local CHANNEL_INSTANCE_ORDER = { "NONE", "PARTY", "SELF", "EMOTE", "INSTANCE_CHAT", "YELL", "SAY" }

local CHANNEL_RAID = {
	NONE = "None", SELF = "Self (Chat Frame)", EMOTE = "Emote",
	PARTY = "Party", RAID = "Raid", YELL = "Yell", SAY = "Say",
}
local CHANNEL_RAID_ORDER = { "NONE", "SELF", "EMOTE", "PARTY", "RAID", "YELL", "SAY" }

local CHANNEL_SOLO = {
	NONE = "None", SELF = "Self (Chat Frame)", EMOTE = "Emote",
	YELL = "Yell", SAY = "Say",
}
local CHANNEL_SOLO_ORDER = { "NONE", "SELF", "EMOTE", "YELL", "SAY" }

-- Goodbye plays at the end of a dungeon, where the player is in a group by
-- definition, so "self" was never offered there upstream either.
local CHANNEL_GOODBYE_PARTY = { NONE = "None", EMOTE = "Emote", PARTY = "Party", YELL = "Yell", SAY = "Say" }
local CHANNEL_GOODBYE_PARTY_ORDER = { "NONE", "EMOTE", "PARTY", "YELL", "SAY" }
local CHANNEL_GOODBYE_INSTANCE = {
	NONE = "None", EMOTE = "Emote", PARTY = "Party", INSTANCE_CHAT = "Instance", YELL = "Yell", SAY = "Say",
}
local CHANNEL_GOODBYE_INSTANCE_ORDER = { "NONE", "EMOTE", "PARTY", "INSTANCE_CHAT", "YELL", "SAY" }
local CHANNEL_GOODBYE_RAID = { NONE = "None", EMOTE = "Emote", PARTY = "Party", RAID = "Raid", YELL = "Yell", SAY = "Say" }
local CHANNEL_GOODBYE_RAID_ORDER = { "NONE", "EMOTE", "PARTY", "RAID", "YELL", "SAY" }

local UTILITY_CATEGORIES = {
	{ key = "feast", name = "Feasts" },
	{ key = "toy", name = "Toys" },
	{ key = "bot", name = "Bots" },
	{ key = "portal", name = "Portals" },
	{ key = "spell", name = "Spell" },
}

-- Search boxes commit on enter or blur, and the filtered list is baked into a
-- dropdown at build time, so the words and the two selections outlive the page
-- and are reapplied when the page is rebuilt. Empty strings rather than nil:
-- the dropdown resolves its label from the current key, and a nil key would be
-- drawn as the word "nil".
local newSearchWord, newSelected = "", ""
local addedSearchWord, addedSelected = "", ""

local function GetDB()
	return E.db.WT.announcement
end

local function AfterAnnouncement()
	SafeModuleCall(W.Modules.Announcement, "ProfileUpdate")
end

local function AfterQuest()
	-- The quest announcements are driven by SwitchButtons: it is what decides
	-- whether progress is announced at all, so the toggle has to reach it.
	SafeModuleCall(W.Modules.SwitchButtons, "ProfileUpdate")
end

-- A rendered sample is worth more than a description of the tokens, so the
-- current template is run against a made up quest and the result is part of the
-- tooltip. Nothing is shown while the quest backend has not filled in its test
-- context, and a template that renders to nothing simply adds no sample.
local function ExampleText()
	local QP = W:GetModule("QuestProgress", true)
	if not QP or type(QP.GetTestContext) ~= "function" or type(QP.RenderTemplate) ~= "function" then
		return nil
	end

	local ok, message = xpcall(function()
		local context = QP:GetTestContext()
		context.progress = L("Test Target") .. ": 3/10"
		return QP:RenderTemplate(GetDB().quest.template, context)
	end, geterrorhandler())
	if not ok or type(message) ~= "string" or message == "" then return nil end

	return message
end

-- Every element the quest template understands, plus a rendered sample, listed
-- for the tooltip that sits on the template field.
local function TemplateTooltip()
	local parts = {
		L("The template for rendering announcement message."),
		format(L("The template of each element can be customized in %s module."), L("Quest Progress")),
		"",
		Color.StringByTemplate(L("Template Elements"), "blue-400"),
		"{{level}} = " .. L("Quest level"),
		"{{daily}} = " .. L("Daily quest label"),
		"{{weekly}} = " .. L("Weekly quest label"),
		"{{link}} = " .. L("Quest link"),
		"{{tag}} = " .. L("Quest tags (Quest series)"),
		"{{progress}} = " .. L("Quest progress (including objectives)"),
		"{{title}} = " .. L("Quest title"),
		"{{suggestedGroup}} = " .. L("Suggested group size"),
	}

	local example = ExampleText()
	if example then
		parts[#parts + 1] = ""
		parts[#parts + 1] = Color.StringByTemplate(L("Example"), "blue-400") .. ": " .. example
	end

	return table_concat(parts, "\n")
end

-- Utility spells come from the module, which fills them in asynchronously once
-- the client knows which of them this character can actually use. An empty list
-- before that happens is expected and simply draws no options.
local function SpellList(ignore)
	local A = W:GetModule("Announcement", true)
	local source = A and A.ConfigurableUtilitySpells
	local custom = GetDB().utility.custom
	local word = strlower(ignore == "added" and addedSearchWord or newSearchWord)
	local values, order = {}, {}

	if source then
		for spellID, desc in pairs(source) do
			local added = custom[spellID] ~= nil
			local matches = (ignore == "added" and added) or (ignore == "notAdded" and not added)
			if matches and (word == "" or strfind(strlower(desc), word, 1, true)) then
				values[spellID] = desc
				order[#order + 1] = spellID
			end
		end
		table_sort(order, function(a, b) return values[a] < values[b] end)
	end

	-- The descriptions already carry spell names and icons; translating them
	-- would only rewrite text the client produced.
	values._noLoc = true
	return values, order
end

local function BuildGeneral(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local db = GetDB()

	_, h = Widgets:SectionHeader(parent, L("GENERAL"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Toggle the announcement module.",
		  getValue = DBGet(db, "enable"), setValue = DBSet(db, "enable", AfterAnnouncement) },
		{ type = "slider", text = "Same Message Interval", min = 0, max = 3600, step = 1,
		  getValue = DBGet(db, "sameMessageInterval"), setValue = DBSet(db, "sameMessageInterval"),
		  tooltip = L("Time interval between sending same messages measured in seconds.")
			  .. " " .. L("Set to 0 to disable.") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "input", text = "Emote Format", inputWidth = 200,
		  getValue = DBGet(db, "emoteFormat"), setValue = DBSet(db, "emoteFormat"),
		  tooltip = L("The text template used in emote channel.") .. "\n"
			  .. format(L("Default is %s."), Color.StringByTemplate(": %s", "blue-500")) },
		nil
	); y = y - h

	return y
end

local function BuildQuest(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local q = GetDB().quest

	_, h = Widgets:SectionHeader(parent, L("QUEST"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Let your teammates know the progress of quests.",
		  getValue = DBGet(q, "enable"), setValue = DBSet(q, "enable", AfterQuest) },
		{ type = "toggle", text = "Include Details", tooltip = "Announce every time the progress has been changed.",
		  getValue = DBGet(q, "includeDetails"), setValue = DBSet(q, "includeDetails") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Hide Level on Max Level",
		  tooltip = "Do not show quest level if the quest level is the same as the maximum level of your current expansion.",
		  getValue = DBGet(q, "hideLevelOnMaxLevel"), setValue = DBSet(q, "hideLevelOnMaxLevel") },
		{ type = "toggle", text = "Hide Level if Same as Player",
		  tooltip = "Do not show quest level if the quest level is the same as your current level.",
		  getValue = DBGet(q, "hideLevelIfSameAsPlayer"), setValue = DBSet(q, "hideLevelIfSameAsPlayer") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "input", text = "Message Template", inputWidth = 300,
		  getValue = DBGet(q, "template"), setValue = DBSet(q, "template", addon.RefreshOptions),
		  tooltip = TemplateTooltip() },
		nil
	); y = y - h

	_, h = Widgets:Button(parent, L("Default"), y, function()
		q.template = P.announcement.quest.template
		addon.RefreshOptions()
	end); y = y - h

	_, h = Widgets:TripleRow(parent, y,
		{ type = "dropdown", text = "In Party", values = CHANNEL_PARTY, order = CHANNEL_PARTY_ORDER,
		  getValue = DBGet2(q, "channel", "party"), setValue = DBSet2(q, "channel", "party") },
		{ type = "dropdown", text = "In Instance", values = CHANNEL_INSTANCE, order = CHANNEL_INSTANCE_ORDER,
		  getValue = DBGet2(q, "channel", "instance"), setValue = DBSet2(q, "channel", "instance") },
		{ type = "dropdown", text = "In Raid", values = CHANNEL_RAID, order = CHANNEL_RAID_ORDER,
		  getValue = DBGet2(q, "channel", "raid"), setValue = DBSet2(q, "channel", "raid") }
	); y = y - h

	return y
end

local function BuildUtility(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local u = GetDB().utility

	_, h = Widgets:SectionHeader(parent, L("UTILITY"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Send the use of portals, ritual of summoning, feasts, etc.",
		  getValue = DBGet(u, "enable"), setValue = DBSet(u, "enable") },
		{ type = "spacer" }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "Solo", values = CHANNEL_SOLO, order = CHANNEL_SOLO_ORDER,
		  getValue = DBGet2(u, "channel", "solo"), setValue = DBSet2(u, "channel", "solo") },
		{ type = "dropdown", text = "In Party", values = CHANNEL_PARTY, order = CHANNEL_PARTY_ORDER,
		  getValue = DBGet2(u, "channel", "party"), setValue = DBSet2(u, "channel", "party") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "In Instance", values = CHANNEL_INSTANCE, order = CHANNEL_INSTANCE_ORDER,
		  getValue = DBGet2(u, "channel", "instance"), setValue = DBSet2(u, "channel", "instance") },
		{ type = "dropdown", text = "In Raid", values = CHANNEL_RAID, order = CHANNEL_RAID_ORDER,
		  getValue = DBGet2(u, "channel", "raid"), setValue = DBSet2(u, "channel", "raid") }
	); y = y - h

	-- One row per category: the switch on the left, the raid warning switch on
	-- the right, and the sentence itself behind the cog on that row. Three rows of
	-- controls per category would have pushed the section past a screen.
	for _, category in ipairs(UTILITY_CATEGORIES) do
		local cd = u.general and u.general[category.key]
		if cd then
			local row
			row, h = Widgets:DualRow(parent, y,
				{ type = "toggle", text = category.name,
				  getValue = DBGet(cd, "enable"), setValue = DBSet(cd, "enable") },
				{ type = "toggle", text = "Raid Warning",
				  tooltip = "If possible, send the announcement as a raid warning.",
				  getValue = DBGet(cd, "raidWarning"), setValue = DBSet(cd, "raidWarning") }
			); y = y - h
			if row and row._rightRegion then
				addon.AttachCog(row._rightRegion, category.name, {
					{ type = "input", label = "Text", inputWidth = 220,
					  get = function() return cd.text end,
					  set = function(v) cd.text = v or "" end },
				})
			end
		end
	end

	return y
end

local function BuildCustom(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local db = GetDB()
	local custom = db.utility.custom

	_, h = Widgets:SectionHeader(parent, L("CUSTOM"), y); y = y - h

	local notAddedValues, notAddedOrder = SpellList("notAdded")
	_, h = Widgets:DualRow(parent, y,
		{ type = "input", text = "Search", inputWidth = 180,
		  getValue = function() return newSearchWord end,
		  setValue = function(v) newSearchWord = v or ""; addon.RefreshOptions() end },
		{ type = "dropdown", text = "Spell", values = notAddedValues, order = notAddedOrder,
		  getValue = function() return newSelected end,
		  setValue = function(v) newSelected = v end }
	); y = y - h
	_, h = Widgets:Button(parent, L("Add"), y, function()
		if newSelected == "" then return end
		custom[newSelected] = { enable = true, raidWarning = false, text = L("I used %spell%!") }
		addedSelected = newSelected
		newSelected = ""
		newSearchWord = ""
		addon.RefreshOptions()
	end); y = y - h

	local addedValues, addedOrder = SpellList("added")
	_, h = Widgets:DualRow(parent, y,
		{ type = "input", text = "Search", inputWidth = 180,
		  getValue = function() return addedSearchWord end,
		  setValue = function(v) addedSearchWord = v or ""; addon.RefreshOptions() end },
		{ type = "dropdown", text = "Added", values = addedValues, order = addedOrder,
		  getValue = function() return addedSelected end,
		  setValue = function(v) addedSelected = v end }
	); y = y - h
	_, h = Widgets:Button(parent, L("Delete"), y, function()
		if addedSelected == "" then return end
		custom[addedSelected] = nil
		addedSelected = ""
		addon.RefreshOptions()
	end); y = y - h

	-- The edit controls stay on the page and act on whatever is selected above,
	-- so picking another spell changes what they edit instead of moving them.
	local function Selected()
		if addedSelected == "" then return end
		return custom[addedSelected]
	end

	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable",
		  getValue = function() local c = Selected() return c and c.enable end,
		  setValue = function(v) local c = Selected() if c then c.enable = v end end },
		{ type = "toggle", text = "Raid Warning",
		  tooltip = "If possible, send the announcement as a raid warning.",
		  getValue = function() local c = Selected() return c and c.raidWarning end,
		  setValue = function(v) local c = Selected() if c then c.raidWarning = v end end }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "input", text = "Text", inputWidth = 300,
		  getValue = function() local c = Selected() return c and c.text end,
		  setValue = function(v) local c = Selected() if c then c.text = v or "" end end },
		nil
	); y = y - h

	return y
end

local function BuildGoodbye(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local gb = GetDB().goodbye

	_, h = Widgets:SectionHeader(parent, L("GOODBYE"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Say goodbye after dungeon completed.",
		  getValue = DBGet(gb, "enable"), setValue = DBSet(gb, "enable") },
		{ type = "slider", text = "Delay (sec)", min = 0, max = 20, step = 1,
		  getValue = DBGet(gb, "delay"), setValue = DBSet(gb, "delay"),
		  tooltip = format(L("Default is %s."), P.announcement.goodbye.delay) }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "input", text = "Text", inputWidth = 300,
		  getValue = DBGet(gb, "text"), setValue = DBSet(gb, "text") },
		nil
	); y = y - h
	_, h = Widgets:Button(parent, L("Default Text"), y, function()
		gb.text = P.announcement.goodbye.text
		addon.RefreshOptions()
	end); y = y - h
	_, h = Widgets:TripleRow(parent, y,
		{ type = "dropdown", text = "In Party", values = CHANNEL_GOODBYE_PARTY, order = CHANNEL_GOODBYE_PARTY_ORDER,
		  getValue = DBGet2(gb, "channel", "party"), setValue = DBSet2(gb, "channel", "party") },
		{ type = "dropdown", text = "In Instance", values = CHANNEL_GOODBYE_INSTANCE, order = CHANNEL_GOODBYE_INSTANCE_ORDER,
		  getValue = DBGet2(gb, "channel", "instance"), setValue = DBSet2(gb, "channel", "instance") },
		{ type = "dropdown", text = "In Raid", values = CHANNEL_GOODBYE_RAID, order = CHANNEL_GOODBYE_RAID_ORDER,
		  getValue = DBGet2(gb, "channel", "raid"), setValue = DBSet2(gb, "channel", "raid") }
	); y = y - h

	return y
end

local function BuildResetInstance(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local ri = GetDB().resetInstance

	_, h = Widgets:SectionHeader(parent, L("RESET INSTANCE"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Send a message after instance resetting.",
		  getValue = DBGet(ri, "enable"), setValue = DBSet(ri, "enable") },
		{ type = "toggle", text = "Difficulty Change", tooltip = "Also announce when you change the instance difficulty.",
		  getValue = DBGet(ri, "difficultyChange"), setValue = DBSet(ri, "difficultyChange") }
	); y = y - h
	_, h = Widgets:TripleRow(parent, y,
		{ type = "dropdown", text = "In Party", values = CHANNEL_PARTY, order = CHANNEL_PARTY_ORDER,
		  getValue = DBGet2(ri, "channel", "party"), setValue = DBSet2(ri, "channel", "party") },
		{ type = "dropdown", text = "In Instance", values = CHANNEL_INSTANCE, order = CHANNEL_INSTANCE_ORDER,
		  getValue = DBGet2(ri, "channel", "instance"), setValue = DBSet2(ri, "channel", "instance") },
		{ type = "dropdown", text = "In Raid", values = CHANNEL_RAID, order = CHANNEL_RAID_ORDER,
		  getValue = DBGet2(ri, "channel", "raid"), setValue = DBSet2(ri, "channel", "raid") }
	); y = y - h

	return y
end

local function BuildKeystone(parent, y)
	local Widgets = EllesmereUI.Widgets
	local _, h
	local ks = GetDB().keystone

	_, h = Widgets:SectionHeader(parent, L("KEYSTONE"), y); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "toggle", text = "Enable", tooltip = "Announce your mythic keystone.",
		  getValue = DBGet(ks, "enable"), setValue = DBSet(ks, "enable") },
		{ type = "toggle", text = "!keys Command",
		  tooltip = "Send the keystone to party or guild chat when someone use !keys command.",
		  getValue = DBGet(ks, "command"), setValue = DBSet(ks, "command") }
	); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "input", text = "Text", inputWidth = 300,
		  getValue = DBGet(ks, "text"), setValue = DBSet(ks, "text"),
		  tooltip = Color.StringByTemplate("%keystone%", "blue-400") .. " = " .. L("Keystone") },
		nil
	); y = y - h
	_, h = Widgets:Button(parent, L("Default Text"), y, function()
		ks.text = P.announcement.keystone.text
		addon.RefreshOptions()
	end); y = y - h
	_, h = Widgets:DualRow(parent, y,
		{ type = "dropdown", text = "In Party", values = CHANNEL_PARTY, order = CHANNEL_PARTY_ORDER,
		  getValue = DBGet2(ks, "channel", "party"), setValue = DBSet2(ks, "channel", "party") },
		{ type = "spacer" }
	); y = y - h

	return y
end

-- One section per backend feature, in the order a setup pass would touch them.
-- The keystone section is retail-only: the eternal realm has no keystone system.
addon.RegisterOptionBuilder("announcement", function(parent, y)
	y = BuildGeneral(parent, y)
	y = BuildQuest(parent, y)
	y = BuildUtility(parent, y)
	y = BuildCustom(parent, y)
	y = BuildGoodbye(parent, y)
	y = BuildResetInstance(parent, y)
	if not E.Forever then
		y = BuildKeystone(parent, y)
	end
	return y
end)
