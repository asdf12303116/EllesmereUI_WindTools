local G ---@class GlobalDB
local W, F, E, L, V, P ---@type WindTools, Functions, ElvUI, LocaleTable, PrivateDB, ProfileDB
W, F, E, L, V, P, G = unpack((select(2, ...)))

G.core = {
	compatibilityCheck = true,
	changlogPopup = false,
	elvUIVersionPopup = true,
	cvarAlert = false,
	fixSetPassThroughButtons = false,
	loginMessage = true,
	autoCopyPrivateProfile = {
		enable = false,
		copyFrom = nil,
		initializedCharacters = {},
	},
}

G.developer = {
	logLevel = 2,
	tableAttributeDisplay = {
		enable = false,
		width = 1000,
		height = 600,
	},
}

G.item = {
	contacts = {
		alts = {},
		favorites = {},
		updateAlts = true,
	},
	extraItemsBar = {
		bar1 = {},
		bar2 = {},
		bar3 = {},
		bar4 = {},
		bar5 = {},
	},
}

G.combat = {
	raidMarkers = {
		-- Mover position saved at account level so layout is shared across
		-- characters. Populated by EllesmereUI Unlock Mode via the
		-- RegisterUnlockElements API. Nil = use default anchor (right side of
		-- the screen, bottom-right area).
		position = nil,
	},
	combatAlert = {
		-- Mover position saved at account level; written by EllesmereUI
		-- Unlock Mode through Core\CompatE.lua's E:CreateMover shim.
		position = nil,
	},
	damageMeterLayout = {
		position = nil,
	},
	covenantHelper = {
		soulbindRules = {
			characters = {},
		},
	},
}

G.misc = {
	watched = {
		movies = {},
	},
	lfgList = {},
	exitPhaseDiving = {
		position = nil,
	},
	gameBar = {
		-- Mover position saved at account level so the bar layout is shared
		-- across characters. Populated by EllesmereUI Unlock Mode via the
		-- RegisterUnlockElements API. Nil = use the default anchor (top center).
		position = nil,
	},
}

G.maps = {
	eventTracker = {},
	instanceDifficulty = {
		position = nil,
	},
	minimapButtons = {
		position = nil,
	},
}

G.social = {
	emote = {
		position = nil,
	},
	chatBar = {
		-- Mover position saved at account level so layout is shared across
		-- characters. Populated by EllesmereUI Unlock Mode via the
		-- RegisterUnlockElements API. Nil = use default anchor (above LeftChatPanel).
		position = nil,
	},
}

G.quest = {
	switchButtons = {
		position = nil,
	},
}
