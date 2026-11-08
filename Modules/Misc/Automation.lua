local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local AM = W:NewModule("Automation") ---@class Automation : AceModule

local _G = _G
local securecall = securecall

local AcceptResurrect = AcceptResurrect
local HideUIPanel = HideUIPanel
local PlayerCanTeleport = PlayerCanTeleport
local StaticPopup_Hide = StaticPopup_Hide
local UnitAffectingCombat = UnitAffectingCombat
local UnitExists = UnitExists

local C_SummonInfo_ConfirmSummon = C_SummonInfo.ConfirmSummon

local confirmSummonAfterCombat = false

function AM:CANCEL_SUMMON()
	confirmSummonAfterCombat = false
end

function AM:CONFIRM_SUMMON()
	if not self.db or not self.db.confirmSummon then
		return
	end

	if confirmSummonAfterCombat then
		return
	end

	if UnitAffectingCombat("player") or not PlayerCanTeleport() then
		confirmSummonAfterCombat = true
		return
	end

	E:Delay(0.6, function()
		C_SummonInfo_ConfirmSummon()
		StaticPopup_Hide("CONFIRM_SUMMON")
	end)
end

function AM:PLAYER_REGEN_ENABLED()
	self.isInCombat = false

	if confirmSummonAfterCombat then
		confirmSummonAfterCombat = false
		if self.db and self.db.confirmSummon then
			C_SummonInfo_ConfirmSummon()
			StaticPopup_Hide("CONFIRM_SUMMON")
		end
	end
end

function AM:PLAYER_REGEN_DISABLED()
	self.isInCombat = true

	if self.db.hideWorldMapAfterEnteringCombat and _G.WorldMapFrame:IsShown() then
		HideUIPanel(_G.WorldMapFrame)
	end

	if self.db.hideBagAfterEnteringCombat then
		securecall("CloseAllBags")
	end
end

function AM:RESURRECT_REQUEST(_, inviterName)
	local inviterIsInCombat = UnitAffectingCombat(inviterName)
	local bossIsInCombat = UnitExists("boss1") and UnitAffectingCombat("boss1")

	if self.isInCombat or inviterIsInCombat or bossIsInCombat then
		if self.db.acceptCombatResurrect then
			AcceptResurrect()
		end
	else
		if self.db.acceptResurrect then
			AcceptResurrect()
		end
	end
end

local events = {
	"PLAYER_REGEN_ENABLED",
	"PLAYER_REGEN_DISABLED",
	"RESURRECT_REQUEST",
	"CONFIRM_SUMMON",
	"CANCEL_SUMMON",
}

local function registerEvents(module, enabled)
	for i = 1, #events do
		if enabled then
			module:RegisterEvent(events[i])
		else
			module:UnregisterEvent(events[i])
		end
	end
end

function AM:Initialize()
	self.db = E.db.WT.misc.automation
	if not self.db or not self.db.enable or self.initialized then
		return
	end

	registerEvents(self, true)
	self.initialized = true
end

function AM:ProfileUpdate()
	self.db = E.db.WT.misc.automation
	if not self.db then
		return
	end

	-- Every handler reads self.db on entry, so the events can stay registered
	-- while the module is off. What must not happen is a module that was
	-- switched on registering a second time, which is what initialized guards.
	if self.db.enable and not self.initialized then
		registerEvents(self, true)
		self.initialized = true
	elseif not self.db.enable and self.initialized then
		registerEvents(self, false)
		self.initialized = false
	end
end

W:RegisterModule(AM:GetName())
