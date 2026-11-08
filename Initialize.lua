local addonName, addon = ...

local EUI = _G.EllesmereUI

local xpcall = xpcall
local geterrorhandler = geterrorhandler

local function L(text)
    return EUI and EUI.L and EUI.L(text) or text
end

-- Later TOC files unpack addon[1..7] at file scope. Export the locale table
-- before anything that can bail, so a failed init surfaces as one clear message
-- instead of "attempt to index a nil value (local 'L')" in Metadata.lua.
addon[4] = setmetatable({}, {
    __index = function(_, key)
        return L(key)
    end
})

-- Stand-in for W/E when init bails: downstream file-scope code indexes nested
-- fields and calls methods, so every lookup resolves to a stand-in that
-- swallows any call. A dead load stays silent instead of erroring per file.
local function InertStub()
    local stub
    stub = setmetatable({}, {
        __index = function(t, key)
            local value = InertStub()
            rawset(t, key, value)
            return value
        end,
        __call = function()
            return stub
        end
    })
    return stub
end

local function AbortWithMessage(message)
    local frame = _G.DEFAULT_CHAT_FRAME
    if frame then
        frame:AddMessage(message)
    end
    addon[1] = addon[1] or InertStub()
    addon[2] = addon[2] or {}
    addon[3] = addon[3] or InertStub()
    addon[5] = addon[5] or {}
    addon[6] = addon[6] or {}
    addon[7] = addon[7] or {}
end

if not EUI or not EUI.Lite then
    AbortWithMessage("EllesmereUI_WindTools requires EllesmereUI to load first.")
    return
end

local CreateCompatE = addon.CreateCompatE
local InstallModuleSystem = addon.InstallModuleSystem
if not CreateCompatE or not InstallModuleSystem then
    AbortWithMessage("EllesmereUI_WindTools compat layer did not load.")
    return
end

local function SafeCall(func, ...)
    if type(func) == "function" then
        local args = {...}
        return xpcall(function()
            return func(unpack(args))
        end, function(err)
            return geterrorhandler()(err)
        end)
    end
end

-- A partial init (EllesmereUI present but broken by a new client patch) must not
-- leave later files unpacking nil: report the root error once, then bail cleanly.
local E, W
local initOk = xpcall(function()
    E = CreateCompatE()
    W = EUI.Lite.NewAddon(addonName)
    InstallModuleSystem(W)
end, function(err)
    return geterrorhandler()(err)
end)

if not initOk or not E or not W then
    AbortWithMessage("EllesmereUI_WindTools failed to initialize; see the error above.")
    return
end

local V, P, G = {}, {}, {}

addon[1] = W
addon[2] = {}
addon[3] = E
addon[5] = V
addon[6] = P
addon[7] = G

local F = addon[2]
F.GetCompatibleFont = function(name)
    return name
end

_WindTools = addon
_G.WindTools = addon

W.Title = "WindTools"
W.DisplayVersion = C_AddOns.GetAddOnMetadata(addonName, "X-Version") or "0.2.8"
W.Version = W.DisplayVersion
W.Utilities = W.Utilities or {}
W.CompatibleFont = false

W.Modules.Misc = W:NewModule("Misc")
W.Modules.Skins = W:NewModule("Skins")
W.Modules.Tooltips = W:NewModule("Tooltips")
W.Modules.MoveFrames = W:NewModule("MoveFrames")
W:NewModule("QuestProgress")

E:AddLib("OpenRaid", "LibOpenRaid-1.0")
E:AddLib("ObjectiveProgressWT", "LibObjectiveProgress-WT")
E:AddLib("RangeCheck", "LibRangeCheck-3.0")
E:AddLib("Keystone", "LibKeystone")
E:AddLib("WTItemEnchant", "LibItemEnchant-WT")

local db

local function InitDB()
    if db then
        return
    end

    db = EUI.Lite.NewDB("EllesmereUI_WindToolsDB", {
        profile = P
    })
    E.db.WT = db.profile

    _G.WindToolsGlobalDB = _G.WindToolsGlobalDB or {}
    if EUI.Lite.DeepMergeDefaults then
        EUI.Lite.DeepMergeDefaults(_G.WindToolsGlobalDB, G)
    end
    E.global.WT = _G.WindToolsGlobalDB

    _G.WindToolsPrivateDB = _G.WindToolsPrivateDB or {}
    if EUI.Lite.DeepMergeDefaults then
        EUI.Lite.DeepMergeDefaults(_G.WindToolsPrivateDB, V)
    end
    E.private.WT = _G.WindToolsPrivateDB

    W.db = db
end

local function Print(...)
    if EUI.Print then
        EUI.Print("|cff0cd29f[WindTools]|r", ...)
    end
end

addon.Print = Print

-------------------------------------------------------------------------------
--  Options page definitions
--  PAGE_GROUPS: ordered list of pages; each page aggregates one or more
--               category builders registered via addon.RegisterOptionBuilder.
--  A page renders by walking its categories and calling each builder with
--  (parent, y, title). Builders return the new y offset.
--
--  CATEGORY_TITLES: maps the internal category key (used in
--  RegisterOptionBuilder) to the human-readable title passed as the third
--  argument to each builder. Builders use this title for section headers.
-------------------------------------------------------------------------------
local CATEGORY_TITLES = {
    information    = "Information",
    misc           = "Misc",
    extraItemsBar  = "Extra Items Bar",
    item           = "Item",
    combat         = "Combat",
    announcement   = "Announcement",
    social         = "Social",
    unitFrames     = "Unit Frames",
    advanced       = "Advanced",
}

-- All pages and their category mappings (flat, used by BuildPage).
--
-- A page is listed only when the module behind it is actually loaded (see
-- Modules/Load_Modules.xml). Pages for unported modules are absent rather than
-- disabled, so the settings panel never offers a control that does nothing.
local PAGE_GROUPS = {{
    page = "Information",       categories = {"information"}
}, {
    page = "General",           categories = {"misc"}
}, {
    -- Game Bar owns a page of its own even though its options live in the Misc
    -- options file: that file also carries the CVars editor, which belongs to
    -- the General page.
    page = "Game Bar",          categories = {"misc"}
}, {
    page = "Extra Items Bar",   categories = {"extraItemsBar"}
}, {
    page = "Loot & Trade",      categories = {"item"}
}, {
    page = "Display",           categories = {"item"}
}, {
    page = "Inspect",           categories = {"item"}
}, {
    page = "Combat",            categories = {"combat"}
}, {
    page = "Announcement",      categories = {"announcement"}
}, {
    page = "Chat Bar",          categories = {"social"}
}, {
    page = "Smart Tab",         categories = {"social"}
}, {
    page = "Unit Frames",       categories = {"unitFrames"}
}, {
    page = "Advanced",          categories = {"advanced"}
}}

local GROUP_BY_PAGE = {}
for _, group in ipairs(PAGE_GROUPS) do
    GROUP_BY_PAGE[group.page] = group
end

-- Build a single options page by invoking its registered category builders.
-- pageName is passed as the 4th arg (subPage) so dispatch builders can
-- route to the correct section. Returns total content height.
local function BuildPage(pageName, parent, yOffset)
    local y = yOffset or -6
    local group = GROUP_BY_PAGE[pageName]
    if not group then
        return math.abs(y) + 30
    end

    local Widgets = EllesmereUI.Widgets
    for index, categoryKey in ipairs(group.categories or {}) do
        local builder = addon.OptionBuilders and addon.OptionBuilders[categoryKey]
        if builder then
            if index > 1 then
                local _, sh = Widgets:Spacer(parent, y, 8)
                y = y - sh
            end
            local title = CATEGORY_TITLES[categoryKey] or categoryKey
            local ok, newY = xpcall(function()
                return builder(parent, y, title, pageName)
            end, function(err)
                return geterrorhandler()(err)
            end)
            if ok and type(newY) == "number" then
                y = newY
            end
        end
    end
    return math.abs(y) + 30
end

-- Expose the page builder to the EllesmereUI plugin bridge in Options/Plugin.lua.
-- The page list itself is mirrored there in module form, so no group metadata
-- is exported: nothing outside the bridge walks it any more.
addon.BuildOptionsPage = BuildPage
addon.InitDB = InitDB

-------------------------------------------------------------------------------
--  Blizzard Settings panel entry (Options -> AddOns)
--  Registers a canvas-layout category with a single button that opens the
--  standalone WindTools options panel. Uses the same Settings API as
--  EllesmereUI's own entry.
-------------------------------------------------------------------------------
local function RegisterBlizzardOptionsEntry()
    if not Settings or not Settings.RegisterCanvasLayoutCategory then return end

    local panel = CreateFrame("Frame")
    panel.name = L("WindTools") .. " for EllesmereUI"

    local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    btn:SetSize(220, 30)
    btn:SetPoint("CENTER", panel, "CENTER", 0, 0)
    btn:SetText(L("Open WindTools"))

    btn:SetScript("OnClick", function()
        -- Close Blizzard settings first to avoid overlapping windows
        if SettingsPanel and SettingsPanel:IsShown() then
            HideUIPanel(SettingsPanel)
        end
        C_Timer.After(0, function()
            -- The pages live inside the EllesmereUI panel. Registration can be
            -- refused (a taken id, a reserved label), and there is no second
            -- window to fall back to, so say so instead of doing nothing.
            if not (addon.OpenOptionsPlugin and addon.OpenOptionsPlugin()) then
                Print("options are not available: EllesmereUI refused the page registration.")
            end
        end)
    end)

    local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
    Settings.RegisterAddOnCategory(category)
end

function W:OnProfileChanged()
    self:UpdateModules()
end

W:RegisterEvent("PLAYER_LOGIN", function()
    InitDB()
    W.initialized = true
    -- Modules\Misc\Core.lua gates its ADDON_LOADED handler on this flag,
    -- so every Misc module silently never ran before it was set.
    E.initialized = true
    -- The ported modules call ElvUI frame methods (frame:Size, frame:Point,
    -- frame:SetTemplate and about twenty more). They are installed here
    -- rather than at file scope because the per-object-type pass has to walk
    -- the Blizzard frames that already exist, and it has to happen before
    -- any module initializes.
    if E.InstallFrameAPI then
        SafeCall(E.InstallFrameAPI, E)
    end
    SafeCall(W.InitializeModules, W)
    -- The plugin API can be called at any point after EllesmereUI's chunk has
    -- run, but the pages read the profile DB, so this waits until InitDB did.
    if addon.RegisterOptionsPlugin then
        SafeCall(addon.RegisterOptionsPlugin)
    end
    RegisterBlizzardOptionsEntry()
    -- The login message is an account wide preference: Options/Advanced.lua
    -- writes it to E.global.WT.core, which is the table Settings/Global.lua
    -- defines. Reading profile.core here matched nothing, so the switch never
    -- did anything.
    if E.global.WT and E.global.WT.core and E.global.WT.core.loginMessage then
        -- Upstream printed a small logo plus "<title> <version> Loaded." followed
        -- by a line of feedback channels. The channels belong to upstream and do
        -- not apply to this port, so only the version line is kept. It bypasses
        -- Print because that already prefixes [WindTools] and the locale string
        -- carries the title itself.
        if EUI.Print then
            EUI.Print(format(L("%s %s Loaded."), W.Title, W.Version))
        end
    end
end)

-------------------------------------------------------------------------------
--  AddOn Compartment entry
--  Opens the pages inside the EllesmereUI panel.
-------------------------------------------------------------------------------
_G.WindTools_OnAddonCompartmentClick = function()
    if not (addon.OpenOptionsPlugin and addon.OpenOptionsPlugin()) then
        Print("options are not available: EllesmereUI refused the page registration.")
    end
end
