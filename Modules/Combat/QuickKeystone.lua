local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local QK = W:NewModule("QuickKeystone")

local _G = _G

local C_AddOns_IsAddOnLoaded = C_AddOns.IsAddOnLoaded
local C_Container_GetContainerItemID = C_Container.GetContainerItemID
local C_Container_GetContainerNumSlots = C_Container.GetContainerNumSlots
local C_Container_UseContainerItem = C_Container.UseContainerItem
local C_Item_IsItemKeystoneByID = C_Item.IsItemKeystoneByID

local NUM_BAG_SLOTS = NUM_BAG_SLOTS

function QK:PutKeystone()
	for bagIndex = 0, NUM_BAG_SLOTS do
		for slotIndex = 1, C_Container_GetContainerNumSlots(bagIndex) do
			local itemID = C_Container_GetContainerItemID(bagIndex, slotIndex)
			if itemID and C_Item_IsItemKeystoneByID(itemID) then
				C_Container_UseContainerItem(bagIndex, slotIndex)
				return
			end
		end
	end
end

---Hook the keystone frame once and gate the work on the setting instead of
---adding and removing the hook: Blizzard script handlers cannot be unhooked.
---@param event string?
---@param addonName string?
function QK:UpdateHook(event, addonName)
	if event then
		if addonName ~= "Blizzard_ChallengesUI" then
			return
		end
		self:UnregisterEvent("ADDON_LOADED")
	end

	local frame = _G.ChallengesKeystoneFrame
	if not frame or self.hookedFrame == frame then
		return
	end

	self.hookedFrame = frame
	frame:HookScript("OnShow", function()
		if self.db and self.db.enable then
			self:PutKeystone()
		end
	end)
end

function QK:ProfileUpdate()
	self.db = E.db.WT.combat.quickKeystone

	if C_AddOns_IsAddOnLoaded("Blizzard_ChallengesUI") then
		self:UpdateHook()
	else
		self:RegisterEvent("ADDON_LOADED", "UpdateHook")
	end
end

QK.Initialize = QK.ProfileUpdate

W:RegisterModule(QK:GetName())
