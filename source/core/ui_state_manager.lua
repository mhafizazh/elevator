UIStateManager = {}
UIStateManager.__index = UIStateManager

function UIStateManager.new()
	local self = setmetatable({}, UIStateManager)
	
	-- Screen state
	self.screenState = "main_menu"
	
	-- Selection indices per screen
	self.mainMenuSelectionIndex = 1
	self.selectedCharacterIndex = 1
	self.startingInventorySelectionIndex = 1
	self.floorItemSelectionIndex = 1
	self.lootSelectionIndex = 1
	self.collectibleSelectionIndex = 1
	
	-- Main menu options
	self.difficultyLevel = 1 -- 1: Easy, 2: Medium, 3: Hard
	self.tutorialEnabled = true
	
	-- UI text & flags
	self.lastRunSummary = ""
	self.showKeyCutscene = false
	self.collectibleForReplacement = nil
	self.lastFloorSurvived = false
	
	-- Tutorial tracking
	self.tutorialsShown = {
		starting_loadout = false,
		crank_up = false,
		character_select = false,
		item_select = false,
		loot_select = false,
		item_collection = false,
		results = false,
	}
	
	return self
end

-- === SCREEN STATE ===

function UIStateManager:getScreenState()
	return self.screenState
end

function UIStateManager:setScreenState(state)
	self.screenState = state
end

-- === SELECTION INDICES ===

function UIStateManager:getSelectionIndex(screenName)
	if screenName == "main_menu" then
		return self.mainMenuSelectionIndex
	elseif screenName == "character_select" then
		return self.selectedCharacterIndex
	elseif screenName == "starting_loadout" then
		return self.startingInventorySelectionIndex
	elseif screenName == "item_select" then
		return self.floorItemSelectionIndex
	elseif screenName == "loot_select" then
		return self.lootSelectionIndex
	elseif screenName == "item_collection" then
		return self.collectibleSelectionIndex
	end
	return 1
end

function UIStateManager:setSelectionIndex(screenName, index)
	if screenName == "main_menu" then
		self.mainMenuSelectionIndex = index
	elseif screenName == "character_select" then
		self.selectedCharacterIndex = index
	elseif screenName == "starting_loadout" then
		self.startingInventorySelectionIndex = index
	elseif screenName == "item_select" then
		self.floorItemSelectionIndex = index
	elseif screenName == "loot_select" then
		self.lootSelectionIndex = index
	elseif screenName == "item_collection" then
		self.collectibleSelectionIndex = index
	end
end

function UIStateManager:clampSelectionIndex(screenName, maxIndex)
	local currentIndex = self:getSelectionIndex(screenName)
	local clamped = math.max(1, math.min(currentIndex, maxIndex))
	self:setSelectionIndex(screenName, clamped)
	return clamped
end

-- === UI TEXT & SUMMARY ===

function UIStateManager:setSummary(text)
	self.lastRunSummary = text
end

function UIStateManager:getSummary()
	return self.lastRunSummary
end

-- === MENU OPTIONS ===

function UIStateManager:getDifficultyLevel()
	return self.difficultyLevel
end

function UIStateManager:setDifficultyLevel(level)
	self.difficultyLevel = level
end

function UIStateManager:isTutorialEnabled()
	return self.tutorialEnabled
end

function UIStateManager:setTutorialEnabled(enabled)
	self.tutorialEnabled = enabled
end

-- === TUTORIALS ===

function UIStateManager:setTutorialShown(screenName)
	self.tutorialsShown[screenName] = true
end

function UIStateManager:isTutorialShown(screenName)
	return self.tutorialsShown[screenName] or false
end

-- === CUTSCENE FLAGS ===

function UIStateManager:toggleKeyCutscene()
	self.showKeyCutscene = not self.showKeyCutscene
end

function UIStateManager:setKeyCutscene(value)
	self.showKeyCutscene = value
end

function UIStateManager:shouldShowKeyCutscene()
	return self.showKeyCutscene
end

-- === FLOOR SURVIVAL ===

function UIStateManager:setFloorSurvived(survived)
	self.lastFloorSurvived = survived
end

function UIStateManager:didFloorSurvive()
	return self.lastFloorSurvived
end

-- === COLLECTIBLE REPLACEMENT ===

function UIStateManager:setCollectibleForReplacement(itemId)
	self.collectibleForReplacement = itemId
end

function UIStateManager:getCollectibleForReplacement()
	return self.collectibleForReplacement
end
