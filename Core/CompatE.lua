local addonName, addon = ...

local EUI = _G.EllesmereUI
if not EUI then
	return
end

local FONT_KEY = addonName
local unpack = unpack
local type = type
local pairs = pairs
local tostring = tostring
local tonumber = tonumber
local format = format
local floor = floor
local max = math.max
local min = math.min
local strmatch = string.match
local gsub = string.gsub
local strsplit = strsplit
local wipe = wipe
local next = next
local CreateFrame = _G.CreateFrame
local GetAverageItemLevel = _G.GetAverageItemLevel
local GetMouseFoci = _G.GetMouseFoci
local UnitFactionGroup = _G.UnitFactionGroup
local UnitGUID = _G.UnitGUID

local function DeepCopy(value, seen)
	if type(value) ~= "table" then
		return value
	end

	seen = seen or {}
	if seen[value] then
		return seen[value]
	end

	local copy = {}
	seen[value] = copy
	for key, child in pairs(value) do
		copy[DeepCopy(key, seen)] = DeepCopy(child, seen)
	end
	return copy
end

local function CopyTable(target, source)
	if type(target) ~= "table" or type(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			CopyTable(target[key], value)
		else
			target[key] = value
		end
	end

	return target
end

local function RemoveTableDuplicates(target, defaults)
	if type(target) ~= "table" or type(defaults) ~= "table" then
		return target
	end

	for key, value in pairs(defaults) do
		if type(value) == "table" and type(target[key]) == "table" then
			RemoveTableDuplicates(target[key], value)
			if next(target[key]) == nil then
				target[key] = nil
			end
		elseif target[key] == value then
			target[key] = nil
		end
	end

	return target
end

local function SplitString(text, separator)
	separator = separator or ","
	local first, second = strsplit(separator, text or "")
	return first, second
end

-- ElvUI-compatible global table utilities (missing from EllesmereUI).
-- SmartTab and other WindTools modules reference these as bare globals.
local function TableShallowCopy(src)
	if type(src) ~= "table" then
		return src
	end
	local dest = {}
	for k, v in pairs(src) do
		dest[k] = v
	end
	return dest
end

local function TableAppendAll(dest, src)
	if type(dest) ~= "table" or type(src) ~= "table" then
		return
	end
	for i = 1, #src do
		dest[#dest + 1] = src[i]
	end
end

local function TableInvert(tbl)
	if type(tbl) ~= "table" then
		return {}
	end
	local result = {}
	for k, v in pairs(tbl) do
		result[v] = k
	end
	return result
end

local function GetFontPath()
	return EUI.GetFontPath and EUI.GetFontPath(FONT_KEY) or _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function GetFontName()
	return EUI.GetFontName and EUI.GetFontName(FONT_KEY) or "Expressway"
end

-- Resolve the outline flag: if a specific style is explicitly passed (and it's
-- not "NONE", which WindTools uses as the "use default" sentinel), apply it
-- directly with slug gating. Otherwise fall back to EllesmereUI's global or
-- per-module outline setting.
local function GetFontOutlineFlag(fallback)
	if fallback and fallback ~= "NONE" and fallback ~= "" then
		-- Specific flag like "OUTLINE", "THICKOUTLINE", "MONOCHROME", etc.
		if EUI.SlugFlag then
			return EUI.SlugFlag(fallback)
		end
		return fallback
	end
	return EUI.GetFontOutlineFlag and EUI.GetFontOutlineFlag(FONT_KEY) or ""
end

local function PrimeAndSetFont(fontString, font, size, flags)
	if not fontString or not fontString.SetFont then
		return
	end

	-- Resolve font path: if a font name/path is given, pass through; otherwise
	-- use the EllesmereUI global/module font.  Inline paths or LSM-registered
	-- names both work: EUI.GetFontPath handles the full resolution chain.
	if font and not strfind(font, "\\") and not strfind(font, "/") then
		-- Looks like a font name, not a path — resolve via EllesmereUI.
		font = (EUI.ResolveFontName and EUI.ResolveFontName(font)) or font
	end
	font = font or GetFontPath()
	size = size or select(2, fontString:GetFont()) or 12
	flags = GetFontOutlineFlag(flags)
	if EUI.PrimeFontShadow then
		EUI.PrimeFontShadow(fontString, flags == "")
	end
	fontString:SetFont(font, size, flags)
end

local function InstallFontTemplateCompat()
	local region = CreateFrame("Frame"):CreateFontString(nil, "ARTWORK")
	local meta = getmetatable(region)
	if meta and meta.__index and not meta.__index.FontTemplate then
		meta.__index.FontTemplate = function(self, font, size, flags)
			PrimeAndSetFont(self, font, size, flags)
		end
	end
end

local function ClampColor(value)
	return max(0, min(1, tonumber(value) or 0))
end

local function ColorHex(r, g, b)
	return format("%02x%02x%02x", floor(ClampColor(r) * 255 + 0.5), floor(ClampColor(g) * 255 + 0.5), floor(ClampColor(b) * 255 + 0.5))
end

local function TextGradient(text, r1, g1, b1)
	return "|cff" .. ColorHex(r1 or 1, g1 or 1, b1 or 1) .. tostring(text or "") .. "|r"
end

local function ClassColor(classFile, asTable)
	local color
	if EUI.GetClassColor then
		color = EUI.GetClassColor(classFile)
	elseif _G.C_ClassColor and C_ClassColor.GetClassColor then
		color = C_ClassColor.GetClassColor(classFile)
	end

	color = color or { r = 1, g = 1, b = 1 }
	if asTable then
		return { r = color.r or 1, g = color.g or 1, b = color.b or 1 }
	end
	return color.r or 1, color.g or 1, color.b or 1
end

local function CreateCompatE()
	InstallFontTemplateCompat()

	local E = {
		UIParent = _G.UIParent,
		TexCoords = { 0, 1, 0, 1 },
		PopupDialogs = _G.StaticPopupDialogs or {},
		ConfigModeLayouts = {},
		ConfigModeLocalizedStrings = {},
		NewSign = "",
		version = 999,
		noop = function() end,
		media = {
			normFont = GetFontPath(),
			rgbvaluecolor = { r = 0.05, g = 0.82, b = 0.62 },
			-- EllesmereUI uses Blizzard's built-in white pixel texture as
			-- the universal base texture (equivalent to ElvUI's normTex).
			normTex = "Interface\\Buttons\\WHITE8x8",
			glossTex = "Interface\\Buttons\\WHITE8x8",
			-- ElvUI calls this blankTex; it is the same white pixel.
			blankTex = "Interface\\Buttons\\WHITE8x8",
		},
		-- EllesmereUI ships no media library of its own, so the few textures
		-- and chat logos the ported modules reference are bundled with this
		-- addon under Media\Textures and Media\ChatLogos. The tables have to
		-- exist before Media\Media.lua runs, which is why they are populated
		-- at the bottom of this function rather than there.
		Media = {
			Textures = {},
			ChatLogos = {},
		},
		db = {
			general = {
				font = GetFontName(),
				fontSize = 12,
				valuecolor = { r = 0.05, g = 0.82, b = 0.62 },
				-- Keys the ported modules read directly. EllesmereUI has no
				-- general settings page of its own, so these are frozen here to
				-- keep the modules' colour and abbreviation code working.
				bordercolor = { r = 0, g = 0, b = 0 },
				numberPrefixStyle = "ENGLISH",
				decimalLength = 1,
				minimap = { scale = 1 },
			},
			unitframe = {
				statusbar = "Blizzard",
				font = GetFontName(),
				fontSize = 12,
				fontOutline = "OUTLINE",
			},
		},
		global = {
			general = {
				-- ElvUI kept the client locale on this table and a few ported
				-- modules read it to pick Chinese-only spacing rules. Reading an
				-- absent field would silently take the western branch.
				locale = GetLocale(),
			},
		},
		private = {},
		Libs = {},
	}

	E.myname = UnitName("player") or "Player"
	E.myrealm = GetRealmName and GetRealmName() or "Realm"
	E.mynameRealm = E.myname .. "-" .. E.myrealm
	E.myclass = select(2, UnitClass("player")) or "PRIEST"
	E.myClassColor = ClassColor(E.myclass, true)
	E.myrace = select(2, UnitRace("player")) or "Human"

	-- The ported modules were written against ElvUI's own fields. EllesmereUI
	-- has no equivalent object, so the ones the modules actually read are
	-- declared here: client flags, identity, and the padding constants the
	-- upstream skinning code used for its 1px borders.
	E.myguid = UnitGUID("player")
	E.myfaction, E.myLocalizedFaction = UnitFactionGroup("player")
	E.myfraction = E.myfaction
	E.name = E.myname
	E.myrealm = E.myrealm or ""

	local projectID = _G.WOW_PROJECT_ID
	E.Retail = projectID == _G.WOW_PROJECT_MAINLINE
	E.Forever = _G.WOW_PROJECT_CAMELOT ~= nil and projectID == _G.WOW_PROJECT_CAMELOT
	E.Modern = E.Retail or E.Forever
	E.Classic = projectID == _G.WOW_PROJECT_CLASSIC
	E.TBC = projectID == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC
	E.Mists = projectID == _G.WOW_PROJECT_MISTS_CLASSIC

	-- Placeholder for the pixel-perfect flag. Modules read E.PixelMode and the
	-- two padding constants below; EllesmereUI keeps its own pixel scale in
	-- EllesmereUI.PP, and E:Scale is wired to it further down.
	E.PixelMode = (EUI.PP and EUI.PP.perfect ~= nil) and true or false
	E.Border = E.PixelMode and 1 or 2
	E.Spacing = E.PixelMode and 0 or 1
	E.twoPixelsPlease = false
	E.InfoColor = "|cff1784d1"
	E.InfoColor2 = "|cff9b9b9b"
	E.initialized = false

	-- Number abbreviation state. BuildAbbreviateConfigs fills these in;
	-- declaring them here keeps Modules\Misc\Math.lua able to hook the method
	-- even on a client where the module runs before anything else touches it.
	E.ShortPrefixValues = {}
	E.ShortPrefixStyles = {
		CHINESE = { { 1e12, "兆" }, { 1e8, "亿" }, { 1e4, "万" } },
		TCHINESE = { { 1e12, "兆" }, { 1e8, "億" }, { 1e4, "萬" } },
		KOREAN = { { 1e12, "조" }, { 1e8, "억" }, { 1e4, "만" } },
		ENGLISH = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } },
		GERMAN = { { 1e12, "Bio" }, { 1e9, "Mrd" }, { 1e6, "Mio" }, { 1e3, "Tsd" } },
		METRIC = { { 1e12, "T" }, { 1e9, "G" }, { 1e6, "M" }, { 1e3, "k" } },
	}
	E.Abbreviate = { short = nil, long = nil }
	E.ShortValueDec = "%.1f"

	-- Media pointers. These have to be filled before Media\Media.lua runs,
	-- because W.Media.RoleIcons.DEFAULT copies the tank/healer/damager paths
	-- out of E.Media.Textures at load time.
	do
		local mediaRoot = [[Interface\AddOns\EllesmereUI_WindTools\Media\]]
		local textures = {
			Tank = "Tank",
			Healer = "Healer",
			DPS = "DPS",
			ArrowUp = "ArrowUp",
			Close = "Close",
			Melli = "Melli",
			MinusButton = "MinusButton",
			PlusButton = "PlusButton",
			White8x8 = "White8x8",
			GlowTex = "GlowTex",
			BagQuestIcon = "BagQuestIcon",
		}
		for key, file in pairs(textures) do
			E.Media.Textures[key] = mediaRoot .. "Textures\\" .. file .. ".tga"
		end

		local logos = {
			"ElvBlue",
			"ElvGreen",
			"ElvOrange",
			"ElvPink",
			"ElvPurple",
			"ElvYellow",
			"ElvRed",
			"ElvSimpy",
			"Rainbow",
			"Hibiscus",
			"Gem",
			"Beer",
			"PalmTree",
			"TyroneBiggums",
			"SuperBear",
		}
		for i = 1, #logos do
			E.Media.ChatLogos[logos[i]] = mediaRoot .. "ChatLogos\\" .. logos[i] .. ".tga"
		end
	end

	function E:Delay(delay, callback, ...)
		local args = { ... }
		local timer = C_Timer.NewTimer(delay or 0, function()
			callback(unpack(args))
		end)
		return timer
	end

	function E:CopyTable(target, source)
		if target == nil then
			return DeepCopy(source)
		end
		return CopyTable(target, source)
	end

	function E:RemoveTableDuplicates(target, defaults)
		return RemoveTableDuplicates(target, defaults)
	end

	function E:SplitString(text, separator)
		return SplitString(text, separator)
	end

	function E:TextGradient(text, r1, g1, b1)
		return TextGradient(text, r1, g1, b1)
	end

	function E:ClassColor(classFile, asTable)
		return ClassColor(classFile, asTable)
	end

	-- UIFrameFade* is not part of the documented API surface, so a client may
	-- ship without it. Fall back to setting the target alpha directly: the fade
	-- is cosmetic, and a hard jump beats an error on the mouse-over path.
	function E:UIFrameFadeIn(frame, timeToFade, startAlpha, endAlpha)
		if UIFrameFadeIn then
			return UIFrameFadeIn(frame, timeToFade, startAlpha, endAlpha)
		end
		frame:SetAlpha(endAlpha or 1)
	end

	function E:UIFrameFadeOut(frame, timeToFade, startAlpha, endAlpha)
		if UIFrameFadeOut then
			return UIFrameFadeOut(frame, timeToFade, startAlpha, endAlpha)
		end
		frame:SetAlpha(endAlpha or 0)
	end

	function E:StaticPopup_Show(name, ...)
		return StaticPopup_Show(name, ...)
	end

	function E:ToggleOptions(path)
		-- Kept for modules ported from WindTools that still call E:ToggleOptions
		-- with an ElvUI-style path like "WindTools,information,changelog". The
		-- pages live in the EllesmereUI panel, so the path is resolved there.
		if addon.OpenOptionsPlugin then
			addon.OpenOptionsPlugin(path)
		end
	end

	function E:Print(...)
		if EUI.Print then
			return EUI.Print(...)
		end
	end

	function E:IsAddOnEnabled(name)
		return C_AddOns.GetAddOnEnableState(name, E.myname) == 2
	end

	function E:IsSecretValue(value)
		if issecretvalue then
			return issecretvalue(value)
		end
		return value == nil
	end

	function E:NotSecretValue(value)
		if issecretvalue then
			return not issecretvalue(value)
		end
		return value ~= nil
	end

	function E:AddLib(key, major)
		self.Libs[key] = LibStub and LibStub:GetLibrary(major, true)
		return self.Libs[key]
	end

	E.Libs.LSM = LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)
	E.Libs.Deflate = LibStub and LibStub:GetLibrary("LibDeflate", true)
	E.Libs.Keystone = LibStub and LibStub:GetLibrary("LibKeystone", true)
	E.Libs.OpenRaid = LibStub and LibStub:GetLibrary("LibOpenRaid-1.0", true)

	-----------------------------------------------------------------------
	--  ElvUI utility shims
	--
	--  The modules ported from WindTools were written against ElvUI's helper
	--  set. EllesmereUI has none of these, so each one is reimplemented here
	--  on top of the Blizzard API both clients share (120105 and 16001).
	-----------------------------------------------------------------------

	function E:Round(num, idp)
		if type(num) ~= "number" then
			return num, idp
		end

		local mult = 10 ^ (idp or 0)
		if idp and idp > 0 then
			return floor(num * mult + 0.5) / mult
		end
		return floor(num + 0.5)
	end

	-- C_Item.GetCurrentItemLevel wants an ItemLocation, and the gear scan in
	-- Modules\Item\Inspect.lua reads .iLvl out of the returned table. C_TooltipInfo
	-- exists on both clients, which is why the scan uses it rather than a
	-- hidden GameTooltip.
	function E:GetGearSlotInfo(unit, slot, deepScan)
		if not C_TooltipInfo or not C_TooltipInfo.GetInventoryItem then
			return {}
		end
		if not E:NotSecretValue(unit) or not E:NotSecretValue(slot) then
			return {}
		end

		local data = C_TooltipInfo.GetInventoryItem(unit, slot)
		local slotInfo = {}
		if not data or not data.lines then
			return slotInfo
		end

		if deepScan then
			slotInfo.gems, slotInfo.essences = nil, nil
		end

		local matchItemLevel = ITEM_LEVEL and ITEM_LEVEL:gsub("%%d", "(%%d+)")
		local matchItemLevelAlt = ITEM_LEVEL_ALT and ITEM_LEVEL_ALT:gsub("%%d(%s?)%(%%d%)", "%%d+%1%%((%%d+)%%)")
		for i = 1, #data.lines do
			local line = data.lines[i]
			local text = line and line.leftText
			if text == RETRIEVING_ITEM_INFO then
				return "tooSoon"
			end
			if text and matchItemLevelAlt and matchItemLevel then
				local level = strmatch(text, matchItemLevelAlt) or strmatch(text, matchItemLevel)
				if level then
					slotInfo.iLvl = tonumber(level)
					break
				end
			end
		end

		return slotInfo
	end

	-- C_PaperDollInfo.GetInspectItemLevel covers the inspect case on both
	-- clients. The player is answered from the average equipped level, which
	-- is what the upstream module showed for its own frame.
	function E:GetUnitItemLevel(unit)
		unit = unit or "player"
		if unit == "player" then
			local _, equipped = GetAverageItemLevel()
			return equipped or 0
		end

		if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel and E:NotSecretValue(unit) then
			local level = C_PaperDollInfo.GetInspectItemLevel(unit)
			if level and level > 0 then
				return level
			end
		end

		return 0
	end

	function E:ShortValue(value, dec)
		if type(value) ~= "number" then
			return tostring(value)
		end

		local style = E.ShortPrefixStyles and E.db and E.db.general and E.db.general.numberPrefixStyle
		local values = (style and E.ShortPrefixStyles[style]) or E.ShortPrefixStyles.ENGLISH
		if not values then
			return format("%.0f", value)
		end

		local decimal = dec and format("%%.%df", tonumber(dec) or 0)
		local absValue = value < 0 and -value or value

		for i = 1, #values do
			local threshold, suffix = values[i][1], values[i][2]
			if absValue >= threshold then
				if decimal then
					return format(decimal, value / threshold) .. suffix
				end
				return format("%.0f", value / threshold) .. suffix
			end
		end

		return format("%.0f", value)
	end

	function E:RGBToHex(r, g, b, header, ending)
		r, g, b = ClampColor(r), ClampColor(g), ClampColor(b)
		return format("%s%02x%02x%02x%s", header or "|cff", r * 255, g * 255, b * 255, ending or "")
	end

	function E:CropRatio(width, height, mult, left, right, top, bottom, factor)
		if not mult then
			mult = 0.5
		end
		if not (left and right and top and bottom) then
			left, right, top, bottom = E.TexCoords[1], E.TexCoords[2], E.TexCoords[3], E.TexCoords[4]
		end

		local ratio = (width or 1) / (height or 1)
		if ratio > 1 then
			local split = 1 / ratio
			local range = factor and (right - left) or 1
			local trim = range * (1 - split) * mult
			top, bottom = top + trim, bottom - trim
		else
			local split = 1 - ratio
			local range = factor and (bottom - top) or 1
			local trim = range * split * mult
			left, right = left + trim, right - trim
		end

		return left, right, top, bottom
	end

	function E:TextureString(texture, data)
		return format("|T%s%s|t", texture, data or "")
	end

	-- Modules call this on every hover to colour a unit frame; the realm name
	-- is used as a string key only, so stripping the separators is enough.
	function E:ShortenRealm(realm)
		if type(realm) ~= "string" then
			return realm
		end
		return (gsub(realm, "[%s%-]", ""))
	end

	function E:EscapeString(str)
		if type(str) ~= "string" then
			return str
		end
		return (gsub(str, "([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1"))
	end

	function E:UnlocalizedClassName(className)
		if not className then
			return nil
		end
		local maleNames = _G.LOCALIZED_CLASS_NAMES_MALE
		local femaleNames = _G.LOCALIZED_CLASS_NAMES_FEMALE
		for classFile, localized in next, maleNames do
			if localized == className then
				return classFile
			end
		end
		for classFile, localized in next, femaleNames do
			if localized == className then
				return classFile
			end
		end
		return nil
	end

	-- Modules\Tooltips\UnitInfo.lua reads the second return value as the
	-- localized faction name. UnitFactionGroup already answers that; the
	-- battleground special cases upstream added do not change the name.
	function E:GetUnitBattlefieldFaction(unit)
		local faction, localized = UnitFactionGroup(unit)
		return faction, localized
	end

	-----------------------------------------------------------------------
	--  Unit auras
	--
	--  ElvUI returned the packed aura tuple. Modules only test for presence
	--  (and occasionally read name/spellID), so the aura table is enough and
	--  avoids depending on ElvUltimate's unpacking helper.
	-----------------------------------------------------------------------

	function E:GetAuraData(unit, index, filter)
		local data = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex and C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
		if not data then
			return nil
		end
		return data
	end

	local function FindAuraBy(key, value, unit, filter, index)
		local data = E:GetAuraData(unit, index, filter)
		if not data then
			return nil
		end

		local name, spellID = data.name, data.spellId
		if E:NotSecretValue(name) and E:NotSecretValue(spellID) then
			if key == "name" and name == value then
				return data
			elseif key == "spellID" and spellID == value then
				return data
			end
		end

		return FindAuraBy(key, value, unit, filter, index + 1)
	end

	-- C_UnitAuras answers the 12.0 secret value rules on both clients, so the
	-- lookup walks the aura list instead of calling the removed UnitAura.
	function E:GetAuraByID(unit, spellID, filter)
		return FindAuraBy("spellID", spellID, unit, filter, 1)
	end

	function E:GetAuraByName(unit, name, filter)
		return FindAuraBy("name", name, unit, filter, 1)
	end


	function E:GetMouseFocus()
		if GetMouseFoci then
			return GetMouseFoci()[1]
		end
		return _G.GetMouseFocus and _G.GetMouseFocus()
	end

	-- EllesmereUI tracks its own pixel scale; E:Scale is the ElvUI name for
	-- the same conversion, which several ported frames use to snap padding.
	function E:Scale(value)
		if EUI.PP and EUI.PP.Scale then
			return EUI.PP.Scale(value)
		end
		return value
	end

	-----------------------------------------------------------------------
	--  Animations and status bars
	-----------------------------------------------------------------------

	-- CreateAnimationGroup is a documented Blizzard API, so these three need
	-- no library: Flash builds the group once and replays it on demand.
	function E:Flash(obj, duration, loop)
		if not obj then
			return
		end

		if not obj.WTFlash then
			local group = obj:CreateAnimationGroup()
			local fadeOut = group:CreateAnimation("Alpha")
			fadeOut:SetFromAlpha(1)
			fadeOut:SetToAlpha(0.2)
			fadeOut:SetDuration(duration or 0.2)
			fadeOut:SetOrder(1)

			if loop then
				fadeOut:SetSmoothing("IN_OUT")
			end

			local fadeIn = group:CreateAnimation("Alpha")
			fadeIn:SetFromAlpha(0.2)
			fadeIn:SetToAlpha(1)
			fadeIn:SetDuration(duration or 0.2)
			fadeIn:SetOrder(2)

			if loop then
				group:SetLooping("BOUNCE")
			end

			obj.WTFlash = group
		end

		if not obj.WTFlash:IsPlaying() then
			obj.WTFlash:Play()
		end
	end

	function E:StopFlash(obj, stopAlpha)
		if obj and obj.WTFlash and obj.WTFlash:IsPlaying() then
			obj.WTFlash:Stop()
		end
		if obj and stopAlpha then
			obj:SetAlpha(stopAlpha)
		end
	end

	-- UIFrameFadeRemoveFrame is part of the fade library Blizzard ships in
	-- FrameXML, but not every client exposes it as a global.
	function E:UIFrameFadeRemoveFrame(frame)
		if UIFrameFadeRemoveFrame then
			return UIFrameFadeRemoveFrame(frame)
		end
		if frame then
			frame.fadeInfo = nil
		end
	end

	-- StatusBar smoothing is purely cosmetic: the smoothed bar eases between
	-- values, and the plain one snaps. Recording the bar and leaving it alone
	-- is enough for the modules that call this.
	function E:RegisterStatusBar(statusBar)
		if not statusBar then
			return
		end
		E.statusBars = E.statusBars or {}
		E.statusBars[statusBar] = true
	end

	function E:SetSmoothing(bar, enable)
		if not bar then
			return
		end
		E.smoothedBars = E.smoothedBars or {}
		E.smoothedBars[bar] = enable or nil
	end

	function E:SetSmoothingAmount()
		-- Kept as a no-op: the amount only feeds the easing above.
	end

	-----------------------------------------------------------------------
	--  Abbreviation
	-----------------------------------------------------------------------

	-- Modules\Misc\Math.lua hooks this method to install its own breakpoints,
	-- so it has to exist even when nothing calls it.
	function E:BuildAbbreviateConfigs()
		local style = E.db and E.db.general and E.db.general.numberPrefixStyle
		local values = E.ShortPrefixStyles and E.ShortPrefixStyles[style or "ENGLISH"]
		if not values then
			return
		end

		wipe(E.ShortPrefixValues)
		local decimal = format("%%.%df", (E.db and E.db.general and E.db.general.decimalLength) or 1)
		for i = 1, #values do
			local threshold, suffix = values[i][1], values[i][2]
			E.ShortPrefixValues[i] = { threshold, format(decimal, 1):gsub("^1", ""), decimal .. suffix }
		end
	end

	-----------------------------------------------------------------------
	--  Tooltip scanning
	-----------------------------------------------------------------------

	-- C_TooltipInfo answers the same data without a hidden tooltip on both
	-- clients, and it is the only path that survives the 12.0 secret values.
	function E:ScanTooltip_HyperlinkInfo(link)
		if C_TooltipInfo and C_TooltipInfo.GetHyperlink and E:NotSecretValue(link) then
			local data = C_TooltipInfo.GetHyperlink(link)
			if data then
				return data
			end
		end

		if not E.ScanTooltip then
			return nil
		end
		E.ScanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
		E.ScanTooltip:SetHyperlink(link)
		return E.ScanTooltip:GetTooltipData()
	end

	-----------------------------------------------------------------------
	--  Movers
	--
	--  Seven ported modules call E:CreateMover and every one of them throws
	--  the return value away: they only want the frame registered in the
	--  unlock overlay. EllesmereUI's Unlock Mode is that overlay, so the shim
	--  registers an element there and nothing else.
	-----------------------------------------------------------------------

	function E:CreateMover(parent, name, textString, _, _, _, _, shouldDisable, configString)
		if not parent or not name then
			return
		end
		if not EUI or not EUI.RegisterUnlockElements or not EUI.MakeUnlockElement then
			return
		end

		E.movers = E.movers or {}
		if E.movers[name] then
			return
		end
		E.movers[name] = true

		-- Upstream spelled the saved-variable path as "WindTools,combat,foo"
		-- because ElvUI kept it under E.global.WindTools. This port nests the
		-- same tree under E.global.WT, so the leading segment is rewritten
		-- instead of being looked up.
		local path
		if type(configString) == "string" then
			path = { strsplit(",", configString) }
			if path[1] == "WindTools" then
				path[1] = "WT"
			end
		end
		local function getPos()
			if not path then
				return nil
			end
			local node = E.global
			for i = 1, #path do
				node = node and node[path[i]]
				if not node then
					return nil
				end
			end
			return node.position
		end

		local elements = {
			EUI.MakeUnlockElement({
				key = name,
				label = textString or name,
				group = "WindTools",
				order = 900,
				getFrame = function()
					return parent
				end,
				getSize = function()
					if not parent.GetWidth then
						return 0, 0
					end
					return parent:GetWidth(), parent:GetHeight()
				end,
				savePos = function(_, point, relPoint, x, y)
					if not path or not point then
						return
					end
					local node = E.global
					for i = 1, #path - 1 do
						node[path[i]] = node[path[i]] or {}
						node = node[path[i]]
					end
					node[path[#path]] = node[path[#path]] or {}
					node[path[#path]].position = {
						point = point,
						relPoint = relPoint or point,
						x = x,
						y = y,
					}
				end,
				loadPos = function()
					local pos = getPos()
					if not pos then
						return nil
					end
					return {
						point = pos.point,
						relPoint = pos.relPoint or pos.point,
						x = pos.x,
						y = pos.y,
					}
				end,
				clearPos = function()
					if not path then
						return
					end
					local node = E.global
					for i = 1, #path do
						node = node and node[path[i]]
					end
					if node then
						node.position = nil
					end
				end,
				isHidden = function()
					if type(shouldDisable) == "function" then
						return not shouldDisable()
					end
					if type(shouldDisable) == "boolean" then
						return not shouldDisable
					end
					return false
				end,
			}),
		}

		EUI:RegisterUnlockElements(elements, "EllesmereUI_WindTools")
	end

	-----------------------------------------------------------------------
	--  Texture coordinates and frames
	--
	--  ElvUI keeps its icon crop in E.TexCoords and swaps the Blizzard
	--  backdrop coordinate builder out for a guarded one (the 12.0 secret
	--  rules make the stock version throw on protected frames).
	-----------------------------------------------------------------------

	function E:GetTexCoords()
		return self.TexCoords[1], self.TexCoords[2], self.TexCoords[3], self.TexCoords[4]
	end

	function E:SameTexCoords(left, right, top, bottom)
		local c = self.TexCoords
		return c[1] == left and c[2] == right and c[3] == top and c[4] == bottom
	end

	function E:ResetTexCoords(left, right, top, bottom)
		if self:SameTexCoords(left, right, top, bottom) then
			return
		end

		self:SetTexCoord(self.TexCoords[1], self.TexCoords[2], self.TexCoords[3], self.TexCoords[4])
	end

	function E:NotSecretTable(value)
		if type(value) ~= "table" then
			return self:NotSecretValue(value)
		end

		for key, entry in next, value do
			if not self:NotSecretValue(key) or not self:NotSecretValue(entry) then
				return false
			end
		end

		return true
	end

	function E:NotSizeRestricted(frame)
		if not frame or not frame.GetSize then
			return true
		end

		local width, height = frame:GetSize()
		return self:NotSecretValue(width) and self:NotSecretValue(height)
	end

	-- The stock backdrop coordinate builder reads frame:GetSize() and throws
	-- once the size is a secret value, which happens on protected frames in
	-- 12.0. This is ElvUI's guard, reused here because the ported modules
	-- call SetTemplate on protected frames.
	function E:SetupTextureCoordinates()
		if self:NotSizeRestricted() and _G.BackdropTemplateMixin then
			_G.BackdropTemplateMixin.SetupTextureCoordinates(self)
		end
	end

	function E:ReplaceSetupTextureCoordinates(frame)
		if frame and frame.SetupTextureCoordinates ~= self.SetupTextureCoordinates then
			frame.SetupTextureCoordinates = self.SetupTextureCoordinates
		end
	end

	function E:SetFontShadow(font, style, shadow, sR, sG, sB, sA, sX, sY)
		if not font or not font.SetShadowColor then
			return
		end

		local alpha = sA or (shadow and ((style == "" and 1) or 0.6)) or 0
		font:SetShadowColor(sR or 0, sG or 0, sB or 0, alpha)
		font:SetShadowOffset(sX or (shadow and 1) or 0, sY or (shadow and -1) or 0)
	end

	function E:GetFrameName(frame, fallback, allowDebug)
		if allowDebug and frame.GetDebugName then
			return frame:GetDebugName()
		end

		if frame.GetName then
			return frame:GetName() or fallback
		end

		return fallback
	end


	-----------------------------------------------------------------------
	--  ElvUI frame API
	-----------------------------------------------------------------------
	-- The ported modules were written against ElvUI's frame metatable
	-- extensions: they call frame:Size(), frame:Point(), frame:SetTemplate()
	-- and about twenty more methods that Blizzard frames do not have. There
	-- are more than four hundred such call sites, so rewriting them is not
	-- worth it -- the methods themselves are installed here instead. A name
	-- is only added when the object type does not already define it, so
	-- nothing Blizzard or another addon provides is ever replaced.
	--
	-- Installation is deferred to PLAYER_LOGIN (E:InstallFrameAPI): the
	-- per-type pass needs the Blizzard frames to exist, and it has to run
	-- before W:InitializeModules so module code can already call the API.

	E.HiddenFrame = CreateFrame("Frame")
	E.HiddenFrame:Hide()
	E.frames = E.frames or {}
	E.unitFrameElements = E.unitFrameElements or {}
	E.texts = E.texts or {}
	E.statusBars = E.statusBars or {}

	-- Colour tables the ported skinning code unpacks. Both the named and the
	-- indexed keys are filled in because call sites do both: some read
	-- color.r, others unpack the table.
	local function NewColorTable(r, g, b, a)
		return { r = r, g = g, b = b, a = a, r, g, b, a }
	end

	E.media.bordercolor = NewColorTable(0, 0, 0, 1)
	E.media.backdropcolor = NewColorTable(0.1, 0.1, 0.1, 1)
	E.media.backdropfadecolor = NewColorTable(0.13, 0.13, 0.13, 0.69)
	E.media.unitframeBorderColor = NewColorTable(0, 0, 0, 1)

	local function DisablePixelSnap(frame)
		if frame.SetSnapToPixelGrid then
			frame:SetSnapToPixelGrid(false)
			frame:SetTexelSnappingBias(0)
		end

		if frame.SetTexelSnappingBias then
			frame:SetTexelSnappingBias(0)
		end

		if frame.GetStatusBarTexture then
			local texture = frame:GetStatusBarTexture()
			if texture then
				DisablePixelSnap(texture)
			end
		end

		frame.PixelSnapDisabled = true
	end

	local function WatchPixelSnap(frame, snap)
		if frame.PixelSnapDisabled and snap then
			frame.PixelSnapDisabled = nil
		end
	end

	local function BackdropFrameLevel(frame, level)
		frame:SetFrameLevel(level)

		if frame.oborder then
			frame.oborder:SetFrameLevel(level)
		end

		if frame.iborder then
			frame.iborder:SetFrameLevel(level)
		end
	end

	local function BackdropFrameLower(backdrop, parent)
		local level = parent:GetFrameLevel()
		local minus = level and (level - 1)

		if minus and minus >= 0 then
			BackdropFrameLevel(backdrop, minus)
		else
			BackdropFrameLevel(backdrop, 0)
		end
	end

	-- Per-template border and backdrop colours. EllesmereUI has no colour
	-- settings page, so the four tables above are the only source.
	local function GetTemplate(template, isUnitFrameElement)
		local border = isUnitFrameElement and E.media.unitframeBorderColor or E.media.bordercolor
		local backdropr, backdropg, backdropb, backdropa

		if template == "ClassColor" then
			local color = E.myClassColor
			backdropr, backdropg, backdropb = E.media.backdropcolor.r, E.media.backdropcolor.g, E.media.backdropcolor.b
			return color.r, color.g, color.b, 1, backdropr, backdropg, backdropb, 1
		elseif template == "Transparent" then
			backdropr = E.media.backdropfadecolor.r
			backdropg = E.media.backdropfadecolor.g
			backdropb = E.media.backdropfadecolor.b
			backdropa = E.media.backdropfadecolor.a
		else
			backdropr = E.media.backdropcolor.r
			backdropg = E.media.backdropcolor.g
			backdropb = E.media.backdropcolor.b
			backdropa = 1
		end

		return border.r, border.g, border.b, 1, backdropr, backdropg, backdropb, backdropa
	end

	local function Size(frame, width, height, ...)
		local w = E:Scale(width)
		frame:SetSize(w, (height and E:Scale(height)) or w, ...)
	end

	local function Width(frame, width, ...)
		frame:SetWidth(E:Scale(width), ...)
	end

	local function Height(frame, height, ...)
		frame:SetHeight(E:Scale(height), ...)
	end

	local function OffsetFrameLevel(frame, offset, secondary)
		local level = (secondary or frame):GetFrameLevel()
		frame:SetFrameLevel(level + (offset or 0))
	end

	local function Point(obj, arg1, arg2, arg3, arg4, arg5, ...)
		if not arg2 then
			arg2 = obj:GetParent()
		end

		if type(arg2) == "number" then
			arg2 = E:Scale(arg2)
		end
		if type(arg3) == "number" then
			arg3 = E:Scale(arg3)
		end
		if type(arg4) == "number" then
			arg4 = E:Scale(arg4)
		end
		if type(arg5) == "number" then
			arg5 = E:Scale(arg5)
		end

		obj:SetPoint(arg1, arg2, arg3, arg4, arg5, ...)
	end

	local function GrabPoint(obj, pointValue)
		if type(pointValue) == "string" then
			local pointIndex = tonumber(pointValue)

			if not pointIndex then
				for i = 1, obj:GetNumPoints() do
					local point, relativeTo, relativePoint, xOfs, yOfs = obj:GetPoint(i)
					if not point then
						break
					elseif point == pointValue then
						return point, relativeTo, relativePoint, xOfs, yOfs
					end
				end
			end

			pointValue = pointIndex
		end

		return obj:GetPoint(pointValue)
	end

	local function NudgePoint(obj, xAxis, yAxis, noScale, pointValue, clearPoints)
		xAxis = xAxis or 0
		yAxis = yAxis or 0

		local x = (noScale and xAxis) or E:Scale(xAxis)
		local y = (noScale and yAxis) or E:Scale(yAxis)
		local point, relativeTo, relativePoint, xOfs, yOfs = GrabPoint(obj, pointValue)

		if clearPoints or obj:IsAnchoringRestricted() then
			obj:ClearAllPoints()
		end

		obj:SetPoint(point, relativeTo, relativePoint, xOfs + x, yOfs + y)
	end

	local function PointXY(obj, xOffset, yOffset, noScale, pointValue, clearPoints)
		local x = xOffset and ((noScale and xOffset) or E:Scale(xOffset))
		local y = yOffset and ((noScale and yOffset) or E:Scale(yOffset))
		local point, relativeTo, relativePoint, xOfs, yOfs = GrabPoint(obj, pointValue)

		if clearPoints or obj:IsAnchoringRestricted() then
			obj:ClearAllPoints()
		end

		obj:SetPoint(point, relativeTo, relativePoint, x or xOfs, y or yOfs)
	end

	local function SetOutside(obj, anchor, xOffset, yOffset, anchor2, noScale)
		anchor = anchor or obj:GetParent()
		xOffset = xOffset or E.Border
		yOffset = yOffset or E.Border

		local x = (noScale and xOffset) or E:Scale(xOffset)
		local y = (noScale and yOffset) or E:Scale(yOffset)

		if obj:IsAnchoringRestricted() or obj:GetPoint() then
			obj:ClearAllPoints()
		end

		DisablePixelSnap(obj)
		obj:SetPoint("TOPLEFT", anchor, "TOPLEFT", -x, y)
		obj:SetPoint("BOTTOMRIGHT", anchor2 or anchor, "BOTTOMRIGHT", x, -y)
	end

	local function SetInside(obj, anchor, xOffset, yOffset, anchor2, noScale)
		anchor = anchor or obj:GetParent()
		xOffset = xOffset or E.Border
		yOffset = yOffset or E.Border

		local x = (noScale and xOffset) or E:Scale(xOffset)
		local y = (noScale and yOffset) or E:Scale(yOffset)

		if obj:IsAnchoringRestricted() or obj:GetPoint() then
			obj:ClearAllPoints()
		end

		DisablePixelSnap(obj)
		obj:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, -y)
		obj:SetPoint("BOTTOMRIGHT", anchor2 or anchor, "BOTTOMRIGHT", -x, y)
	end

	local function SetTemplate(frame, template, glossTex, ignoreUpdates, forcePixelMode, isUnitFrameElement, isNamePlateElement, noScale)
		local borderr, borderg, borderb, bordera, backdropr, backdropg, backdropb, backdropa =
			GetTemplate(template, isUnitFrameElement)

		frame.template = template or "Default"
		frame.glossTex = glossTex
		frame.ignoreUpdates = ignoreUpdates
		frame.forcePixelMode = forcePixelMode
		frame.isUnitFrameElement = isUnitFrameElement
		frame.isNamePlateElement = isNamePlateElement

		if not frame.SetBackdrop and _G.BackdropTemplateMixin then
			_G.Mixin(frame, _G.BackdropTemplateMixin)

			if frame.OnSizeChanged then
				frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
			end
		end

		E:ReplaceSetupTextureCoordinates(frame)

		if not frame.SetBackdrop then
			return
		end

		if template == "NoBackdrop" then
			frame:SetBackdrop(nil)
		else
			local edgeSize = E.twoPixelsPlease and 2 or 1

			frame:SetBackdrop({
				edgeFile = E.media.blankTex,
				bgFile = glossTex and (type(glossTex) == "string" and glossTex or E.media.glossTex) or E.media.blankTex,
				edgeSize = noScale and edgeSize or E:Scale(edgeSize),
			})

			if frame.callbackBackdropColor then
				frame:callbackBackdropColor()
			else
				frame:SetBackdropColor(backdropr, backdropg, backdropb, frame.customBackdropAlpha or backdropa or 1)
			end

			-- Non pixel-perfect clients need the extra inner and outer border
			-- frames; EllesmereUI only ever runs in pixel mode, so this branch
			-- stays off and the single 1px edge above is the whole border.
			if not E.PixelMode and not forcePixelMode then
				local backdrop = { edgeFile = E.media.blankTex, edgeSize = noScale and 1 or E:Scale(1) }
				local level = frame:GetFrameLevel()

				if not frame.iborder then
					local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
					E:ReplaceSetupTextureCoordinates(border)
					border:SetBackdrop(backdrop)
					border:SetBackdropBorderColor(0, 0, 0, 1)
					border:SetFrameLevel(level)
					border:SetInside(frame, 1, 1, nil, noScale)
					frame.iborder = border
				end

				if not frame.oborder then
					local border = CreateFrame("Frame", nil, frame, "BackdropTemplate")
					E:ReplaceSetupTextureCoordinates(border)
					border:SetBackdrop(backdrop)
					border:SetBackdropBorderColor(0, 0, 0, 1)
					border:SetFrameLevel(level)
					border:SetOutside(frame, 1, 1, nil, noScale)
					frame.oborder = border
				end
			end
		end

		if frame.forcedBorderColors then
			borderr, borderg, borderb, bordera = unpack(frame.forcedBorderColors)
		end

		frame:SetBackdropBorderColor(borderr, borderg, borderb, bordera)

		if not frame.ignoreUpdates then
			if frame.isUnitFrameElement then
				E.unitFrameElements[frame] = true
			else
				E.frames[frame] = true
			end
		end
	end

	local function CreateBackdrop(frame, template, glossTex, ignoreUpdates, forcePixelMode, isUnitFrameElement, isNamePlateElement, noScale, allPoints, frameLevel)
		local parent = (frame.IsObjectType and frame:IsObjectType("Texture") and frame:GetParent()) or frame
		local backdrop = frame.backdrop or CreateFrame("Frame", nil, parent)

		if not frame.backdrop then
			frame.backdrop = backdrop
		end

		backdrop:SetTemplate(template, glossTex, ignoreUpdates, forcePixelMode, isUnitFrameElement, isNamePlateElement, noScale)

		if allPoints then
			if allPoints == true then
				backdrop:SetAllPoints()
			else
				backdrop:SetAllPoints(allPoints)
			end
		elseif forcePixelMode then
			local border = E.twoPixelsPlease and 2 or 1
			backdrop:SetOutside(frame, border, border, nil, noScale)
		else
			local border = (isUnitFrameElement and E.Border) or (isNamePlateElement and E.Border) or E.Border
			backdrop:SetOutside(frame, border, border, nil, noScale)
		end

		if frameLevel then
			if frameLevel == true then
				BackdropFrameLevel(backdrop, parent:GetFrameLevel())
			else
				BackdropFrameLevel(backdrop, frameLevel)
			end
		else
			BackdropFrameLower(backdrop, parent)
		end
	end

	local function CreateShadow(frame, size, pass)
		if not pass and frame.shadow then
			return
		end

		size = size or 3

		local glow = E.Media.Textures.GlowTex or E.media.blankTex
		local offset = E.PixelMode and size or (size + 1)
		local shadow = CreateFrame("Frame", nil, frame, "BackdropTemplate")

		E:ReplaceSetupTextureCoordinates(shadow)
		shadow:SetFrameLevel(1)
		shadow:SetOutside(frame, offset, offset, nil, true)
		shadow:SetBackdrop({ edgeFile = glow, edgeSize = size })
		shadow:SetBackdropColor(0, 0, 0, 0)
		shadow:SetBackdropBorderColor(0, 0, 0, 0.9)

		local strata = frame:GetFrameStrata()
		if strata and E:NotSecretValue(strata) then
			shadow:SetFrameStrata(strata)
		end

		if pass then
			return shadow
		end

		frame.shadow = shadow
	end

	local function Kill(object)
		if object.UnregisterAllEvents then
			object:UnregisterAllEvents()
			object:SetParent(E.HiddenFrame)
		else
			object.Show = object.Hide
		end

		object:Hide()
	end

	local STRIP_TEX = "Texture"
	local STRIP_FONT = "FontString"

	local function StripRegion(which, object, kill, zero)
		if kill then
			object:Kill()
		elseif zero then
			object:SetAlpha(0)
		elseif which == STRIP_TEX then
			object:SetTexture(nil)
			object:SetAtlas("")
		elseif which == STRIP_FONT then
			object:SetText("")
		end
	end

	-- Blizzard frames keep their decoration in these named sub-frames; ElvUI
	-- strips them by name before skinning.
	local STRIP_NAMES = {
		"Inset", "inset", "InsetFrame", "LeftInset", "RightInset", "NineSlice", "BG", "Bg",
		"border", "Border", "Background", "BorderFrame", "bottomInset", "BottomInset",
		"bgLeft", "bgRight", "FilligreeOverlay", "PortraitOverlay", "ArtOverlayFrame",
		"Portrait", "portrait", "ScrollFrameBorder", "ScrollUpBorder", "ScrollDownBorder",
	}

	local function StripType(which, object, kill, zero)
		if object:IsObjectType(which) then
			StripRegion(which, object, kill, zero)
			return
		end

		if which == STRIP_TEX then
			local frameName = object.GetName and object:GetName()

			for i = 1, #STRIP_NAMES do
				local key = STRIP_NAMES[i]
				local blizz = object[key] or (frameName and _G[frameName .. key])

				if blizz and blizz.StripTextures then
					blizz:StripTextures(kill, zero)
				end
			end
		end

		if object.GetNumRegions then
			for _, region in next, { object:GetRegions() } do
				if region and region.IsObjectType and region:IsObjectType(which) then
					StripRegion(which, region, kill, zero)
				end
			end
		end
	end

	local function StripTextures(object, kill, zero)
		StripType(STRIP_TEX, object, kill, zero)
	end

	local function StripTexts(object, kill, zero)
		StripType(STRIP_FONT, object, kill, zero)
	end

	local function FontTemplate(fs, fontName, fontSize, fontStyle, skip)
		fontStyle = fontStyle or E.db.general.fontOutline or ""
		fontSize = fontSize or E.db.general.fontSize or 12

		if fontStyle == "NONE" then
			fontStyle = ""
		end

		if not skip then
			E.texts[fs] = { fontName, fontSize, fontStyle }
		end

		if fs.CanBeAccessedInContext and not fs:CanBeAccessedInContext() then
			return
		end

		if fs.SetScaleAnimationMode and _G.FontStringScaleAnimationMode then
			fs:SetScaleAnimationMode(_G.FontStringScaleAnimationMode.Vertex)
		end

		local font
		if fontName and E.Libs.LSM then
			font = E.Libs.LSM:Fetch("font", fontName)
		end

		fs:SetFont(font or E.media.normFont, fontSize, fontStyle)
		E:SetFontShadow(fs, fontStyle, string.find(fontStyle, "SHADOW") ~= nil)
	end

	local function StyleButton(button, noHover, noPushed, noChecked)
		if not noHover then
			button:SetHighlightTexture(E.media.blankTex)
			local hover = button:GetHighlightTexture()
			if hover then
				hover:SetInside()
				hover:SetBlendMode("ADD")
				hover:SetColorTexture(1, 1, 1, 0.1)
				button.hover = hover
			end
		end

		if not noPushed then
			button:SetPushedTexture(E.media.blankTex)
			local pushed = button:GetPushedTexture()
			if pushed then
				pushed:SetInside()
				pushed:SetBlendMode("ADD")
				pushed:SetColorTexture(1, 1, 1, 0.16)
				button.pushed = pushed
			end
		end

		if not noChecked then
			button:SetCheckedTexture(E.media.blankTex)
			local checked = button:GetCheckedTexture()
			if checked then
				checked:SetInside()
				checked:SetBlendMode("ADD")
				checked:SetColorTexture(1, 1, 1, 0.2)
				button.checked = checked
			end
		end
	end

	local function CreateCloseButton(frame, size, offset, texture, backdrop)
		size = size or 16
		offset = offset or -6

		local button = CreateFrame("Button", nil, frame)
		button:Size(size, size)
		button:Point("TOPRIGHT", offset, offset)

		if backdrop then
			button:CreateBackdrop(nil, true)
		end

		local tex = button:CreateTexture(nil, "OVERLAY")
		tex:SetAllPoints()
		tex:SetTexture(texture or E.Media.Textures.Close)

		button:SetScript("OnClick", function()
			frame:Hide()
		end)

		return button
	end

	local function SetTexCoords(frame)
		frame:SetTexCoord(unpack(E.TexCoords))
	end

	local function GetChild(frame, child, index, allowDebug)
		local name = frame and child and E:GetFrameName(frame, nil, allowDebug)

		if not name then
			return nil
		end

		if not index then
			index = ""
		end

		local main = _G[name]
		local sub = main and main[child .. index]

		if sub then
			return sub
		end

		return _G[name .. child .. index]
	end

	local API = {
		Kill = Kill,
		Size = Size,
		Point = Point,
		Width = Width,
		Height = Height,
		PointXY = PointXY,
		GrabPoint = GrabPoint,
		NudgePoint = NudgePoint,
		SetOutside = SetOutside,
		SetInside = SetInside,
		SetTemplate = SetTemplate,
		CreateBackdrop = CreateBackdrop,
		CreateShadow = CreateShadow,
		FontTemplate = FontTemplate,
		StripTextures = StripTextures,
		StripTexts = StripTexts,
		StyleButton = StyleButton,
		OffsetFrameLevel = OffsetFrameLevel,
		CreateCloseButton = CreateCloseButton,
		SetTexCoords = SetTexCoords,
		GetChild = GetChild,
	}

	local function AddAPI(object)
		local mt = getmetatable(object)
		local mk = mt and mt.__index

		if not mk then
			return
		end

		for method, func in next, API do
			if not object[method] then
				mk[method] = func
			end
		end

		if mk.DisabledPixelSnap then
			return
		end

		for _, name in next, { "SetSnapToPixelGrid", "SetStatusBarTexture", "SetColorTexture", "SetVertexColor", "CreateTexture", "SetTexCoord", "SetTexture" } do
			if mk[name] then
				hooksecurefunc(mk, name, name == "SetSnapToPixelGrid" and WatchPixelSnap or DisablePixelSnap)
			end
		end

		mk.DisabledPixelSnap = true
	end

	-- Installs the API on every object type that exists right now. Runs at
	-- PLAYER_LOGIN, once, so later frames of those types inherit it.
	function E:InstallFrameAPI()
		if self.frameAPIInstalled then
			return
		end

		self.frameAPIInstalled = true

		local probe = CreateFrame("Frame")

		AddAPI(probe)
		AddAPI(probe:CreateTexture())
		AddAPI(probe:CreateFontString())

		local mask = probe:CreateMaskTexture()
		if mask then
			AddAPI(mask)
		end

		local handled = { Frame = true, Texture = true, FontString = true, MaskTexture = true }
		local object = _G.EnumerateFrames and _G.EnumerateFrames()

		while object do
			local kind = object:GetObjectType()

			if kind and not handled[kind] and not object:IsForbidden() then
				AddAPI(object)
				handled[kind] = true
			end

			object = _G.EnumerateFrames(object)
		end
	end
	return E
end

addon.CreateCompatE = CreateCompatE
