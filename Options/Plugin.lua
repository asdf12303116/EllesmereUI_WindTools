local addon = select(2, ...)
local W = addon[1]

local _G = _G

local debug = debug
local error = error
local ipairs = ipairs
local pairs = pairs
local strlower = strlower
local type = type
local wipe = wipe
local xpcall = xpcall

local math_abs = math.abs

-- The settings pages are handed to EllesmereUI's own options panel instead of
-- being drawn here. EUI owns the window, the sidebar and the scrolling, so this
-- file only describes the shape of the pages and forwards each one to the
-- builder registered under its category.
local PLUGIN_ID = "EllesmereUI_WindTools"

-- Grouping follows the seven blocks the pages were always split into, because
-- RegisterPlugin allows 20 modules and 20 pages per module while the pages
-- themselves number 27: one module per page would exceed the limit.
--
-- The order inside pages is the reading order a user follows while setting the
-- addon up, not the load order of the option files.
local MODULES = {
	{
		key = "General",
		title = "General",
		description = "Addon wide behaviour, the game bar, and information pages.",
		pages = { "General", "Game Bar", "Information", "Advanced" },
	},
	{
		key = "Items",
		title = "Items",
		description = "Looting, trading, and the item tooltips shown in bags and merchants.",
		pages = { "Loot & Trade", "Display", "Inspect", "Item Level", "Merchant", "Extra Items Bar" },
	},
	{
		key = "Combat",
		title = "Combat",
		description = "Raid markers, combat alerts, and the damage meter layout.",
		pages = { "Combat" },
	},
	{
		key = "Social",
		title = "Social",
		description = "Chat bar, chat tab behaviour, and announcements.",
		pages = { "Chat Bar", "Smart Tab", "Announcement" },
	},
	{
		key = "Maps",
		title = "Maps",
		description = "Super tracker, minimap, world map, and difficulty displays.",
		pages = { "Super Tracker", "Minimap", "World Map", "Difficulty & Events" },
	},
	{
		key = "Quest",
		title = "Quest",
		description = "Objective tracker, quest automation, and achievement helpers.",
		pages = { "Objective Tracker", "Automation", "Progress & Turn In", "Achievement" },
	},
	{
		-- No space in the key: it has to match ^%a[%w_%-]*$. The title carries
		-- the readable form.
		key = "UITweaks",
		title = "UI Tweaks",
		description = "Tooltips, progression text, keystone info, and unit frames.",
		pages = { "Tooltip Info", "Progression", "Keystone & Group Info", "Tooltip Advanced", "Unit Frames" },
	},
}

-- pageName -> module key, so /wt <page> and the Blizzard settings button can
-- open the right tab without the caller knowing the grouping.
local MODULE_BY_PAGE = {}
for _, module in ipairs(MODULES) do
	for _, pageName in ipairs(module.pages) do
		MODULE_BY_PAGE[pageName] = module.key
	end
end

addon.OptionsPluginID = PLUGIN_ID
addon.OptionsPluginModuleByPage = MODULE_BY_PAGE

-- One builder instance per page, so a page keeps its widget refresh closures
-- across rebuilds the way EUI's own modules do.
--
-- Content headers (the extra items bar selector and its preview) are declared
-- from inside a page builder, because that is where the builder knows it wants
-- one. EllesmereUI's own modules do the same, calling SetContentHeader mid
-- build, so this file only redirects that one call: during a plugin build it
-- goes to the EllesmereUI panel, which owns the header frame in this mode.
--
-- headerForPage is what a jump straight to a page needs: EUI asks for a header
-- before building (EllesmereUI_Panel.lua:3749-3755) and then hands the builder
-- to SetContentHeader without saying which page it came from, so the page is
-- recovered by looking the builder up here.
local headerForPage = {}
local buildingPageName
local lastBuiltPage
local routingInstalled

local function InstallContentHeaderRouting()
	-- A boolean, not a marker field: addon.SetContentHeader is a function value,
	-- and Lua refuses to index one, so the usual "stamp the wrapper" trick would
	-- raise instead of guard.
	if routingInstalled then return end
	routingInstalled = true

	local previous = addon.SetContentHeader

	-- Which page does this header belong to? A build answers it directly. A
	-- redraw from a header's own control is answered by the builder's identity,
	-- because the only builders that exist are the ones parked here. The last
	-- built page covers the one remaining shape: EUI re-applying a header it
	-- cached for the page still on screen.
	local function TargetPage(builder)
		if buildingPageName then return buildingPageName end

		for pageName, parked in pairs(headerForPage) do
			if parked == builder then return pageName end
		end

		local EUI = _G.EllesmereUI
		if lastBuiltPage and EUI and EUI.IsShown and EUI:IsShown() then
			return lastBuiltPage
		end
		return nil
	end

	addon.SetContentHeader = function(builder)
		local pageName = TargetPage(builder)
		if not pageName then
			-- Nothing identifies a page, so let the header land on whatever page
			-- EllesmereUI currently shows.
			if previous then return previous(builder) end
			return
		end

		headerForPage[pageName] = builder

		local EUI = _G.EllesmereUI
		if EUI and EUI.SetContentHeader then
			return EUI:SetContentHeader(builder)
		end
	end

	-- The builder stays parked. Invalidating drops EllesmereUI's rendered header,
	-- not the knowledge of which page wants one: the getter is asked for that
	-- builder again straight after an invalidate (ExtraItemBar's setter does
	-- exactly that), so clearing it here would lose the header for good.
	local previousInvalidate = addon.InvalidateContentHeaderCache
	if previousInvalidate then
		addon.InvalidateContentHeaderCache = function()
			local EUI = _G.EllesmereUI
			if EUI and EUI.InvalidateContentHeaderCache then
				EUI:InvalidateContentHeaderCache()
			end
			return previousInvalidate()
		end
	end
end

local function BuildPage(pageName, parent, yOffset)
	InstallContentHeaderRouting()
	if not addon.BuildOptionsPage then return math_abs(yOffset or 0) + 30 end

	-- Scoped to this call and restored afterwards: a header belongs to the page
	-- being built, so a failure must not leave the name pointing at a finished
	-- page. The error is rethrown for EUI's own guard to report, which keeps one
	-- error path instead of two.
	local previousPage = buildingPageName
	buildingPageName = pageName
	local ok, height = xpcall(addon.BuildOptionsPage, debug.traceback, pageName, parent, yOffset)
	buildingPageName = previousPage

	if not ok then error(height, 0) end
	lastBuiltPage = pageName
	return height
end

local function GetHeaderBuilder(pageName)
	InstallContentHeaderRouting()
	return headerForPage[pageName]
end

-- Resetting one module must not touch the others, so each module lists the
-- slices of the three databases it owns. The standalone panel that used to reset
-- the whole profile is gone; EllesmereUI's footer button resets the module being
-- viewed, which is the narrower granularity the plugin API offers.
local RESET_SLICES = {
	General = { { "profile", "misc" }, { "global", "core" }, { "global", "developer" } },
	Items = { { "profile", "item" }, { "private", "item" }, { "global", "item" } },
	Combat = { { "profile", "combat" }, { "private", "combat" } },
	-- announcement sits in its own profile key but every page it feeds lives in
	-- this module, so a Social reset that skipped it would leave those pages
	-- configured differently from the rest of the module.
	Social = {
		{ "profile", "social" }, { "private", "social" }, { "global", "social" },
		{ "profile", "announcement" },
	},
	Maps = { { "profile", "maps" }, { "private", "maps" }, { "global", "maps" } },
	Quest = { { "profile", "quest" }, { "private", "quest" } },
	UITweaks = {
		{ "profile", "tooltips" }, { "private", "tooltips" },
		{ "profile", "unitFrames" }, { "private", "unitFrames" },
		{ "profile", "skins" },
	},
}

local function LiveRoot(name)
	local E = addon[3]
	if name == "profile" then return E and E.db and E.db.WT end
	if name == "private" then return E and E.private and E.private.WT end
	if name == "global" then return E and E.global and E.global.WT end
end

local function DefaultRoot(name)
	if name == "profile" then return addon[6] end
	if name == "private" then return addon[5] end
	if name == "global" then return addon[7] end
end

-- Wipe and re-merge rather than copying defaults over the live table: a slice
-- that gained keys since the defaults were written would otherwise keep them.
local function ResetModule(moduleKey)
	local slices = RESET_SLICES[moduleKey]
	if not slices then return end

	local DeepMergeDefaults = _G.EllesmereUI
		and _G.EllesmereUI.Lite
		and _G.EllesmereUI.Lite.DeepMergeDefaults
	if not DeepMergeDefaults then return end

	for _, slice in ipairs(slices) do
		local root, key = slice[1], slice[2]
		local live = LiveRoot(root)
		local defaults = DefaultRoot(root)
		if type(live) == "table" and type(defaults) == "table" then
			wipe(live[key])
			if type(defaults[key]) == "table" then
				DeepMergeDefaults(live[key], defaults[key])
			end
		end
	end

	-- The page rebuild that follows reads the freshly reset values, but the
	-- modules behind them keep their old state until told to re-read.
	if W and W.UpdateModules then
		W:UpdateModules()
	end
end

-- Builds the module specs handed to RegisterPlugin. searchPrebuild is off for
-- every page: a few builders create frames of their own (the extra items bar
-- preview, the game bar icon preview), and the hidden pre-build pass would run
-- them against a stub widget factory before the user ever opened the page.
-- Search still indexes a page once it has been opened for real.
local function BuildSpec()
	local modules = {}
	-- RegisterPlugin has no field for a plugin version, and the description is
	-- the only line it redraws on every module switch, so the version rides
	-- along with it. Only a development build names itself here.
	local version = addon.GetDevelopmentVersion and addon.GetDevelopmentVersion()
	local suffix = version and (" (dev " .. version .. ")") or nil
	for index, module in ipairs(MODULES) do
		modules[index] = {
			key = module.key,
			title = module.title,
			description = suffix and (module.description .. suffix) or module.description,
			pages = module.pages,
			buildPage = BuildPage,
			-- Only the extra items bar page pins a header today, but the getter
			-- is registered for every module: EUI calls it per page, and the
			-- lookup is empty for pages that never asked for one.
			getHeaderBuilder = GetHeaderBuilder,
			searchPrebuild = false,
		}
		-- Only modules with a sensible slice of their own get the footer Reset
		-- button; EUI hides it when onReset is absent.
		modules[index].onReset = function() ResetModule(module.key) end
	end

	return {
		label = "WindTools",
		position = "bottom",
		modules = modules,
	}
end

--- Registers the settings pages with EllesmereUI's panel. Safe to call more
--- than once: the second call is a no-op once the plugin is registered.
--- @return boolean registered
function addon.RegisterOptionsPlugin()
	local EUI = _G.EllesmereUI
	if not EUI or not EUI.RegisterPlugin then
		addon.Print("EllesmereUI plugin API is missing; no settings pages are available.")
		return false
	end

	if EUI.IsPluginRegistered and EUI.IsPluginRegistered(PLUGIN_ID) then
		return true
	end

	local ok = EUI.RegisterPlugin(PLUGIN_ID, BuildSpec())
	if not ok then
		-- RegisterPlugin reports the reason itself; there is no second window to
		-- fall back to, so the failure has to surface here instead.
		addon.Print("could not register the settings pages with EllesmereUI.")
		return false
	end

	return true
end

--- Resolves a page name, module key, or EUI style comma path to a page.
--- @param path string|nil
--- @return string|nil pageName, string|nil moduleKey
function addon.ResolveOptionsPage(path)
	if not path or path == "" then return nil end

	-- "WindTools,information,changelog": the second field names the page, the
	-- rest is kept for callers that used the ElvUI style path.
	local _, pagePart = path:match("([^,]+),([^,]+)")
	local candidate = strlower(pagePart or path)

	-- Page names are unique and win over module keys, because two of the keys
	-- ("General", "Combat") are also page names and the page is the narrower
	-- request. Declaration order keeps a partial match stable.
	for _, module in ipairs(MODULES) do
		for _, pageName in ipairs(module.pages) do
			if strlower(pageName) == candidate then
				return pageName, module.key
			end
		end
	end

	-- A module key opens that module on its first page.
	for _, module in ipairs(MODULES) do
		if strlower(module.key) == candidate then
			return module.pages[1], module.key
		end
	end

	-- Partial match, so "/wt game" and "tooltip" land somewhere sensible.
	for _, module in ipairs(MODULES) do
		for _, pageName in ipairs(module.pages) do
			if strlower(pageName):find(candidate, 1, true) then
				return pageName, module.key
			end
		end
	end

	return nil, nil
end

--- Opens the WindTools pages inside the EllesmereUI panel.
--- @param path string|nil Page name, module key, or comma path.
--- @return boolean handled  true when the plugin owns the settings UI, even if
---   the panel refused to open (combat); callers must not fall back then.
function addon.OpenOptionsPlugin(path)
	local EUI = _G.EllesmereUI
	if not EUI or not EUI.OpenPlugin then return false end

	if not addon.RegisterOptionsPlugin() then
		return false
	end

	local pageName, moduleKey = addon.ResolveOptionsPage(path)
	EUI.OpenPlugin(PLUGIN_ID, moduleKey, pageName)

	-- RegisterPlugin already reports its own refusals, and OpenPlugin prints a
	-- note when combat blocks it, so a false return needs no second window.
	return true
end

--- Rebuilds the page currently shown, if it belongs to this plugin.
--- @param force boolean|nil
function addon.RefreshOptionsPlugin(force)
	local EUI = _G.EllesmereUI
	if not EUI or not EUI.RefreshPage then return end
	EUI:RefreshPage(force)
end

--- Resizes the content header without rebuilding it. The extra items bar
--- preview changes height as bars are added or removed and tells the panel so;
--- EllesmereUI's silent setter does the same job the panel's own helper did.
--- @param height number
function addon.UpdateContentHeaderHeight(height)
	local EUI = _G.EllesmereUI
	if not EUI or not EUI.SetContentHeaderHeightSilent then return end
	EUI:SetContentHeaderHeightSilent(height)
end

-- Option builders call this to redraw after a setter. It is the only
-- implementation now that the standalone panel is gone.
addon.RefreshOptions = function(force) addon.RefreshOptionsPlugin(force) end

-- Exposed for the command layer and for tests that walk the page list.
addon.OptionsPluginModules = MODULES

W.OptionsPluginID = PLUGIN_ID
