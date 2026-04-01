import "CoreLibs/graphics"
import "assets/images"
import "systems/crank_system"
import "systems/floor_challenge_system"
import "systems/floor_generator"
import "core/data/characters"
import "core/data/items"

local pd = playdate
local gfx = pd.graphics

Game = {}
Game.__index = Game

local STARTING_ITEM_LIMIT = 3
local FLOOR_EQUIP_LIMIT = 2
local RESULT_CUTSCENE_FRAMES = 90
local RESULT_CUTSCENE_HOLD_FRAMES = 35

local function cloneCharacterState(character)
	return {
		id = character.id,
		name = character.name,
		alive = true,
		stats = {
			combat = character.stats.combat,
			stealth = character.stats.stealth,
			survival = character.stats.survival,
			luck = character.stats.luck,
		},
	}
end

local function buildSortedItemOptions()
	local itemOptions = {}
	for itemId, item in pairs(Items) do
		itemOptions[#itemOptions + 1] = { id = itemId, name = item.name }
	end

	table.sort(itemOptions, function(left, right)
		return left.name < right.name
	end)

	return itemOptions
end

local function containsValue(values, target)
	for _, value in ipairs(values) do
		if value == target then
			return true
		end
	end
	return false
end

local function removeValue(values, target)
	for index, value in ipairs(values) do
		if value == target then
			table.remove(values, index)
			return true
		end
	end
	return false
end

local function joinItemNames(itemIds)
	if not itemIds or #itemIds == 0 then
		return "none"
	end

	local names = {}
	for _, itemId in ipairs(itemIds) do
		local item = Items[itemId]
		if item then
			names[#names + 1] = item.name
		end
	end

	if #names == 0 then
		return "none"
	end

	return table.concat(names, ", ")
end

local function cloneList(values)
	local copy = {}
	for index, value in ipairs(values or {}) do
		copy[index] = value
	end
	return copy
end

local function drawCenteredText(text, centerX, y)
	local textWidth = gfx.getTextSize(text)
	gfx.drawText(text, math.floor(centerX - (textWidth / 2)), y)
end



local function clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

function Game.new()
	local self = setmetatable({}, Game)
	local loadedImages = Images.load()

	self.hasZombieInfection = false
	self.hasCultKey = false
	self.hasExitKey = false
	self.images = loadedImages
	self.crankSystem = CrankSystem.new(360, 0)
	self.numberX = 200
	self.numberY = 50
	self.floorChallengeSystem = FloorChallengeSystem.new()
	self.floorGenerator = FloorGenerator.new()
	local generatedFloors, generatedLoot, exitKeyFloor = self.floorGenerator:generate()
	self.gameData = { floors = generatedFloors, lootByFloor = generatedLoot, exitKeyFloor = exitKeyFloor }
	self.currentFloorIndex = 0
	self.lastRunSummary = ""
	self.lastChallengeDebugLines = {}
	self.screenState = "starting_loadout"
	self.itemOptions = buildSortedItemOptions()
	self.startingInventorySelectionIndex = 1
	self.floorItemSelectionIndex = 1
	self.selectedStartingItemIds = {}
	self.ownedItemIds = {}
	self.pendingEquippedItemIds = {}
	self.lastCrankStep = 0
	self.selectedDestinationFloor = 1
	self.resolvedFloors = {}
	self.cutsceneTimer = 0
	self.cutsceneHoldTimer = 0
	self.cutsceneLines = {}
	self.currentLootItems = {}
	self.selectedLootItemIds = {}
	self.lootSelectionIndex = 1

	self.characters = {}
	self.characterOptions = {}
	for _, character in pairs(Characters) do
		local characterState = cloneCharacterState(character)
		self.characters[characterState.id] = characterState
		self.characterOptions[#self.characterOptions + 1] = characterState.id
	end
	table.sort(self.characterOptions)
	self.selectedCharacterIndex = 1

	return self
end

function Game:getSelectedCharacter()
	local characterId = self.characterOptions[self.selectedCharacterIndex]
	return self.characters[characterId]
end

function Game:isAnyCharacterAlive()
	for _, characterId in ipairs(self.characterOptions) do
		if self.characters[characterId].alive then
			return true
		end
	end
	return false
end

function Game:selectFirstAliveCharacter()
	for index, characterId in ipairs(self.characterOptions) do
		if self.characters[characterId].alive then
			self.selectedCharacterIndex = index
			return
		end
	end
end

function Game:triggerGameOver()
	self.screenState = "game_over"
	self.pendingEquippedItemIds = {}
	self.lastRunSummary = "Game Over"
	if DEBUG_MODE then
		self.lastChallengeDebugLines = {
			"All family members are dead",
			"Run ended on floor " .. tostring(self.currentFloorIndex),
		}
	else
		self.lastChallengeDebugLines = {}
	end
end

function Game:restartGame()
	local freshGame = Game.new()
	for key in pairs(self) do
		self[key] = nil
	end
	for key, value in pairs(freshGame) do
		self[key] = value
	end
end

function Game:startResultCutscene(lines)
	self.screenState = "result_cutscene"
	self.cutsceneTimer = RESULT_CUTSCENE_FRAMES
	self.cutsceneHoldTimer = RESULT_CUTSCENE_HOLD_FRAMES
	self.cutsceneLines = lines or {}
end

function Game:resolveCurrentFloorEncounter()
	if self.currentFloorIndex == 0 then
		self.screenState = "character_select"
		self.lastRunSummary = "Doors opened at floor 0"
		return
	end

	if self.resolvedFloors[self.currentFloorIndex] then
		self.screenState = "character_select"
		self.lastRunSummary = "Doors opened at floor " .. tostring(self.currentFloorIndex) .. " (already cleared)"
		return
	end

	local selectedCharacter = self:getSelectedCharacter()
	if not selectedCharacter or not selectedCharacter.alive then
		self.screenState = "character_select"
		self.lastRunSummary = "No alive character selected"
		return
	end

	local floorType = self.floorGenerator:getFloorType(self.gameData, self.currentFloorIndex)
	local equippedItems = cloneList(self.pendingEquippedItemIds)

	if floorType == "exit" then
		self.pendingEquippedItemIds = {}
		self.resolvedFloors[self.currentFloorIndex] = true
		if self.hasExitKey then
			self.screenState = "victory"
			self.lastRunSummary = selectedCharacter.name .. " escaped!"
		else
			self.screenState = "exit_locked"
			self.lastRunSummary = "Exit is locked! Find the key."
		end
		return
	end

	local result = self.floorChallengeSystem:enterFloor(
		self.currentFloorIndex,
		floorType,
		selectedCharacter,
		equippedItems
	)

	self.pendingEquippedItemIds = {}
	self.resolvedFloors[self.currentFloorIndex] = true
	if DEBUG_MODE then
		self.lastChallengeDebugLines = {
			"Floor " .. tostring(self.currentFloorIndex) .. " (" .. floorType .. ")",
			"Character: " .. selectedCharacter.name,
			"Items: " .. joinItemNames(equippedItems),
			"Chance: " .. tostring(result.chance),
			"Roll: " .. tostring(result.roll),
			result.survived and "Result: SURVIVED" or "Result: DIED",
		}
	else
		self.lastChallengeDebugLines = {}
	end

	local cutsceneLines = {
		selectedCharacter.name .. " vs " .. tostring(floorType),
		"Floor " .. tostring(self.currentFloorIndex),
		"Chance " .. tostring(result.chance) .. "% | Roll " .. tostring(result.roll),
		result.survived and "Winner: " .. selectedCharacter.name or "Winner: Floor " .. tostring(self.currentFloorIndex),
		result.survived and "Result: SURVIVED" or "Result: DIED",
	}

	if result.survived then
		if self.currentFloorIndex == self.gameData.exitKeyFloor then
			self.hasExitKey = true
			self.lastRunSummary = "Found: Exit Key!"
			cutsceneLines[#cutsceneLines + 1] = "Found: Exit Key!"
		elseif floorType == "loot" then
			local lootItems = self.gameData.lootByFloor[self.currentFloorIndex]
			if lootItems and #lootItems > 0 then
				self.currentLootItems = lootItems
				self.selectedLootItemIds = {}
				for _, itemId in ipairs(self.ownedItemIds) do
					self.selectedLootItemIds[#self.selectedLootItemIds + 1] = itemId
				end
				self.lootSelectionIndex = 1
				self.selectedDestinationFloor = clamp(self.currentFloorIndex + 1, 0, #self.gameData.floors)
				self:startResultCutscene(cutsceneLines)
				self.screenState = "loot_select"
				self.cutsceneTimer = 0
				return
			else
				self.lastRunSummary = "No loot found"
			end
		else
			self.lastRunSummary = selectedCharacter.name .. " survived floor " .. tostring(self.currentFloorIndex)
		end
		self.selectedDestinationFloor = clamp(self.currentFloorIndex + 1, 0, #self.gameData.floors)
		self:startResultCutscene(cutsceneLines)
	else
		selectedCharacter.alive = false
		if self:isAnyCharacterAlive() then
			self:selectFirstAliveCharacter()
			self.lastRunSummary = selectedCharacter.name .. " died on floor " .. tostring(self.currentFloorIndex)
			self:startResultCutscene(cutsceneLines)
		else
			self:triggerGameOver()
		end
	end
end

function Game:updateResultCutscene()
	if self.cutsceneHoldTimer > 0 then
		self.cutsceneHoldTimer = self.cutsceneHoldTimer - 1
	else
		if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
			self.cutsceneTimer = 0
		end
	end

	self.cutsceneTimer = self.cutsceneTimer - 1
	if self.cutsceneTimer <= 0 then
		if self.screenState ~= "game_over" then
			self.screenState = "character_select"
		end
	end
end

function Game:getOwnedItemOptions()
	local ownedOptions = {}
	for _, itemOption in ipairs(self.itemOptions) do
		if containsValue(self.ownedItemIds, itemOption.id) then
			ownedOptions[#ownedOptions + 1] = itemOption
		end
	end
	return ownedOptions
end

function Game:getCurrentPreviewItemIds()
	return self.pendingEquippedItemIds
end

function Game:updateCrankFloorSelection()
	if self.screenState ~= "closed_floor" then
		self.lastCrankStep = self.crankSystem:getValue()
		return
	end

	local currentCrankStep = self.crankSystem:getValue()
	local delta = currentCrankStep - self.lastCrankStep
	if delta == 0 then
		return
	end

	local minimumFloor = 0
	local maximumFloor = #self.gameData.floors

	self.currentFloorIndex = clamp(self.currentFloorIndex + delta, minimumFloor, maximumFloor)
	self.selectedDestinationFloor = self.currentFloorIndex
	self.lastCrankStep = currentCrankStep
	-- self.lastRunSummary = "Doors closed. Floor " .. tostring(self.currentFloorIndex)
end

function Game:toggleSelectionItem(selectionList, itemId, limit)
	if removeValue(selectionList, itemId) then
		return true
	end

	if #selectionList >= limit then
		return false
	end

	selectionList[#selectionList + 1] = itemId
	return true
end

function Game:confirmStartingInventory()
	self.ownedItemIds = {}
	for _, itemId in ipairs(self.selectedStartingItemIds) do
		self.ownedItemIds[#self.ownedItemIds + 1] = itemId
	end

	self.pendingEquippedItemIds = {}
	self.screenState = "closed_floor"
	self.selectedDestinationFloor = 1
	self.lastCrankStep = self.crankSystem:getValue()
	self.lastRunSummary = "Rotate crank to move upstairs."
end

function Game:openFloorItemSelection()
	if #self.pendingEquippedItemIds == 0 then
		self.pendingEquippedItemIds = {}
	end
	self.floorItemSelectionIndex = 1
	self.screenState = "item_select"
	self.lastRunSummary = "Select up to 2 items, then press B to confirm"
end

function Game:closeFloorItemSelection()
	self.screenState = "character_select"
	self.lastRunSummary = "A selects items. B closes door."
end

function Game:moveToSelectedFloor()
	if self.currentFloorIndex >= #self.gameData.floors then
		self.lastRunSummary = "Run complete: all floors already resolved"
		return
	end

	local minimumFloor = 1
	if self.currentFloorIndex > 0 then
		minimumFloor = math.min(#self.gameData.floors, self.currentFloorIndex + 1)
	end
	local floorIndex = clamp(self.selectedDestinationFloor, minimumFloor, #self.gameData.floors)
	local floorType = self.floorGenerator:getFloorType(self.gameData, floorIndex)

	if self.currentFloorIndex == 0 then
		self.currentFloorIndex = floorIndex
		if DEBUG_MODE then
			self.lastChallengeDebugLines = {
				"Floor 0",
				"Safe staging floor",
				"No event triggered",
				"Arrived at floor " .. tostring(self.currentFloorIndex),
			}
		else
			self.lastChallengeDebugLines = {}
		end
		self.lastRunSummary = "Arrived at floor " .. tostring(self.currentFloorIndex)
		self.selectedDestinationFloor = clamp(self.currentFloorIndex + 1, 1, #self.gameData.floors)
		self.screenState = "character_select"
		return
	end
	self.lastRunSummary = "Moved to floor " .. tostring(self.currentFloorIndex)
end

function Game:updateCharacterSelection()
	if not self:isAnyCharacterAlive() then
		return
	end

	if pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonLeft) then
		repeat
			self.selectedCharacterIndex = self.selectedCharacterIndex - 1
			if self.selectedCharacterIndex < 1 then
				self.selectedCharacterIndex = #self.characterOptions
			end
		until self:getSelectedCharacter().alive
	elseif pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonRight) then
		repeat
			self.selectedCharacterIndex = self.selectedCharacterIndex + 1
			if self.selectedCharacterIndex > #self.characterOptions then
				self.selectedCharacterIndex = 1
			end
		until self:getSelectedCharacter().alive
	end
end

function Game:updateStartingLoadoutSelection()
	if pd.buttonJustPressed(pd.kButtonUp) then
		self.startingInventorySelectionIndex = self.startingInventorySelectionIndex - 1
		if self.startingInventorySelectionIndex < 1 then
			self.startingInventorySelectionIndex = #self.itemOptions
		end
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		self.startingInventorySelectionIndex = self.startingInventorySelectionIndex + 1
		if self.startingInventorySelectionIndex > #self.itemOptions then
			self.startingInventorySelectionIndex = 1
		end
	elseif pd.buttonJustPressed(pd.kButtonA) then
		local itemOption = self.itemOptions[self.startingInventorySelectionIndex]
		local changed = self:toggleSelectionItem(self.selectedStartingItemIds, itemOption.id, STARTING_ITEM_LIMIT)
		if not changed then
			self.lastRunSummary = "Starting loadout full"
		else
			--self.lastRunSummary = "Starting items: " .. joinItemNames(self.selectedStartingItemIds)
		end
	elseif pd.buttonJustPressed(pd.kButtonB) then
		self:confirmStartingInventory()
	end
end

function Game:updateFloorItemSelection()
	local ownedItemOptions = self:getOwnedItemOptions()
	if #ownedItemOptions == 0 then
		if pd.buttonJustPressed(pd.kButtonB) then
			self:resolveCurrentFloorEncounter()
		end
		if pd.buttonJustPressed(pd.kButtonLeft) then
			self:closeFloorItemSelection()
		end
		return
	end

	if pd.buttonJustPressed(pd.kButtonUp) then
		self.floorItemSelectionIndex = self.floorItemSelectionIndex - 1
		if self.floorItemSelectionIndex < 1 then
			self.floorItemSelectionIndex = #ownedItemOptions
		end
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		self.floorItemSelectionIndex = self.floorItemSelectionIndex + 1
		if self.floorItemSelectionIndex > #ownedItemOptions then
			self.floorItemSelectionIndex = 1
		end
	elseif pd.buttonJustPressed(pd.kButtonA) then
		local itemOption = ownedItemOptions[self.floorItemSelectionIndex]
		local changed = self:toggleSelectionItem(self.pendingEquippedItemIds, itemOption.id, FLOOR_EQUIP_LIMIT)
		if not changed then
			self.lastRunSummary = "Only 2 items can be equipped"
		else
			self.lastRunSummary = "Equipped: " .. joinItemNames(self.pendingEquippedItemIds)
		end
	elseif pd.buttonJustPressed(pd.kButtonB) then
		self:resolveCurrentFloorEncounter()
	elseif pd.buttonJustPressed(pd.kButtonLeft) then
		self:closeFloorItemSelection()
	end
end

function Game:updateLootSelection()
	if #self.currentLootItems == 0 then
		self.screenState = "character_select"
		return
	end

	local allItemIds = {}
	local seen = {}
	for _, itemId in ipairs(self.currentLootItems) do
		if not seen[itemId] then
			allItemIds[#allItemIds + 1] = itemId
			seen[itemId] = true
		end
	end

	if pd.buttonJustPressed(pd.kButtonUp) then
		self.lootSelectionIndex = self.lootSelectionIndex - 1
		if self.lootSelectionIndex < 1 then
			self.lootSelectionIndex = #allItemIds
		end
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		self.lootSelectionIndex = self.lootSelectionIndex + 1
		if self.lootSelectionIndex > #allItemIds then
			self.lootSelectionIndex = 1
		end
	elseif pd.buttonJustPressed(pd.kButtonA) then
		local itemId = allItemIds[self.lootSelectionIndex]
		if containsValue(self.selectedLootItemIds, itemId) then
			removeValue(self.selectedLootItemIds, itemId)
		else
			if #self.selectedLootItemIds >= 2 then
				self.lastRunSummary = "Can only carry 2 items"
			else
				self.selectedLootItemIds[#self.selectedLootItemIds + 1] = itemId
			end
		end
	elseif pd.buttonJustPressed(pd.kButtonB) then
		self.ownedItemIds = {}
		for _, itemId in ipairs(self.selectedLootItemIds) do
			self.ownedItemIds[#self.ownedItemIds + 1] = itemId
		end
		local kept = #self.selectedLootItemIds
		self.currentLootItems = {}
		self.selectedLootItemIds = {}
		self.screenState = "character_select"
		if kept > 0 then
			self.lastRunSummary = "Kept " .. kept .. " item(s), dropped the rest"
		else
			self.lastRunSummary = "Dropped all items"
		end
	end
end

function Game:drawSelectableItemList(title, itemOptions, selectedItemIds, selectedIndex, panelX, panelY, panelWidth, footerLines)
	local lineHeight = 16
	local panelHeight = 22 + (#itemOptions * lineHeight) + (#footerLines * lineHeight) + 8

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(panelX, panelY, panelWidth, panelHeight)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(panelX, panelY, panelWidth, panelHeight)

	local y = panelY + 8
	gfx.drawText(title, panelX + 8, y)
	y = y + lineHeight

	for index, itemOption in ipairs(itemOptions) do
		local cursor = "  "
		if index == selectedIndex then
			cursor = "> "
		end

		local marker = "[ ] "
		if containsValue(selectedItemIds, itemOption.id) then
			marker = "[x] "
		end

		gfx.drawText(cursor .. marker .. itemOption.name, panelX + 8, y)
		y = y + lineHeight
	end

	for _, footerLine in ipairs(footerLines) do
		gfx.drawText(footerLine, panelX + 8, y)
		y = y + lineHeight
	end
end

function Game:drawStartingLoadoutUi()
	self:drawSelectableItemList(
		"Choose starting items",
		self.itemOptions,
		self.selectedStartingItemIds,
		self.startingInventorySelectionIndex,
		20,
		24,
		180,
		{
			"A = toggle item",
			"B = start run",
			"Limit: " .. tostring(STARTING_ITEM_LIMIT),
		}
	)

	-- gfx.drawText("Owned at start: " .. joinItemNames(self.selectedStartingItemIds), 20, 156)
	gfx.drawText(self.lastRunSummary, 20, 174)
end

function Game:drawFloorEquipUi()
	local ownedItemOptions = self:getOwnedItemOptions()
	local footerLines = {
		"A = toggle item",
		"B = confirm and resolve",
		"Left = back",
		"Limit: " .. tostring(FLOOR_EQUIP_LIMIT),
	}

	if #ownedItemOptions == 0 then
		ownedItemOptions = { { id = "none", name = "No items owned" } }
		footerLines = {
			"B = resolve with no items",
			"Left = back",
		}
	end

	self:drawSelectableItemList(
		"Equip for floor " .. tostring(self.currentFloorIndex),
		ownedItemOptions,
		self.pendingEquippedItemIds,
		self.floorItemSelectionIndex,
		20,
		24,
		180,
		footerLines
	)
	if DEBUG_MODE then
	local selectedCharacter = self:getSelectedCharacter()
		if selectedCharacter then
			local floorType = self.floorGenerator:getFloorType(self.gameData, self.currentFloorIndex)
			local preview = self.floorChallengeSystem:getFloorPreview(floorType, selectedCharacter, self.pendingEquippedItemIds)
			gfx.drawText("Character: " .. selectedCharacter.name, 20, 172)
			gfx.drawText("Floor: " .. tostring(floorType), 20, 188)
			gfx.drawText("Chance: " .. tostring(preview.chance) .. "%", 20, 204)
			gfx.drawText("Items: " .. joinItemNames(self.pendingEquippedItemIds), 20, 220)
		end
	else
		self.lastChallengeDebugLines = {}
	end
end

function Game:drawFloorValueDebugPanel()
	local selectedCharacter = self:getSelectedCharacter()
	if not selectedCharacter then
		return
	end

	local panelX = 200
	local panelY = 8
	local panelWidth = 192
	local panelHeight = 224
	local lineHeight = 14

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(panelX, panelY, panelWidth, panelHeight)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(panelX, panelY, panelWidth, panelHeight)

	local y = panelY + 8
	--gfx.drawText("Floor values (" .. selectedCharacter.name .. ")", panelX + 6, y)
	gfx.drawText("Debug mode", panelX + 6, y)
	y = y + lineHeight

	local startFloor = math.max(0, self.currentFloorIndex - 1)
	local maxVisible = 8
	local endFloor = math.min(#self.gameData.floors, startFloor + maxVisible - 1)
	local previewItemIds = self:getCurrentPreviewItemIds()

	for floorNumber = startFloor, endFloor do
		local floorType = self.floorGenerator:getFloorType(self.gameData, floorNumber)
		local preview = self.floorChallengeSystem:getFloorPreview(floorType, selectedCharacter, previewItemIds)

		local marker = " "
		if floorNumber == self.currentFloorIndex then
			marker = ">"
		end

		local floorLine = string.format("%s%02d %-10s %2d%%", marker, floorNumber, floorType, preview.chance)
		gfx.drawText(floorLine, panelX + 6, y)
		y = y + lineHeight
	end

	y = y + 4
	gfx.drawText("Last calc:", panelX + 6, y)
	y = y + lineHeight

	for _, line in ipairs(self.lastChallengeDebugLines) do
		if y > panelY + panelHeight - lineHeight then
			break
		end
		gfx.drawText(line, panelX + 6, y)
		y = y + lineHeight
	end
end

function Game:drawLootSelectionUi()
	local lootOptions = {}
	local seen = {}
	for _, itemId in ipairs(self.currentLootItems) do
		if not seen[itemId] then
			lootOptions[#lootOptions + 1] = { id = itemId, name = itemId:gsub("_", " "), isNew = true }
			seen[itemId] = true
		end
	end

	local panelHeight = 22 + (#lootOptions * 16) + (4 * 16) + 8

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(60, 24, 280, panelHeight)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(60, 24, 280, panelHeight)

	local y = 32
	gfx.drawText("Select up to 2 items to keep:", 68, y)
	y = y + 16

	for index, itemOption in ipairs(lootOptions) do
		local cursor = "  "
		if index == self.lootSelectionIndex then
			cursor = "> "
		end

		local marker = "[ ] "
		if containsValue(self.selectedLootItemIds, itemOption.id) then
			marker = "[x] "
		end

		gfx.drawText(cursor .. marker .. itemOption.name, 68, y)
		y = y + 16
	end

	gfx.drawText("A = toggle item", 68, y)
	y = y + 16
	gfx.drawText("B = confirm selection", 68, y)
	y = y + 16
	gfx.drawText("Unselected items will be lost", 68, y)
	y = y + 16
	gfx.drawText("Carrying: " .. #self.selectedLootItemIds .. "/2", 68, y)

	gfx.drawText(self.lastRunSummary, 20, 200)
end

function Game:drawCharacterSelectionUi()
	local centerX = 200
	local carouselY = 55

	local carouselSlots = {
		{ offset = -2, size = 36, x = 18, y = carouselY + 22 },
		{ offset = -1, size = 52, x = 85, y = carouselY + 12 },
		{ offset =  0, size = 80, x = 160, y = carouselY },
		{ offset =  1, size = 52, x = 263, y = carouselY + 12 },
		{ offset =  2, size = 36, x = 346, y = carouselY + 22 },
	}

	local totalChars = #self.characterOptions

	for _, slot in ipairs(carouselSlots) do
		local charIndex = self.selectedCharacterIndex + slot.offset

		while charIndex < 1 do
			charIndex = charIndex + totalChars
		end
		while charIndex > totalChars do
			charIndex = charIndex - totalChars
		end

		local characterId = self.characterOptions[charIndex]
		local character = self.characters[characterId]
		local charImage = self.images.characters[characterId]

		local drawX = slot.x
		local drawY = slot.y
		local size = slot.size

		if charImage then
			local imgWidth, imgHeight = charImage:getSize()
			local scaleX = size / imgWidth
			local scaleY = size / imgHeight

			if not character.alive then
				gfx.pushContext()
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
				charImage:drawScaled(drawX, drawY, scaleX, scaleY)
				gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
				gfx.setDitherPattern(0.5)
				gfx.fillRect(drawX, drawY, size, size)
				gfx.setImageDrawMode(gfx.kDrawModeCopy)
				gfx.popContext()
			else
				charImage:drawScaled(drawX, drawY, scaleX, scaleY)
			end
		else
			gfx.setColor(gfx.kColorWhite)
			gfx.fillRect(drawX, drawY, size, size)
			gfx.setColor(gfx.kColorBlack)
			gfx.drawRect(drawX, drawY, size, size)
			drawCenteredText(character.name, drawX + (size / 2), drawY + (size / 2) - 4)
		end

		if slot.offset == 0 then
			gfx.setColor(gfx.kColorBlack)
			gfx.setLineWidth(2)
			gfx.drawRect(drawX - 2, drawY - 2, size + 4, size + 4)
			gfx.setLineWidth(1)
		end

		local nameY = drawY + size + 4
		local nameColor = character.alive and gfx.kColorBlack or gfx.kColorWhite
		gfx.setColor(nameColor)
		drawCenteredText(character.name, drawX + (size / 2), nameY)

		if not character.alive then
			drawCenteredText("DEAD", drawX + (size / 2), nameY + 12)
		end
	end

	local infoY = 178
	local lineHeight = 16

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(10, infoY - 4, 380, 62)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(10, infoY - 4, 380, 62)

	gfx.drawText("Floor: " .. tostring(self.currentFloorIndex) .. "/" .. tostring(#self.gameData.floors), 20, infoY)
	gfx.drawText("Items: " .. joinItemNames(self.ownedItemIds), 20, infoY + lineHeight)
	gfx.drawText(self.lastRunSummary, 20, infoY + lineHeight * 2)

	gfx.drawText("A = equip items", 240, infoY)
	gfx.drawText("B = close door", 240, infoY + lineHeight)
	gfx.drawText("< > switch character", 240, infoY + lineHeight * 2)

	if DEBUG_MODE then
		self:drawFloorValueDebugPanel()
	end
end

function Game:drawGameOverUi()
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(40, 52, 320, 152)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(40, 52, 320, 152)

	drawCenteredText("GAME OVER", 200, 72)
	drawCenteredText("All family members are dead", 200, 96)
	drawCenteredText("Run ended on floor " .. tostring(self.currentFloorIndex), 200, 112)
	drawCenteredText("No survivors remain", 200, 136)

	if DEBUG_MODE then
		local y = 168
		for _, line in ipairs(self.lastChallengeDebugLines) do
			drawCenteredText(line, 200, y)
			y = y + 16
		end
	end

	drawCenteredText("Press A or B to restart", 200, 186)
end

function Game:drawResultCutsceneUi()
	-- Strong visual frame so the transition reads as a cutscene.
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(24, 36, 352, 170)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(24, 36, 352, 170)

	drawCenteredText("Encounter Result", 200, 64)

	local y = 92
	for _, line in ipairs(self.cutsceneLines) do
		drawCenteredText(line, 200, y)
		y = y + 18
	end

	if self.cutsceneHoldTimer <= 0 then
		drawCenteredText("Press A/B to continue", 200, 196)
	else
		drawCenteredText("...", 200, 196)
	end
end

function Game:drawExitLockedUi()
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(24, 52, 352, 120)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(24, 52, 352, 120)

	drawCenteredText("EXIT LOCKED", 200, 72)
	drawCenteredText("You need the Exit Key", 200, 96)
	drawCenteredText("to unlock this door.", 200, 112)
	drawCenteredText("Press A/B to go back", 200, 148)
end

function Game:drawVictoryUi()
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(24, 36, 352, 170)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(24, 36, 352, 170)

	drawCenteredText("YOU WIN!", 200, 64)
	drawCenteredText("You escaped the building!", 200, 96)
	drawCenteredText("Floor " .. tostring(self.currentFloorIndex), 200, 116)
	drawCenteredText(self.lastRunSummary, 200, 140)
	drawCenteredText("Press A/B to play again", 200, 176)
end

-- function Game:drawFloorIndicator()
--     local boxWidth = 140
--     local boxHeight = 36
--     local boxX = 200 - (boxWidth / 2)  -- Center horizontally
--     local boxY = 0

--     -- Draw white rectangle with border
--     gfx.setColor(gfx.kColorWhite)
--     gfx.fillRect(boxX, boxY, boxWidth, boxHeight)
--     gfx.setColor(gfx.kColorBlack)
--     gfx.drawRect(boxX, boxY, boxWidth, boxHeight)

--     -- Draw floor text centered
--     local floorText = "Floor: " .. tostring(self.currentFloorIndex) .. "/" .. tostring(#self.gameData.floors)
--     drawCenteredText(floorText, 200, boxY)
-- end

function Game:update()
	self.crankSystem:update(pd.getCrankChange())
	self:updateCrankFloorSelection()

	if self.screenState == "starting_loadout" then
		self:updateStartingLoadoutSelection()
	elseif self.screenState == "closed_floor" then
		if pd.buttonJustPressed(pd.kButtonB) then
			self.screenState = "character_select"
			self.lastRunSummary = "Doors opened at floor " .. tostring(self.currentFloorIndex)
		end
	elseif self.screenState == "item_select" then
		self:updateFloorItemSelection()
	elseif self.screenState == "result_cutscene" then
		self:updateResultCutscene()
	elseif self.screenState == "loot_select" then
		self:updateLootSelection()
	elseif self.screenState == "exit_locked" then
		if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
			self.screenState = "character_select"
			self.selectedDestinationFloor = clamp(self.currentFloorIndex + 1, 0, #self.gameData.floors)
		end
	elseif self.screenState == "victory" then
		if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
			self:restartGame()
		end
	elseif self.screenState == "game_over" then
		if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
			self:restartGame()
		end
		return
	elseif self.screenState == "character_select" then
		self:updateCharacterSelection()
		if pd.buttonJustPressed(pd.kButtonA) then
			self:openFloorItemSelection()
		elseif pd.buttonJustPressed(pd.kButtonB) then
			self.screenState = "closed_floor"
			self.selectedDestinationFloor = self.currentFloorIndex
			self.lastCrankStep = self.crankSystem:getValue()
		end
	end
end

function Game:draw()
	gfx.clear(gfx.kColorWhite)

	local backgroundToDraw = self.images.alternateBackground
	if self.screenState == "starting_loadout" or self.screenState == "closed_floor" or self.screenState == "result_cutscene" or self.screenState == "loot_select" or self.screenState == "exit_locked" or self.screenState == "victory" then
		backgroundToDraw = self.images.defaultBackground
	end

	if backgroundToDraw then
		backgroundToDraw:draw(0, 0)
	end

	local boxWidth = 50
	local boxHeight = 16
	local boxX = self.numberX - (boxWidth / 2)
	local boxY = 40

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(boxX, boxY, boxWidth, boxHeight)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(boxX, boxY, boxWidth, boxHeight)

	gfx.setColor(gfx.kColorBlack)
	drawCenteredText(tostring(self.currentFloorIndex), self.numberX, 40)

	if self.screenState == "starting_loadout" then
		self:drawStartingLoadoutUi()
	elseif self.screenState == "item_select" then
		self:drawFloorEquipUi()
	elseif self.screenState == "result_cutscene" then
		self:drawResultCutsceneUi()
	elseif self.screenState == "loot_select" then
		self:drawLootSelectionUi()
	elseif self.screenState == "exit_locked" then
		self:drawExitLockedUi()
	elseif self.screenState == "victory" then
		self:drawVictoryUi()
	elseif self.screenState == "game_over" then
		self:drawGameOverUi()
	elseif self.screenState == "character_select" then
		self:drawCharacterSelectionUi()
	end
end
