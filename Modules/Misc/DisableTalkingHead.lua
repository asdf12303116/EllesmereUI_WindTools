local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local M = W.Modules.Misc ---@class Misc

local _G = _G

function M:HideTalkingHeadFrame(frame)
	if frame and E.db.WT.misc.disableTalkingHead then
		frame:Hide()
	end
end

function M:HookTalkingHeadPlayCurrent()
	self:SecureHook(_G.TalkingHeadFrame, "PlayCurrent", "HideTalkingHeadFrame")
	self:SecureHook(_G.TalkingHeadFrame, "Reset", "HideTalkingHeadFrame")
end

function M:DisableTalkingHead()
	if _G.TalkingHeadFrame then
		self:HookTalkingHeadPlayCurrent()
		return
	end

	-- TalkingHeadUI.xml is part of FrameXML, so the frame is normally there
	-- long before addons load. The hook used to wait on TalkingHead_LoadUI,
	-- which neither client defines any more, so wait for the login event and
	-- look once more instead.
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function M:PLAYER_ENTERING_WORLD()
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")

	if _G.TalkingHeadFrame then
		self:HookTalkingHeadPlayCurrent()
	end
end

M:AddCallback("DisableTalkingHead")
