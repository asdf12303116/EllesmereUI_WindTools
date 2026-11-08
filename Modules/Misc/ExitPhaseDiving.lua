local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local async = W.Utilities.Async
local M = W.Modules.Misc ---@class Misc

local _G = _G
local select = select

local CreateFrame = CreateFrame
local PP = _G.EllesmereUI and _G.EllesmereUI.PP

local NORM_TEX = "Interface\\Buttons\\WHITE8x8"

local SPELL_ID = 1250255
local AURA_ID = 1214374

local tooltipTitle = "Exit Phase Diving"
local tooltipIcon = 4913234

async.WithSpellID(SPELL_ID, function(spell)
	tooltipTitle = F.GetWindStyleText(spell:GetSpellName())
end)

-- Transparent black panel behind the icon. Replaces the ElvUI-only
-- frame:CreateBackdrop("Transparent"), same pattern as Modules\Misc\GameBar.lua.
local function ApplyBackdrop(frame)
	if not PP then
		return
	end

	local bg = frame.bg or frame:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(NORM_TEX)
	bg:SetVertexColor(0, 0, 0, 0.5)
	bg:SetAllPoints()
	if bg.SetSnapToPixelGrid then
		bg:SetSnapToPixelGrid(false)
		bg:SetTexelSnappingBias(0)
	end
	frame.bg = bg

	PP.CreateBorder(frame, 0, 0, 0, 1, 1, "BORDER", 0)
end

local function visuallyHide(button)
	button.backdrop:SetAlpha(0)
	button.Icon:SetAlpha(0)
	button.Highlight:SetAlpha(0)
end

local function visuallyShow(button)
	button.backdrop:SetAlpha(1)
	button.Icon:SetAlpha(1)
	button.Highlight:SetAlpha(1)
end

local function updateVisual(button)
	if E:GetAuraByID("player", AURA_ID, "HELPFUL") then
		visuallyShow(button)
	else
		visuallyHide(button)
	end
end

local function updateButton(button, db)
	if db.enable then
		button:Show()
		if PP then
			PP.Size(button, db.width, db.height)
		else
			button:SetSize(db.width, db.height)
		end
		button.Icon:SetTexCoord(E:CropRatio(db.width, db.height))
		updateVisual(button)
	else
		button:Hide()
	end
end

local function createButton()
	local button = CreateFrame("Button", "WTExitPhaseDivingButton", E.UIParent, "SecureActionButtonTemplate")

	button:SetAttribute("type*", "macro")
	button:SetAttribute("macrotext1", "/cancelaura " .. AURA_ID .. "\n/run _G.GameTooltip:Hide()")
	button:RegisterForClicks(W.UseKeyDown and "AnyDown" or "AnyUp")

	if PP then
		PP.Size(button, 81, 50)
		PP.Point(button, "TOP", 0, -90)
	else
		button:SetSize(81, 50)
		button:SetPoint("TOP", 0, -90)
	end

	ApplyBackdrop(button)
	-- The alpha target of the fade helpers is the backdrop texture itself.
	button.backdrop = button.bg

	button.Icon = button:CreateTexture(nil, "ARTWORK")
	button.Icon:SetAllPoints()
	button.Icon:EnableMouse(false)
	button.Icon:SetTexture(tooltipIcon)

	button.Highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.Highlight:SetAllPoints()
	button.Highlight:SetTexture(NORM_TEX)
	button.Highlight:SetColorTexture(1, 1, 1, 0.15)
	button.Highlight:Hide()

	button:SetScript("OnEnter", function(self)
		if E:GetAuraByID("player", AURA_ID, "HELPFUL") then
			self.Highlight:Show()
			_G.GameTooltip:SetOwner(self, "ANCHOR_BOTTOM", 0, -5)
			_G.GameTooltip:SetText(tooltipTitle, 1, 1, 1)
			_G.GameTooltip:Show()
		end
	end)

	button:SetScript("OnLeave", function(self)
		self.Highlight:Hide()
		_G.GameTooltip:Hide()
	end)

	E:CreateMover(
		button,
		"WTExitPhaseDivingButtonMover",
		L["Exit Phase Diving Button"],
		nil,
		nil,
		nil,
		"ALL,WINDTOOLS",
		function()
			return E.db.WT.misc.exitPhaseDiving.enable
		end,
		"WindTools,misc,exitPhaseDiving"
	)

	button:RegisterEvent("UNIT_AURA")
	button:SetScript("OnEvent", function(self, event, ...)
		if event == "UNIT_AURA" and select(1, ...) == "player" then
			updateVisual(self)
		end
	end)

	return button
end

function M:ExitPhaseDiving()
	if not E.db.WT.misc.exitPhaseDiving.enable then
		return
	end

	self.ExitPhaseDivingButton = createButton()
	updateButton(self.ExitPhaseDivingButton, E.db.WT.misc.exitPhaseDiving)
end

function M:UpdateExitPhaseDivingButton()
	F.TaskManager:OutOfCombat(function()
		local db = E.db.WT.misc.exitPhaseDiving
		if db.enable and not self.ExitPhaseDivingButton then
			self.ExitPhaseDivingButton = createButton()
		end
		if self.ExitPhaseDivingButton then
			updateButton(self.ExitPhaseDivingButton, db)
		end
	end)
end

M:AddCallback("ExitPhaseDiving")
M:AddCallbackForUpdate("UpdateExitPhaseDivingButton")
