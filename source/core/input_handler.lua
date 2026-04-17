import "core/game_utilities"

InputHandler = {}
InputHandler.__index = InputHandler

local pd = playdate

function InputHandler.new(game)
	local self = setmetatable({}, InputHandler)
	self.game = game
	return self
end

-- === CRANK INPUT ===

function InputHandler:updateCrankFloorSelection()
	local game = self.game
	if game.uiState:getScreenState() ~= "closed_floor" then
		game.lastCrankStep = game.crankSystem:getValue()
		return
	end

	local currentCrankStep = game.crankSystem:getValue()
	local delta = currentCrankStep - game.lastCrankStep
	if delta == 0 then
		return
	end

	local minimumFloor = 0
	local maximumFloor = #game.gameData.floors

	game.currentFloorIndex = clamp(game.currentFloorIndex + delta, minimumFloor, maximumFloor)
	game.selectedDestinationFloor = game.currentFloorIndex
	game.lastCrankStep = currentCrankStep
end

-- === PER-SCREEN INPUT HANDLERS ===

function InputHandler:updateMainMenu()
	local uiState = self.game.uiState
	
	if pd.buttonJustPressed(pd.kButtonUp) then
		local idx = uiState:getSelectionIndex("main_menu") - 1
		if idx < 1 then idx = 3 end
		uiState:setSelectionIndex("main_menu", idx)
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		local idx = uiState:getSelectionIndex("main_menu") + 1
		if idx > 3 then idx = 1 end
		uiState:setSelectionIndex("main_menu", idx)
	elseif pd.buttonJustPressed(pd.kButtonLeft) then
		local idx = uiState:getSelectionIndex("main_menu")
		if idx == 2 then
			local diff = uiState:getDifficultyLevel() - 1
			if diff < 1 then diff = 3 end
			uiState:setDifficultyLevel(diff)
		end
	elseif pd.buttonJustPressed(pd.kButtonRight) then
		local idx = uiState:getSelectionIndex("main_menu")
		if idx == 2 then
			local diff = uiState:getDifficultyLevel() + 1
			if diff > 3 then diff = 1 end
			uiState:setDifficultyLevel(diff)
		end
	elseif pd.buttonJustPressed(pd.kButtonA) then
		local idx = uiState:getSelectionIndex("main_menu")
		if idx == 1 then
			self.game:startGame()
		elseif idx == 2 then
			local diff = uiState:getDifficultyLevel() + 1
			if diff > 3 then diff = 1 end
			uiState:setDifficultyLevel(diff)
		elseif idx == 3 then
			uiState:setTutorialEnabled(not uiState:isTutorialEnabled())
		end
	end
end

function InputHandler:updateStartingLoadoutSelection()
	local game = self.game
	local inventory = game.inventory
	local uiState = game.uiState
	
	if pd.buttonJustPressed(pd.kButtonUp) then
		local index = uiState:getSelectionIndex("starting_loadout") - 1
		if index < 1 then
			index = #inventory.startingItemOptions
		end
		uiState:setSelectionIndex("starting_loadout", index)
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		local index = uiState:getSelectionIndex("starting_loadout") + 1
		if index > #inventory.startingItemOptions then
			index = 1
		end
		uiState:setSelectionIndex("starting_loadout", index)
	elseif pd.buttonJustPressed(pd.kButtonA) then
		local itemOption = inventory.startingItemOptions[uiState:getSelectionIndex("starting_loadout")]
		inventory:toggleStartingItem(itemOption.id, 3)
	elseif pd.buttonJustPressed(pd.kButtonB) then
		game:confirmStartingInventory()
	end
end

function InputHandler:updateCharacterSelection()
	local game = self.game
	local uiState = game.uiState
	
	if not game:isAnyCharacterAlive() then
		return
	end

	if pd.buttonJustPressed(pd.kButtonUp) or pd.buttonJustPressed(pd.kButtonLeft) then
		repeat
			local index = uiState:getSelectionIndex("character_select") - 1
			if index < 1 then
				index = #game.characterOptions
			end
			uiState:setSelectionIndex("character_select", index)
		until game:getSelectedCharacter().alive
	elseif pd.buttonJustPressed(pd.kButtonDown) or pd.buttonJustPressed(pd.kButtonRight) then
		repeat
			local index = uiState:getSelectionIndex("character_select") + 1
			if index > #game.characterOptions then
				index = 1
			end
			uiState:setSelectionIndex("character_select", index)
		until game:getSelectedCharacter().alive
	elseif pd.buttonJustPressed(pd.kButtonA) then
		-- Open floor for item selection only if not already cleared
		if game.currentFloorIndex == 0 or game.resolvedFloors[game.currentFloorIndex] then
			uiState:setSummary("Floor already cleared. Use crank to move on.")
		else
			game:openFloorItemSelection()
		end
	elseif pd.buttonJustPressed(pd.kButtonB) then
		-- Close floor and go back to crank
		if game.currentFloorIndex > 0 then
			uiState:setTutorialShown("crank_up")
		end
		uiState:setScreenState("closed_floor")
		game.selectedDestinationFloor = game.currentFloorIndex
		game.lastCrankStep = game.crankSystem:getValue()
	end
end

function InputHandler:updateFloorItemSelection()
	local game = self.game
	local inventory = game.inventory
	local uiState = game.uiState
	
	local ownedItemOptions = inventory:getOwnedItemOptions()
	if #ownedItemOptions == 0 then
		if pd.buttonJustPressed(pd.kButtonB) then
			game:resolveCurrentFloorEncounter()
		end
		if pd.buttonJustPressed(pd.kButtonLeft) then
			game:closeFloorItemSelection()
		end
		return
	end

	if pd.buttonJustPressed(pd.kButtonUp) then
		local index = uiState:getSelectionIndex("item_select") - 1
		if index < 1 then
			index = #ownedItemOptions
		end
		uiState:setSelectionIndex("item_select", index)
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		local index = uiState:getSelectionIndex("item_select") + 1
		if index > #ownedItemOptions then
			index = 1
		end
		uiState:setSelectionIndex("item_select", index)
	elseif pd.buttonJustPressed(pd.kButtonA) then
		local itemOption = ownedItemOptions[uiState:getSelectionIndex("item_select")]
		local equipLimit = game.inventory.hasBackpackFound and 2 or 1
		inventory:toggleEquippedItem(itemOption.id, equipLimit)
	elseif pd.buttonJustPressed(pd.kButtonB) then
		game:resolveCurrentFloorEncounter()
	elseif pd.buttonJustPressed(pd.kButtonLeft) then
		game:closeFloorItemSelection()
	end
end

function InputHandler:updateItemCollection()
	local game = self.game
	local inventory = game.inventory
	local uiState = game.uiState
	
	if #inventory.currentCollectibleItems == 0 then
		uiState:setScreenState("character_select")
		return
	end

	if uiState:getScreenState() ~= "item_collection" then
		return
	end

	local allItemIds = {}
	local seen = {}
	for _, itemId in ipairs(inventory.ownedItemIds) do
		if not seen[itemId] then
			allItemIds[#allItemIds + 1] = itemId
			seen[itemId] = true
		end
	end
	for _, itemId in ipairs(inventory.currentCollectibleItems) do
		if not seen[itemId] then
			allItemIds[#allItemIds + 1] = itemId
			seen[itemId] = true
		end
	end

	if pd.buttonJustPressed(pd.kButtonUp) then
		local index = uiState:getSelectionIndex("item_collection") - 1
		if index < 1 then
			index = #allItemIds
		end
		uiState:setSelectionIndex("item_collection", index)
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		local index = uiState:getSelectionIndex("item_collection") + 1
		if index > #allItemIds then
			index = 1
		end
		uiState:setSelectionIndex("item_collection", index)
	elseif pd.buttonJustPressed(pd.kButtonA) then
		local itemId = allItemIds[uiState:getSelectionIndex("item_collection")]
		inventory:toggleCollectibleSelection(itemId)
	elseif pd.buttonJustPressed(pd.kButtonB) then
		-- Confirm selection and add to inventory
		inventory:confirmCollectibleSelection()
		game:closeItemCollection()
	end
end

function InputHandler:updateLootSelection()
	local game = self.game
	local inventory = game.inventory
	local uiState = game.uiState
	
	if #inventory.currentLootItems == 0 then
		uiState:setScreenState("character_select")
		return
	end

	local allItemIds = {}
	local seen = {}
	for _, itemId in ipairs(inventory.ownedItemIds) do
		if not seen[itemId] then
			allItemIds[#allItemIds + 1] = itemId
			seen[itemId] = true
		end
	end
	for _, itemId in ipairs(inventory.currentLootItems) do
		if not seen[itemId] then
			allItemIds[#allItemIds + 1] = itemId
			seen[itemId] = true
		end
	end

	if pd.buttonJustPressed(pd.kButtonUp) then
		local index = uiState:getSelectionIndex("loot_select") - 1
		if index < 1 then
			index = #allItemIds
		end
		uiState:setSelectionIndex("loot_select", index)
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		local index = uiState:getSelectionIndex("loot_select") + 1
		if index > #allItemIds then
			index = 1
		end
		uiState:setSelectionIndex("loot_select", index)
	elseif pd.buttonJustPressed(pd.kButtonA) then
		local itemId = allItemIds[uiState:getSelectionIndex("loot_select")]
		inventory:toggleLootSelection(itemId, inventory.maxCollectibleCapacity)
	elseif pd.buttonJustPressed(pd.kButtonB) then
		uiState:setTutorialShown("loot_select")
		local kept = #inventory.selectedLootItemIds
		inventory:confirmLootSelection()
		if kept > 0 then
			uiState:setSummary("Kept " .. kept .. " item(s), doors closed")
		else
			uiState:setSummary("Dropped all items, doors closed")
		end
		uiState:setScreenState("closed_floor")
		game.lastCrankStep = game.crankSystem:getValue()
	end
end

function InputHandler:updateResultCutscene()
	local game = self.game
	local cutscene = game.cutscene
	local uiState = game.uiState
	local inventory = game.inventory
	
	if cutscene:getHoldTimer() > 0 then
		cutscene:update()
		return
	end
	
	if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
		cutscene:skip()
	end

	cutscene:update()
	
	if not cutscene:isActive() then
		uiState:setTutorialShown("results")
		if uiState:getScreenState() ~= "game_over" then
			-- Only show item collection if character survived
			if cutscene:didFloorSurvive() then
				-- Check for collectible items on this floor
				local currentFloor = game.currentFloorIndex
				if game.gameData.collectibleByFloor and game.gameData.collectibleByFloor[currentFloor] and #game.gameData.collectibleByFloor[currentFloor] > 0 then
					inventory:setAvailableCollectibles(cloneList(game.gameData.collectibleByFloor[currentFloor]))
					game:openItemCollection()
				else
					uiState:setScreenState("closed_floor")
					game.lastCrankStep = game.crankSystem:getValue()
				end
			else
				-- Character died, go to closed_floor to select another character
				uiState:setScreenState("closed_floor")
				game.lastCrankStep = game.crankSystem:getValue()
			end
		end
	end
end

function InputHandler:updateClosedFloorSelection()
	local game = self.game
	local uiState = game.uiState
	
	if pd.buttonJustPressed(pd.kButtonB) then
		if game.currentFloorIndex > 0 then
			uiState:setTutorialShown("crank_up")
		end
		-- Play door open sound
		local doorOpenSound = pd.sound.sampleplayer.new("sound/door_open")
		if doorOpenSound then
			doorOpenSound:play()
		end
		uiState:setScreenState("character_select")
		uiState:setSummary("Doors opened at floor " .. tostring(game.currentFloorIndex))
	end
end

function InputHandler:updateBackpackCutsceneScreen()
	local game = self.game
	local uiState = game.uiState
	local cutscene = game.cutscene
	
	if cutscene:getHoldTimer() > 0 then
		return
	end
	
	if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
		cutscene:skip()
	end
	
	-- Wait for cutscene to finish, then show item collection if items remain
	if not cutscene:isActive() then
		if #game.inventory.currentCollectibleItems == 0 then
			-- No items to display, go back to closed_floor
			uiState:setScreenState("closed_floor")
			game.lastCrankStep = game.crankSystem:getValue()
			uiState:setSummary("No items to collect.")
		else
			-- Show item collection screen
			uiState:setScreenState("item_collection")
			uiState:setSummary("Select items to collect with A, then B to confirm.")
		end
	end
end

function InputHandler:updateMedkitCutsceneScreen()
	self:updateBackpackCutsceneScreen()
end

function InputHandler:updateExitLockedScreen()
	local uiState = self.game.uiState
	if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
		uiState:setScreenState("character_select")
		self.game.selectedDestinationFloor = clamp(
			self.game.currentFloorIndex + 1, 0, #self.game.gameData.floors
		)
	end
end

function InputHandler:updateGameOverOrVictory()
	if pd.buttonJustPressed(pd.kButtonA) or pd.buttonJustPressed(pd.kButtonB) then
		self.game:restartGame()
	end
end

-- === MAIN DISPATCHER ===

function InputHandler:update(screenState)
	-- Route input to appropriate handler based on screen state
	if screenState == "main_menu" then
		self:updateMainMenu()
	elseif screenState == "starting_loadout" then
		self:updateStartingLoadoutSelection()
	elseif screenState == "character_select" then
		self:updateCharacterSelection()
	elseif screenState == "closed_floor" then
		self:updateClosedFloorSelection()
	elseif screenState == "item_select" then
		self:updateFloorItemSelection()
	elseif screenState == "result_cutscene" then
		self:updateResultCutscene()
	elseif screenState == "backpack_cutscene" then
		self:updateBackpackCutsceneScreen()
	elseif screenState == "medkit_cutscene" then
		self:updateMedkitCutsceneScreen()
	elseif screenState == "item_collection" then
		self:updateItemCollection()
	elseif screenState == "loot_select" then
		self:updateLootSelection()
	elseif screenState == "exit_locked" then
		self:updateExitLockedScreen()
	elseif screenState == "game_over" or screenState == "victory" then
		self:updateGameOverOrVictory()
	end
end
