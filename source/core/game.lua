-- Imports
import "CoreLibs/graphics"
import "core/build_flags"
import "core/data/characters"
import "core/data/items"
import "assets/images"
import "systems/crank_system"
import "systems/floor_challenge_system"
import "systems/floor_generator"
import "core/ui_state_manager"
import "core/ui_renderer"
import "core/input_handler"
import "core/inventory_manager"
import "core/cutscene_manager"
import "core/game_utilities"

local pd = playdate
math.randomseed(pd.getSecondsSinceEpoch())
local gfx = pd.graphics

-- === GAME CLASS ===

Game = {}
Game.__index = Game

-- === INITIALIZATION ===

function Game.new()
	local self = setmetatable({}, Game)
	local loadedImages = Images.load()

	-- Systems
	self.images = loadedImages
	self.crankSystem = CrankSystem.new(360, 0)
	self.floorChallengeSystem = FloorChallengeSystem.new()
	self.floorGenerator = FloorGenerator.new()

	-- Game data
	local generatedFloors, generatedLoot, exitKeyFloor, generatedCollectibles = self.floorGenerator:generate()
	self.gameData = {
		floors = generatedFloors,
		lootByFloor = generatedLoot,
		exitKeyFloor = exitKeyFloor,
		collectibleByFloor = generatedCollectibles
	}

	-- Core state
	self.currentFloorIndex = 0
	self.selectedDestinationFloor = 1
	self.resolvedFloors = {}
	self.lastCrankStep = 0

	-- Flags
	self.hasZombieInfection = false
	self.hasCultKey = false
	self.hasExitKey = false

	-- UI/display
	self.numberX = 200
	self.numberY = 50

	-- Characters
	self.characters = {}
	self.characterOptions = {}
	for _, character in pairs(Characters) do
		local characterState = cloneCharacterState(character)
		characterState.sick = false
		characterState.hurt = false
		characterState.vaccinated = false
		self.characters[characterState.id] = characterState
		self.characterOptions[#self.characterOptions + 1] = characterState.id
	end
	table.sort(self.characterOptions)

	-- Managers (handle all state logic)
	self.uiState = UIStateManager.new()
	self.inventory = InventoryManager.new()
	self.cutscene = CutsceneManager.new()
	self.input = InputHandler.new(self)
	self.renderer = UIRenderer.new(self)

	return self
end

-- === CHARACTER MANAGEMENT ===

function Game:getSelectedCharacter()
	local characterId = self.characterOptions[self.uiState:getSelectionIndex("character_select")]
	return self.characters[characterId]
end

function Game:isAnyCharacterAlive()
	for _, character in pairs(self.characters) do
		if character.alive then
			return true
		end
	end
	return false
end

function Game:selectFirstAliveCharacter()
	for i, characterId in ipairs(self.characterOptions) do
		local character = self.characters[characterId]
		if character.alive then
			self.uiState:setSelectionIndex("character_select", i)
			return
		end
	end
end

-- === GAME FLOW ===

function Game:startGame()
	local minFloors, maxFloors = 20, 30
	local diffLevel = self.uiState:getDifficultyLevel()
	if diffLevel == 1 then
		minFloors, maxFloors = 20, 30
	elseif diffLevel == 2 then
		minFloors, maxFloors = 40, 50
	elseif diffLevel == 3 then
		minFloors, maxFloors = 90, 100
	end

	local generatedFloors, generatedLoot, exitKeyFloor, generatedCollectibles = self.floorGenerator:generate(minFloors, maxFloors)
	self.gameData = {
		floors = generatedFloors,
		lootByFloor = generatedLoot,
		exitKeyFloor = exitKeyFloor,
		collectibleByFloor = generatedCollectibles
	}

	if not self.uiState:isTutorialEnabled() then
		-- Mark all tutorials as shown
		for k, _ in pairs(self.uiState.tutorialsShown) do
			self.uiState.tutorialsShown[k] = true
		end
	end

	self.uiState:setScreenState("starting_loadout")
	self.uiState:setSelectionIndex("starting_loadout", 1)
end

function Game:confirmStartingInventory()
	self.uiState:setTutorialShown("starting_loadout")
	self.inventory:confirmStartingItems()
	self.inventory:clearPendingEquipped()
	self.uiState:setScreenState("closed_floor")
	self.selectedDestinationFloor = 1
	self.lastCrankStep = self.crankSystem:getValue()
	self.uiState:setSummary("Rotate crank to move upstairs.")
end

function Game:openItemCollection()
	self.uiState:setTutorialShown("item_collection")
	self.uiState:setSelectionIndex("item_collection", 1)
	
	-- Check if backpack or medkit is in collectibles
	local hasBackpack = false
	local hasMedkit = false
	local displayItems = {}
	for _, itemId in ipairs(self.inventory.currentCollectibleItems) do
		if itemId == "backpack" then
			hasBackpack = true
		elseif itemId == "medkit" then
			hasMedkit = true
		else
			displayItems[#displayItems + 1] = itemId
		end
	end
	
	self.inventory.currentCollectibleItems = displayItems
	
	if hasMedkit then
		self:_applyMedkit()
		return
	end
	
	-- If backpack found, show backpack cutscene instead
	if hasBackpack then
		self.inventory:increaseCapacity()
		self.cutscene:playCutscene(ItemFoundCutscene.new("backpackCutscene", "You found the backpack!"))
		self.uiState:setScreenState("backpack_cutscene")
		self.uiState:setSummary("You found the backpack!")
		return
	end
	
	if #self.inventory.currentCollectibleItems == 0 then
		-- No items to display, go back to closed_floor
		self.uiState:setScreenState("closed_floor")
		self.lastCrankStep = self.crankSystem:getValue()
		self.uiState:setSummary("No items to collect.")
	else
		self.uiState:setScreenState("item_collection")
		self.uiState:setSummary("Select items to collect with A, then B to confirm.")
	end
end

function Game:closeItemCollection()
	self.uiState:setScreenState("closed_floor")
	self.lastCrankStep = self.crankSystem:getValue()
	self.uiState:setSummary("A selects character. B opens door.")
	self.inventory.currentCollectibleItems = {}
	self.inventory.selectedCollectibleItemIds = {}
	self.uiState:setSelectionIndex("item_collection", 1)
end

function Game:openFloorItemSelection()
	self.uiState:setTutorialShown("character_select")
	self.inventory:clearPendingEquipped()
	self.uiState:setSelectionIndex("item_select", 1)
	self.uiState:setScreenState("item_select")
	local itemLimit = self.inventory.hasBackpackFound and 2 or 1
	self.uiState:setSummary("Select up to " .. itemLimit .. " item(s), then press B to confirm")
end

function Game:closeFloorItemSelection()
	self.uiState:setScreenState("character_select")
	self.uiState:setSummary("A selects items. B closes door.")
end

-- === CORE GAME LOGIC ===

function Game:resolveCurrentFloorEncounter()
	self.uiState:setTutorialShown("item_select")

	-- Validate state
	if self.currentFloorIndex == 0 then
		self.uiState:setScreenState("character_select")
		self.uiState:setSummary("Doors opened at floor 0")
		return
	end

	if self.resolvedFloors[self.currentFloorIndex] then
		self.uiState:setScreenState("character_select")
		self.uiState:setSummary("Doors opened at floor " .. tostring(self.currentFloorIndex) .. " (already cleared)")
		return
	end

	local selectedCharacter = self:getSelectedCharacter()
	if not selectedCharacter or not selectedCharacter.alive then
		self.uiState:setScreenState("character_select")
		self.uiState:setSummary("No alive character selected")
		return
	end

	-- Check exit condition
	local floorType = self.floorGenerator:getFloorType(self.gameData, self.currentFloorIndex)
	if floorType == "exit" then
		self:_handleExitFloor()
		return
	end

	-- Resolve combat
	local equippedItems = cloneList(self.inventory.pendingEquippedItemIds)
	local result = self.floorChallengeSystem:enterFloor(
		self.currentFloorIndex,
		floorType,
		selectedCharacter,
		equippedItems
	)

	self.inventory:clearPendingEquipped()
	self.resolvedFloors[self.currentFloorIndex] = true

	-- Debug output
	if DEBUG_MODE then
		self.cutscene:setDebugLines({
			"Floor " .. tostring(self.currentFloorIndex) .. " (" .. floorType .. ")",
			"Character: " .. selectedCharacter.name,
			"Items: " .. joinItemNames(equippedItems),
			"Chance: " .. tostring(result.chance),
			"Roll: " .. tostring(result.roll),
			result.survived and "Result: SURVIVED" or "Result: DIED",
		})
	end

	-- Generate cutscene
	local survivalText = result.survived and "Result: SURVIVED" or "Result: DIED"
	if result.survived then
		if result.gotSick then
			survivalText = "Result: SURVIVED (Sick)"
		elseif result.gotHurt then
			survivalText = "Result: SURVIVED (Hurt)"
		end
	end

	local cutsceneLines = {
		selectedCharacter.name .. " vs " .. tostring(floorType),
		"Floor " .. tostring(self.currentFloorIndex),
		"Chance " .. tostring(result.chance) .. "% | Roll " .. tostring(result.roll),
		result.survived and "Winner: " .. selectedCharacter.name or "Winner: Floor " .. tostring(self.currentFloorIndex),
		survivalText,
	}

	-- Handle outcome
	if result.survived then
		self:_handleFloorSurvival(selectedCharacter, floorType, cutsceneLines)
	else
		self:_handleCharacterDeath(selectedCharacter, cutsceneLines)
	end
end

-- === PRIVATE HELPERS ===

function Game:_applyMedkit()
	local sickOrHurt = {}
	local healthy = {}
	for _, character in pairs(self.characters) do
		if character.alive then
			if character.sick or character.hurt then
				sickOrHurt[#sickOrHurt + 1] = character
			else
				healthy[#healthy + 1] = character
			end
		end
	end
	
	local target
	local message
	if #sickOrHurt > 0 then
		target = sickOrHurt[math.random(1, #sickOrHurt)]
		target.sick = false
		target.hurt = false
		message = target.name .. " was cured!"
	elseif #healthy > 0 then
		target = healthy[math.random(1, #healthy)]
		target.vaccinated = true
		message = target.name .. " was vaccinated!"
	else
		-- Edge case: no one is alive? Shouldn't happen if game is running.
		message = "Found Medkit... but it's useless."
	end
	
	self.cutscene:playCutscene(ItemFoundCutscene.new("medkitCutscene", message))
	self.uiState:setScreenState("medkit_cutscene")
	self.uiState:setSummary(message)
end

function Game:_handleExitFloor()
	self.inventory:clearPendingEquipped()
	self.resolvedFloors[self.currentFloorIndex] = true

	if self.hasExitKey then
		self.uiState:setScreenState("victory")
		self.uiState:setSummary(self:getSelectedCharacter().name .. " escaped!")
	else
		self.uiState:setScreenState("exit_locked")
		self.uiState:setSummary("Exit is locked! Find the key.")
	end
end

function Game:_handleFloorSurvival(character, floorType, cutsceneLines)
	local showKeyImage = false
	local isItemFound = false

	-- Check for exit key
	if self.currentFloorIndex == self.gameData.exitKeyFloor then
		self.hasExitKey = true
		self.uiState:setSummary("Found: Exit Key!")
		table.insert(cutsceneLines, "Found: Exit Key!")
		showKeyImage = true
		isItemFound = true
	end

	if floorType == "loot" then
		local lootItems = self.gameData.lootByFloor[self.currentFloorIndex]
		if lootItems and #lootItems > 0 then
			self.inventory:setAvailableLoot(lootItems)
			self.uiState:setSelectionIndex("loot_select", 1)
			self.selectedDestinationFloor = clamp(self.currentFloorIndex + 1, 0, #self.gameData.floors)
			self.cutscene:start(cutsceneLines, showKeyImage, true)
			self.uiState:setScreenState("loot_select")
			return
		else
			if not showKeyImage then
				self.uiState:setSummary("No loot found")
			end
		end
	elseif floorType == "collectible" then
		local collectibles = self.gameData.collectibleByFloor[self.currentFloorIndex]
		if collectibles and #collectibles > 0 then
			isItemFound = true
		end
	else
		self.uiState:setSummary(character.name .. " survived floor " .. tostring(self.currentFloorIndex))
	end

	self.selectedDestinationFloor = clamp(self.currentFloorIndex + 1, 0, #self.gameData.floors)
	self.cutscene:start(cutsceneLines, showKeyImage, isItemFound)
	self.cutscene:setFloorSurvived(true)

	if floorType == "collectible" then
		self:openItemCollection()
	else
		self.uiState:setScreenState("result_cutscene")
	end
end

function Game:_handleCharacterDeath(character, cutsceneLines)
	character.alive = false

	if self:isAnyCharacterAlive() then
		self:selectFirstAliveCharacter()
		self.uiState:setSummary(character.name .. " died on floor " .. tostring(self.currentFloorIndex))
		self.cutscene:start(cutsceneLines)
		self.cutscene:setFloorSurvived(false)
		self.uiState:setScreenState("result_cutscene")
	else
		self:triggerGameOver()
	end
end

function Game:triggerGameOver()
	self.uiState:setScreenState("game_over")
	self.inventory:clearPendingEquipped()
	self.uiState:setSummary("Game Over")
	if DEBUG_MODE then
		self.cutscene:setDebugLines({
			"All family members are dead",
			"Run ended on floor " .. tostring(self.currentFloorIndex),
		})
	end
end

function Game:restartGame()
	-- Create a completely new game
	local newGame = Game.new()

	-- Copy over the new game state to self
	for k, v in pairs(newGame) do
		self[k] = v
	end
end

-- === MAIN LOOP ===

function Game:update()
	self.crankSystem:update(pd.getCrankChange())
	self.input:updateCrankFloorSelection()
	self.input:update(self.uiState:getScreenState())
	self.cutscene:update()
end

function Game:draw()
	self.renderer:draw()
end
