import "CoreLibs/graphics"
import "core/game_utilities"
import "core/build_flags"
import "assets/images"

UIRenderer = {}
UIRenderer.__index = UIRenderer

-- === UI LAYOUT MANAGER ===

UILayoutManager = {}
UILayoutManager.__index = UILayoutManager

function UILayoutManager.new()
	local self = setmetatable({}, UILayoutManager)
	self.elements = {} -- list of {x, y, width, height, priority, adjustedX, adjustedY}
	return self
end

function UILayoutManager:addElement(x, y, width, height, priority)
	local element = {x = x, y = y, width = width, height = height, priority = priority or 0}
	table.insert(self.elements, element)
	
	-- Resolve collisions and adjust positions
	self:resolveCollisions()
	
	-- Return the adjusted position
	return element.adjustedX or x, element.adjustedY or y
end

function UILayoutManager:resolveCollisions()
	-- Sort elements by priority (higher priority elements are positioned first and don't move)
	table.sort(self.elements, function(a, b) return a.priority > b.priority end)
	
	-- For each element, starting from highest priority, check against already positioned elements
	for i, elem in ipairs(self.elements) do
		elem.adjustedX = elem.x
		elem.adjustedY = elem.y
		
		-- Check against all higher priority elements (already positioned)
		for j = 1, i - 1 do
			local other = self.elements[j]
			if self:rectsOverlap(elem.adjustedX, elem.adjustedY, elem.width, elem.height,
							   other.adjustedX, other.adjustedY, other.width, other.height) then
				-- Simple repositioning: move down by the height of the overlapping element + margin
				elem.adjustedY = other.adjustedY + other.height + 4
			end
		end
	end
end

function UILayoutManager:rectsOverlap(x1, y1, w1, h1, x2, y2, w2, h2)
	return x1 < x2 + w2 and x2 < x1 + w1 and y1 < y2 + h2 and y2 < y1 + h1
end

function UILayoutManager:clear()
	self.elements = {}
end

local gfx = playdate.graphics

function UIRenderer.new(game)
	local self = setmetatable({}, UIRenderer)
	self.game = game
	self.layoutManager = UILayoutManager.new()
	return self
end

-- === 3D EFFECT HELPERS ===

-- Draw image with simulated Y-axis rotation (3D perspective)
-- rotationY: -1 to 1 (negative = rotated left/away, positive = rotated right/away)
function UIRenderer:drawRotatedImage3D(image, x, y, width, height, rotationY)
	if not image then return end
	
	local imgWidth, imgHeight = image:getSize()
	
	if rotationY == 0 then
		-- No rotation, draw normally
		image:draw(x + (width - imgWidth) / 2, y + (height - imgHeight) / 2)
		return
	end
	
	-- Create skewing effect for 3D rotation around Y-axis
	-- More negative rotationY = more compressed from left side
	-- More positive rotationY = more compressed from right side
	
	local compressionAmount = math.abs(rotationY) * 0.5  -- Max 50% compression
	local scaledWidth = imgWidth * (1 - compressionAmount)
	
	gfx.pushContext()
	
	-- Draw the image smaller horizontally to simulate turned-away perspective
	local drawX = x + (width - scaledWidth) / 2
	local drawY = y + (height - imgHeight) / 2
	
	-- Adjust horizontal position based on rotation direction
	if rotationY < 0 then
		-- Rotated left (away) - push image to the right
		drawX = drawX + (width * math.abs(rotationY) * 0.2)
	else
		-- Rotated right (away) - push image to the left
		drawX = drawX - (width * rotationY * 0.2)
	end
	
	-- Draw compressed image
	image:draw(drawX, drawY)
	
	-- Add shading overlay to enhance 3D effect
	local shadeAlpha = math.abs(rotationY) * 0.3  -- 0 to 30% opacity
	gfx.setColor(gfx.kColorBlack)
	gfx.setDitherPattern(shadeAlpha)
	gfx.fillRect(x, y, width, height)
	
	gfx.popContext()
end

-- === REUSABLE COMPONENTS ===

-- Draw a custom radio button graphic at the specified position
-- Returns the width of the drawn radio button
function UIRenderer:drawRadioButton(x, y, isSelected)
	local radius = 4
	local size = radius * 2 + 1
	
	-- Draw outer circle (border)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(x, y, size, size)
	
	-- Draw inner circle
	if isSelected then
		-- Selected: fill with black dot
		gfx.fillRect(x + 2, y + 2, size - 4, size - 4)
	else
		-- Unselected: fill with white
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(x + 1, y + 1, size - 2, size - 2)
		gfx.setColor(gfx.kColorBlack)
	end
	
	return size + 2  -- Return width including spacing
end

-- Custom high-quality image scaling that maintains aspect ratio
function UIRenderer:scaleImageToFit(image, availableWidth, availableHeight, preserveAspectRatio)
	local imgWidth, imgHeight = image:getSize()
	
	if preserveAspectRatio then
		-- Calculate scale that fits both dimensions while maintaining aspect ratio
		local scaleX = availableWidth / imgWidth
		local scaleY = availableHeight / imgHeight
		local finalScale = math.min(scaleX, scaleY)
		
		-- Prevent upscaling beyond original size
		if finalScale > 1.0 then finalScale = 1.0 end
		
		local scaledWidth = imgWidth * finalScale
		local scaledHeight = imgHeight * finalScale
		
		return finalScale, scaledWidth, scaledHeight
	else
		-- Allow stretching to fill space (current behavior for frames)
		local scaleX = availableWidth / imgWidth
		local scaleY = availableHeight / imgHeight
		
		return scaleX, availableWidth, availableHeight
	end
end

function UIRenderer:drawSelectableItemList(title, itemOptions, selectedItemIds, selectedIndex, panelX, panelY, panelWidth, footerLines)
	local lineHeight = 16
	local maxVisibleItems = 8 -- Maximum items to show before needing to scroll
	local actualItemsCount = math.min(#itemOptions, maxVisibleItems)
	local panelHeight = 22 + (actualItemsCount * lineHeight) + (#footerLines * lineHeight) + 8

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(panelX, panelY, panelWidth, panelHeight)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(panelX, panelY, panelWidth, panelHeight)

	local y = panelY + 8
	gfx.drawText(title, panelX + 8, y)
	y = y + lineHeight

	-- Calculate scroll offset to keep selected item visible
	local selectedListIndex = selectedIndex
	for i, opt in ipairs(itemOptions) do
		if opt.selectableIndex == selectedIndex then
			selectedListIndex = i
			break
		end
	end

	local scrollOffset = 0
	if selectedListIndex > maxVisibleItems then
		scrollOffset = selectedListIndex - maxVisibleItems
	end

	for index, itemOption in ipairs(itemOptions) do
		-- Skip items that are above the scroll offset
		if index > scrollOffset and index <= scrollOffset + maxVisibleItems then
			if itemOption.isHeader then
				gfx.drawText(itemOption.name, panelX + 8, y)
			else
				local cursor = "  "
				local currentSelectableIndex = itemOption.selectableIndex or index
				if currentSelectableIndex == selectedIndex then
					cursor = "> "
				end

				local isSelected = containsValue(selectedItemIds, itemOption.id)
				
				-- Draw text with cursor
				gfx.drawText(cursor, panelX + 8, y)
				
				-- Draw radio button graphic
				local radioBtnX = panelX + 24
				local radioBtnY = y + 3  -- Adjusted for better vertical alignment
				self:drawRadioButton(radioBtnX, radioBtnY, isSelected)
				
				-- Draw item name
				gfx.drawText(itemOption.name, radioBtnX + 15, y)
			end
			y = y + lineHeight
		end
	end

	for _, footerLine in ipairs(footerLines) do
		gfx.drawText(footerLine, panelX + 8, y)
		y = y + lineHeight
	end
end

function UIRenderer:drawTutorialBanner(text, yPos, style)
	local lines = wrapText(text, 360)
	local lineHeight = style == "compact" and 12 or 14  -- Compact for side banners
	local padding = 4
	local boxHeight = (#lines * lineHeight) + (padding * 2)
	
	local startY, startX, boxWidth
	
	if style == "right" then
		-- Right side banner - narrower and positioned on right
		boxWidth = 160  -- Narrower for right side
		startX = 400 - boxWidth - 4  -- Right side with margin
		startY = 60  -- Middle-ish height
		lines = wrapText(text, boxWidth - 20)  -- Re-wrap for narrower box
		boxHeight = (#lines * lineHeight) + (padding * 2)
	elseif style == "large" then
		-- Large centered banner for screens with no UI
		boxWidth = 360
		startX = 20
		startY = math.floor((240 - boxHeight) / 2)  -- Center vertically
		lines = wrapText(text, boxWidth - 20)
		boxHeight = (#lines * lineHeight) + (padding * 2)
	else
		-- Bottom banner (default)
		boxWidth = 400
		startX = 0
		startY = 240 - boxHeight - 4  -- Bottom with small margin
	end

	-- Use layout manager to prevent overlaps (high priority for tutorials)
	local adjustedX, adjustedY = self.layoutManager:addElement(startX, startY, boxWidth, boxHeight, 10)

	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(adjustedX, adjustedY, boxWidth, boxHeight)
	gfx.setColor(gfx.kColorWhite)
	gfx.drawRect(adjustedX, adjustedY, boxWidth, boxHeight)
	
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	local textY = adjustedY + padding
	local centerX = adjustedX + (boxWidth / 2)
	for i, line in ipairs(lines) do
		drawCenteredText(line, centerX, textY + (i - 1) * lineHeight)
	end
	
	gfx.setImageDrawMode(gfx.kDrawModeCopy)
	gfx.setColor(gfx.kColorBlack) -- Reset color
end

-- === SCREEN RENDERERS ===

function UIRenderer:drawMainMenuScreen()
	local uiState = self.game.uiState
	
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(40, 40, 320, 160)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(40, 40, 320, 160)

	drawCenteredText("ELEVATOR ESCAPE", 200, 60)
	
	local y = 90
	local lineHeight = 20
	local options = {
		"Start Game",
		"Difficulty: ",
		"Tutorials: ",
	}
	
	local difficultyText = "Easy (30 Floors)"
	local diffLevel = uiState:getDifficultyLevel()
	if diffLevel == 2 then
		difficultyText = "Medium (50 Floors)"
	elseif diffLevel == 3 then
		difficultyText = "Hard (100 Floors)"
	end
	options[2] = options[2] .. "< " .. difficultyText .. " >"
	
	local selectedIndex = uiState:getSelectionIndex("main_menu")
	
	for i, opt in ipairs(options) do
		local prefix = (i == selectedIndex) and "> " or "  "
		gfx.drawText(prefix .. opt, 60, y)
		
		-- Draw radio button for tutorials option
		if i == 3 then
			self:drawRadioButton(155, y + 2, uiState:isTutorialEnabled())
		end
		
		y = y + lineHeight
	end
	
	drawCenteredText("D-Pad to navigate/change. A to select.", 200, 170)
end

function UIRenderer:drawStartingLoadoutScreen()
	local game = self.game
	local inventory = game.inventory
	local uiState = game.uiState
	
	self:drawSelectableItemList(
		"Choose starting items",
		inventory.startingItemOptions,
		inventory.selectedStartingItemIds,
		uiState:getSelectionIndex("starting_loadout"),
		20,
		24,
		180,
		{
			"A = toggle item",
			"B = start run",
			"Limit: 3",
		}
	)

	gfx.drawText(uiState:getSummary(), 20, 174)
end

function UIRenderer:drawCharacterSelectionScreen()
	local game = self.game
	local uiState = game.uiState
	
	local selectedCharIndex = uiState:getSelectionIndex("character_select")
	local totalChars = #game.characterOptions
	
	-- Simple horizontal layout for 4 character boxes
	local boxWidth = 80
	local boxHeight = 100
	local spacing = 20
	local totalWidth = 4 * boxWidth + 3 * spacing
	local startX = (400 - totalWidth) / 2  -- Center the layout
	local startY = 80
	
	for i = 1, totalChars do
		local charIndex = i
		local characterId = game.characterOptions[charIndex]
		local character = game.characters[characterId]
		local charImage = game.images.characters[characterId]
		
		local boxX = startX + (i - 1) * (boxWidth + spacing)
		local boxY = startY
		
		-- Draw box background
		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(boxX, boxY, boxWidth, boxHeight)
		gfx.setColor(gfx.kColorBlack)
		
		-- Thicker border for selected
		if charIndex == selectedCharIndex then
			gfx.setLineWidth(3)
		else
			gfx.setLineWidth(1)
		end
		gfx.drawRect(boxX, boxY, boxWidth, boxHeight)
		gfx.setLineWidth(1)
		
		-- Draw character image if available, else name
		local imageY = boxY + 10
		if charImage then
			local imgWidth, imgHeight = charImage:getSize()
			local scale = math.min((boxWidth - 10) / imgWidth, (boxHeight - 40) / imgHeight)
			if scale > 1 then scale = 1 end
			local drawX = boxX + (boxWidth - imgWidth * scale) / 2
			local drawY = imageY
			charImage:drawScaled(drawX, drawY, scale)
		end
		
		-- Draw character name
		local nameY = boxY + boxHeight - 30
		gfx.drawText(character.name, boxX + 10, nameY)
		
		-- Draw status
		local statusY = nameY + 12
		if not character.alive then
			gfx.drawText("DEAD", boxX + 10, statusY)
		elseif character.sick then
			gfx.drawText("SICK", boxX + 10, statusY)
		elseif character.hurt then
			gfx.drawText("HURT", boxX + 10, statusY)
		elseif character.vaccinated then
			gfx.drawText("VACC", boxX + 10, statusY)
		end
	end

	local infoY = 200
	local lineHeight = 16

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(10, infoY - 4, 380, 40)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(10, infoY - 4, 380, 40)

	if self.cachedDialogueFloor ~= game.currentFloorIndex then
		local floorType = game.floorGenerator:getFloorType(game.gameData, game.currentFloorIndex)
		local isExplored = game.resolvedFloors[game.currentFloorIndex] == true
		local hint = getRandomHint(floorType, isExplored)
		local aliveNames = getAliveCharacterNames(game.characters, game.characterOptions)
		local speaker = aliveNames[math.random(1, #aliveNames)] or "???"
		self.cachedFloorDialogue = speaker .. ": \"" .. hint .. "\""
		self.cachedDialogueFloor = game.currentFloorIndex
	end

	local maxTextWidth = 360
	local lines = wrapText(self.cachedFloorDialogue, maxTextWidth)
	local startY = infoY

	for i, line in ipairs(lines) do
		gfx.drawText(line, 20, startY + (i - 1) * lineHeight)
		if startY + (i - 1) * lineHeight > infoY + 30 then
			break
		end
	end

	if DEBUG_MODE then
		self:drawFloorValueDebugPanel()
	end
end

function UIRenderer:drawFloorItemSelectionScreen()
	local game = self.game
	local inventory = game.inventory
	local uiState = game.uiState
	
	local ownedItemOptions = inventory:getOwnedItemOptions()
	local footerLines = {
		"A = toggle item",
		"B = confirm",
		"Left = back",
		"Limit: 2",
	}

	if DEBUG_MODE then
		gfx.drawText("DEBUG: Owned items: " .. #inventory.ownedItemIds, 20, 140)
		gfx.drawText("DEBUG: Owned options: " .. #ownedItemOptions, 20, 156)
		for i, itemId in ipairs(inventory.ownedItemIds) do
			gfx.drawText("  " .. i .. ": " .. itemId, 20, 172 + (i * 12))
		end
	end

	if #ownedItemOptions == 0 then
		ownedItemOptions = { { id = "none", name = "No items owned" } }
		footerLines = {
			"B = resolve with no items",
			"Left = back",
		}
	end

	self:drawSelectableItemList(
		"Equip for floor " .. tostring(game.currentFloorIndex),
		ownedItemOptions,
		inventory.pendingEquippedItemIds,
		uiState:getSelectionIndex("item_select"),
		20,
		24,
		180,
		footerLines
	)
	
	if DEBUG_MODE then
		local selectedCharacter = game:getSelectedCharacter()
		if selectedCharacter then
			local floorType = game.floorGenerator:getFloorType(game.gameData, game.currentFloorIndex)
			local preview = game.floorChallengeSystem:getFloorPreview(floorType, selectedCharacter, inventory.pendingEquippedItemIds)
			gfx.drawText("Character: " .. selectedCharacter.name, 20, 172)
			gfx.drawText("Floor: " .. tostring(floorType), 20, 188)
			gfx.drawText("Chance: " .. tostring(preview.chance) .. "%", 20, 204)
			gfx.drawText("Items: " .. joinItemNames(inventory.pendingEquippedItemIds), 20, 220)
		end
	end
end

function UIRenderer:drawFloorValueDebugPanel()
	local game = self.game
	local selectedCharacter = game:getSelectedCharacter()
	if not selectedCharacter then
		return
	end

	local panelX = 200
	local panelY = 8
	local panelWidth = 192
	local panelHeight = 224
	
	-- Use layout manager to prevent overlaps
	local adjustedX, adjustedY = self.layoutManager:addElement(panelX, panelY, panelWidth, panelHeight, 0) -- Low priority, moves if conflict
	
	local lineHeight = 14

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(adjustedX, adjustedY, panelWidth, panelHeight)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(adjustedX, adjustedY, panelWidth, panelHeight)

	local y = adjustedY + 8
	gfx.drawText("Debug mode", adjustedX + 6, y)
	y = y + lineHeight

	local startFloor = math.max(0, game.currentFloorIndex - 1)
	local maxVisible = 8
	local endFloor = math.min(#game.gameData.floors, startFloor + maxVisible - 1)
	local previewItemIds = game.inventory:getPreviewItemIds()

	for floorNumber = startFloor, endFloor do
		local floorType = game.floorGenerator:getFloorType(game.gameData, floorNumber)
		local preview = game.floorChallengeSystem:getFloorPreview(floorType, selectedCharacter, previewItemIds)

		local marker = " "
		if floorNumber == game.currentFloorIndex then
			marker = ">"
		end

		local keyIndicator = ""
		if floorNumber == game.gameData.exitKeyFloor then
			keyIndicator = " [KEY]"
		end

		local floorLine = string.format("%s%02d %-10s %2d%%%s", marker, floorNumber, floorType, preview.chance, keyIndicator)
		gfx.drawText(floorLine, adjustedX + 6, y)
		y = y + lineHeight
	end

	y = y + 4
	gfx.drawText("Last calc:", adjustedX + 6, y)
	y = y + lineHeight

	for _, line in ipairs(game.cutscene:getDebugLines()) do
		if y > adjustedY + panelHeight - lineHeight then
			break
		end
		gfx.drawText(line, adjustedX + 6, y)
		y = y + lineHeight
	end
end

function UIRenderer:drawItemCollectionScreen()
	local game = self.game
	local inventory = game.inventory
	local uiState = game.uiState
	
	local collectibleOptions = {}
	local seen = {}
	local selectableIndex = 1

	if #inventory.ownedItemIds > 0 then
		collectibleOptions[#collectibleOptions + 1] = { name = "--- Owned ---", isHeader = true }
		for _, itemId in ipairs(inventory.ownedItemIds) do
			if not seen[itemId] then
				collectibleOptions[#collectibleOptions + 1] = { id = itemId, name = itemId:gsub("_", " "), selectableIndex = selectableIndex }
				seen[itemId] = true
				selectableIndex = selectableIndex + 1
			end
		end
	end
	
	local foundNew = false
	for _, itemId in ipairs(inventory.currentCollectibleItems) do
		if not seen[itemId] then
			if not foundNew then
				collectibleOptions[#collectibleOptions + 1] = { name = "--- Found Items ---", isHeader = true }
				foundNew = true
			end
			collectibleOptions[#collectibleOptions + 1] = { id = itemId, name = itemId:gsub("_", " "), selectableIndex = selectableIndex }
			seen[itemId] = true
			selectableIndex = selectableIndex + 1
		end
	end

	if #collectibleOptions == 0 then
		return
	end

	self:drawSelectableItemList(
		"Inventory / Collectibles",
		collectibleOptions,
		inventory.selectedCollectibleItemIds,
		uiState:getSelectionIndex("item_collection"),
		20,
		24,
		360,
		{
			"A = toggle item",
			"B = confirm selection",
			"Capacity: " .. #inventory.selectedCollectibleItemIds .. "/" .. inventory.maxCollectibleCapacity,
		}
	)
end

function UIRenderer:drawLootSelectionScreen()
	local game = self.game
	local inventory = game.inventory
	local uiState = game.uiState
	
	local lootOptions = {}
	local seen = {}
	local selectableIndex = 1

	if #inventory.ownedItemIds > 0 then
		lootOptions[#lootOptions + 1] = { name = "--- Owned ---", isHeader = true }
		for _, itemId in ipairs(inventory.ownedItemIds) do
			if not seen[itemId] then
				lootOptions[#lootOptions + 1] = { id = itemId, name = itemId:gsub("_", " "), selectableIndex = selectableIndex }
				seen[itemId] = true
				selectableIndex = selectableIndex + 1
			end
		end
	end
	
	local foundNew = false
	for _, itemId in ipairs(inventory.currentLootItems) do
		if not seen[itemId] then
			if not foundNew then
				lootOptions[#lootOptions + 1] = { name = "--- Found Items ---", isHeader = true }
				foundNew = true
			end
			lootOptions[#lootOptions + 1] = { id = itemId, name = itemId:gsub("_", " "), selectableIndex = selectableIndex }
			seen[itemId] = true
			selectableIndex = selectableIndex + 1
		end
	end

	if #lootOptions == 0 then
		return
	end

	self:drawSelectableItemList(
		"Inventory / Loot",
		lootOptions,
		inventory.selectedLootItemIds,
		uiState:getSelectionIndex("loot_select"),
		20,
		24,
		360,
		{
			"A = toggle item",
			"B = confirm selection",
			"Capacity: " .. #inventory.selectedLootItemIds .. "/" .. inventory.maxCollectibleCapacity,
		}
	)
end

function UIRenderer:drawResultCutsceneScreen()
	self.game.cutscene:drawActive(gfx, self.game.images, self.game.uiState)
end

function UIRenderer:drawBackpackCutsceneScreen()
	self.game.cutscene:drawActive(gfx, self.game.images, self.game.uiState)
end

function UIRenderer:drawMedkitCutsceneScreen()
	self.game.cutscene:drawActive(gfx, self.game.images, self.game.uiState)
end

function UIRenderer:drawExitLockedScreen()
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(24, 52, 352, 120)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(24, 52, 352, 120)

	drawCenteredText("EXIT LOCKED", 200, 72)
	drawCenteredText("You need the Exit Key", 200, 96)
	drawCenteredText("to unlock this door.", 200, 112)
	drawCenteredText("Press A/B to go back", 200, 148)
end

function UIRenderer:drawGameOverScreen()
	local game = self.game
	
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(40, 52, 320, 152)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(40, 52, 320, 152)

	drawCenteredText("GAME OVER", 200, 72)
	drawCenteredText("All family members are dead", 200, 96)
	drawCenteredText("Run ended on floor " .. tostring(game.currentFloorIndex), 200, 112)
	drawCenteredText("No survivors remain", 200, 136)

	if DEBUG_MODE then
		local y = 168
		for _, line in ipairs(game.cutscene:getDebugLines()) do
			drawCenteredText(line, 200, y)
			y = y + 16
		end
	end

	drawCenteredText("Press A or B to restart", 200, 186)
end

function UIRenderer:drawVictoryScreen()
	local game = self.game
	
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(24, 36, 352, 170)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(24, 36, 352, 170)

	drawCenteredText("YOU WIN!", 200, 64)
	drawCenteredText("You escaped the building!", 200, 96)
	drawCenteredText("Floor " .. tostring(game.currentFloorIndex), 200, 116)
	drawCenteredText(game.uiState:getSummary(), 200, 140)
	drawCenteredText("Press A/B to play again", 200, 176)
end

-- === MAIN DISPATCHER ===

function UIRenderer:draw()
	gfx.clear(gfx.kColorWhite)
	
	-- Clear layout manager for new frame
	self.layoutManager:clear()

	local backgroundToDraw = self.game.images.alternateBackground
	local screenState = self.game.uiState:getScreenState()
	if screenState == "main_menu" or screenState == "starting_loadout" or screenState == "closed_floor" or screenState == "result_cutscene" or screenState == "loot_select" or screenState == "item_collection" or screenState == "exit_locked" or screenState == "victory" or screenState == "backpack_cutscene" or screenState == "medkit_cutscene" then
		backgroundToDraw = self.game.images.defaultBackground
	end

	if backgroundToDraw then
		backgroundToDraw:draw(0, 0)
	end

	if screenState ~= "main_menu" then
		local boxWidth = 50
		local boxHeight = 16
		local boxX = self.game.numberX - (boxWidth / 2)
		local boxY = 40

		gfx.setColor(gfx.kColorWhite)
		gfx.fillRect(boxX, boxY, boxWidth, boxHeight)
		gfx.setColor(gfx.kColorBlack)
		gfx.drawRect(boxX, boxY, boxWidth, boxHeight)
		gfx.setColor(gfx.kColorBlack)
		drawCenteredText(tostring(self.game.currentFloorIndex), self.game.numberX, 40)
	end

	if screenState == "main_menu" then
		self:drawMainMenuScreen()
	elseif screenState == "starting_loadout" then
		self:drawStartingLoadoutScreen()
	elseif screenState == "item_select" then
		self:drawFloorItemSelectionScreen()
	elseif screenState == "result_cutscene" then
		self:drawResultCutsceneScreen()
	elseif screenState == "backpack_cutscene" then
		self:drawBackpackCutsceneScreen()
	elseif screenState == "medkit_cutscene" then
		self:drawMedkitCutsceneScreen()
	elseif screenState == "item_collection" then
		self:drawItemCollectionScreen()
	elseif screenState == "loot_select" then
		self:drawLootSelectionScreen()
	elseif screenState == "exit_locked" then
		self:drawExitLockedScreen()
	elseif screenState == "victory" then
		self:drawVictoryScreen()
	elseif screenState == "game_over" then
		self:drawGameOverScreen()
	elseif screenState == "character_select" then
		self:drawCharacterSelectionScreen()
	end

	-- Tutorial banners
	if screenState == "starting_loadout" and not self.game.uiState:isTutorialShown("starting_loadout") then
		self:drawTutorialBanner("Welcome to the Elevator! Select up to 3 starting items. Use (A) to toggle (add/remove) items in your inventory, then press (B) to confirm.", nil, "right")
	elseif screenState == "closed_floor" and self.game.currentFloorIndex == 0 and not self.game.uiState:isTutorialShown("crank_up") then
		self:drawTutorialBanner("Use the Playdate Crank to move the elevator up to Floor 1, then press (B) to open the doors.", nil, "right")
	elseif screenState == "character_select" and self.game.currentFloorIndex > 0 and not self.game.uiState:isTutorialShown("character_select") then
		self:drawTutorialBanner("Read the hint below! Use the D-Pad to pick the best family member for the danger, then press (A).", nil, "right")
	elseif screenState == "item_select" and not self.game.uiState:isTutorialShown("item_select") then
		self:drawTutorialBanner("Equip items to boost survival chances. (A) to toggle, (B) to face the danger!", nil, "right")
	elseif screenState == "result_cutscene" and not self.game.uiState:isTutorialShown("results") then
		self:drawTutorialBanner("This shows your survival roll. Higher stats = better chances. Press (A/B) to continue.", nil, "large")
	elseif screenState == "item_collection" and not self.game.uiState:isTutorialShown("item_collection") then
		self:drawTutorialBanner("Items found! Select an item then choose an inventory slot to replace. (A) to select, (B) when done.", nil, "right")
	elseif screenState == "loot_select" and not self.game.uiState:isTutorialShown("loot_select") then
		self:drawTutorialBanner("Safe room found! Select up to 2 items to keep. You can swap old items for new ones. (A) toggles, (B) confirms.", nil, "right")
	end
end
