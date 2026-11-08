local W, F, E, L = unpack((select(2, ...))) ---@type WindTools, Functions, ElvUI, LocaleTable
local A = W:GetModule("Announcement") ---@class Announcement
-- The Quest group owns QuestProgress and loads independently of this one, so
-- the handle is resolved on demand instead of at load time: capturing nil
-- here would silently disable quest announcing for the whole session.
local function GetQuestProgress()
	return W:GetModule("QuestProgress", true) ---@type QuestProgress
end

local UnitLevel = UnitLevel

---@class QuestAnnounceEventType : number

---@type table<string, QuestAnnounceEventType>
A.QUEST_EVENT = {
	ACCEPTED = 1,
	COMPLETED = 2,
	OBJECTIVE_COMPLETED = 3,
	PROGRESS_UPDATE = 4,
}

---Announce quest progress to chat
---@param eventType QuestAnnounceEventType Event type
---@param context QuestProgressContext Context tables (plain text contexts)
function A:AnnounceQuestProgress(eventType, context)
	if not self.db or not self.db.enable or not self.db.quest or not self.db.quest.enable then
		return
	end

	local db = self.db.quest

	-- Check if paused (controlled by SwitchButtons module)
	local questDB = E.db.WT.quest
	if questDB and questDB.switchButtons and questDB.switchButtons.enable and db.paused then
		return
	end

	-- Determine if we should announce based on event type and settings
	local shouldAnnounce = false

	if eventType == self.QUEST_EVENT.ACCEPTED then
		shouldAnnounce = true
	elseif eventType == self.QUEST_EVENT.COMPLETED then
		shouldAnnounce = true
	elseif eventType == self.QUEST_EVENT.OBJECTIVE_COMPLETED then
		shouldAnnounce = true
	elseif eventType == self.QUEST_EVENT.PROGRESS_UPDATE then
		-- Only announce progress if includeDetails is enabled
		shouldAnnounce = db.includeDetails
	end

	if not shouldAnnounce then
		return
	end

	if context.rawLevel then
		if
			db.hideLevelOnMaxLevel and context.rawLevel == W.MaxLevelForPlayerExpansion
			or db.hideLevelIfSameAsPlayer and context.rawLevel == UnitLevel("player")
		then
			context.level = nil
		end
	end

	-- Render message using template and contexts
	local QP = GetQuestProgress()
	if not QP or not QP.RenderTemplate then
		return
	end

	local message = QP:RenderTemplate(db.template, context)

	if message and message ~= "" then
		self:SendMessage(message, self:GetChannel(db.channel))
	end
end
