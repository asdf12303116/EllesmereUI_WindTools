local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local A = W:GetModule("Announcement") ---@class Announcement
-- Resolved on demand so a load-order change cannot capture nil.
local function GetKeystoneInfo()
	return W:GetModule("KeystoneInfo", true) ---@type KeystoneInfo
end

local gsub = gsub
local strlower = strlower

function A:Keystone(_, _, link)
	local db = self.db.keystone

	if not db or not db.enable then
		return
	end

	local message = gsub(db.text, "%%keystone%%", link)
	self:SendMessage(message, self:GetChannel(db.channel))
end

function A:KeystoneLink(event, text)
	local db = self.db.keystone

	if not db or not db.enable or not db.command then
		return
	end

	if E:IsSecretValue(text) or strlower(text) ~= "!keys" then
		return
	end

	local channel
	if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
		channel = "PARTY"
	elseif event == "CHAT_MSG_GUILD" then
		channel = "GUILD"
	end

	local KI = GetKeystoneInfo()
	if channel and KI then
		local link = KI:GetPlayerKeystoneLink()
		if link then
			self:SendMessage(link, channel)
		end
	end
end
