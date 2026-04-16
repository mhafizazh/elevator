import "CoreLibs/graphics"
import "core/game_utilities"
import "core/build_flags"
import "assets/images"

UIRenderer = {}
UIRenderer.__index = UIRenderer

local gfx = playdate.graphics

function UIRenderer.new(game)
	local self = setmetatable({}, UIRenderer)
	self.game = game
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

	gfx.setColor(gfx.kColorBlack)
	gfx.fillRect(startX, startY, boxWidth, boxHeight)
	gfx.setColor(gfx.kColorWhite)
	gfx.drawRect(startX, startY, boxWidth, boxHeight)
	
	gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
	local textY = startY + padding
	local centerX = startX + (boxWidth / 2)
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
	
	local screenCenterX = 200
	local carouselY = 50
	local spacing = 80  -- Distance between carousel items
	
	local totalChars = #game.characterOptions
	local selectedCharIndex = uiState:getSelectionIndex("character_select")
	
	-- Build carousel slots with proper 3D positioning
	local carouselSlots = {}
	for offset = -2, 2 do
		local isSelected = (offset == 0)
		local distance = math.abs(offset)
		
		-- X scale (squash) makes the card look turned
		local scaleX = isSelected and 1.0 or (0.5 + (0.05 * (2 - distance)))
		-- Y scale reduces slightly for distance
		local scaleY = isSelected and 1.0 or (0.85 + (0.05 * (2 - distance)))
		
		local posX = screenCenterX + (offset * spacing)
		local posY = carouselY + (distance * 8)
		
		local baseFrameSize = 90
		local frameWidth = baseFrameSize * scaleX
		local frameHeight = baseFrameSize * scaleY
		
		-- Y-squash for true 3D perspective (trapezoid effect)
		local yPerspective = 6 * distance
		local leftSquash = (offset > 0) and yPerspective or 0
		local rightSquash = (offset < 0) and yPerspective or 0
		
		table.insert(carouselSlots, {
			offset = offset,
			frameWidth = frameWidth,
			frameHeight = frameHeight,
			leftSquash = leftSquash,
			rightSquash = rightSquash,
			posX = posX,
			posY = posY,
			zDepth = -distance * 100,
			isSelected = isSelected
		})
	end
	
	-- Sort by Z-depth (render back to front)
	table.sort(carouselSlots, function(a, b) return a.zDepth < b.zDepth end)
	
	-- Render carousel items
	for _, slot in ipairs(carouselSlots) do
		local charIndex = selectedCharIndex + slot.offset
		
		while charIndex < 1 do
			charIndex = charIndex + totalChars
		end
		while charIndex > totalChars do
			charIndex = charIndex - totalChars
		end
		
		local characterId = game.characterOptions[charIndex]
		local character = game.characters[characterId]
		local charImage = game.images.characters[characterId]
		
		-- Calculate frame dimensions and position
		local frameWidth = slot.frameWidth
		local frameHeight = slot.frameHeight
		local frameX = slot.posX - (frameWidth / 2)
		local frameY = slot.posY - (frameHeight / 2)
		
		-- Calculate trapezoid corners for perspective
		local p1x, p1y = frameX, frameY + slot.leftSquash
		local p2x, p2y = frameX + frameWidth, frameY + slot.rightSquash
		local p3x, p3y = frameX + frameWidth, frameY + frameHeight - slot.rightSquash
		local p4x, p4y = frameX, frameY + frameHeight - slot.leftSquash
		
		local framePoly = playdate.geometry.polygon.new(p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y)
		framePoly:close()
		
		-- Draw drop shadow
		gfx.setColor(gfx.kColorBlack)
		local shadowOffset = slot.isSelected and 4 or 2
		local shadowPoly = playdate.geometry.polygon.new(p1x + shadowOffset, p1y + shadowOffset, p2x + shadowOffset, p2y + shadowOffset, p3x + shadowOffset, p3y + shadowOffset, p4x + shadowOffset, p4y + shadowOffset)
		shadowPoly:close()
		gfx.fillPolygon(shadowPoly)
		
		-- Draw 3D Spine (Thickness) to make it look like a physical box
		if slot.offset ~= 0 then
			local spineWidth = 4
			if slot.offset < 0 then
				-- Spine on the right side
				local spPoly = playdate.geometry.polygon.new(p2x, p2y, p2x + spineWidth, p2y + spineWidth, p3x + spineWidth, p3y - spineWidth, p3x, p3y)
				spPoly:close()
				gfx.fillPolygon(spPoly)
			elseif slot.offset > 0 then
				-- Spine on the left side
				local spPoly = playdate.geometry.polygon.new(p1x - spineWidth, p1y + spineWidth, p1x, p1y, p4x, p4y, p4x - spineWidth, p4y - spineWidth)
				spPoly:close()
				gfx.fillPolygon(spPoly)
			end
		end
		
		-- Draw Frame Background
		gfx.setColor(gfx.kColorWhite)
		gfx.fillPolygon(framePoly)
		
		-- Draw character image scaled to safely fit inside the trapezoid
		if charImage then
			local imgWidth, imgHeight = charImage:getSize()
			
			-- Calculate the maximum safe rectangle inside the trapezoid
			local innerPadding = 6
			local availableWidth = frameWidth - innerPadding
			local availableHeight = frameHeight - 2 * math.max(slot.leftSquash, slot.rightSquash) - innerPadding
			
			-- Calculate strict uniform scale so image never spills
			local scaleFitX = availableWidth / imgWidth
			local scaleFitY = availableHeight / imgHeight
			local finalScale = math.min(scaleFitX, scaleFitY)
			if finalScale > 1.0 then finalScale = 1.0 end
			
			local scaledWidth = imgWidth * finalScale
			local scaledHeight = imgHeight * finalScale
			
			-- Center perfectly in the frame bounds
			local drawX = frameX + (frameWidth - scaledWidth) / 2
			local drawY = frameY + (frameHeight - scaledHeight) / 2
			
			gfx.pushContext()
			if not character.alive then
				-- Dead character: render dithered
				gfx.setImageDrawMode(gfx.kDrawModeFillWhite)
				charImage:drawScaled(drawX, drawY, finalScale)
				
				-- Apply dither strictly over the image rect to preserve white frame
				gfx.setImageDrawMode(gfx.kDrawModeFillBlack)
				gfx.setDitherPattern(0.5)
				gfx.fillRect(drawX, drawY, scaledWidth, scaledHeight)
			else
				charImage:drawScaled(drawX, drawY, finalScale)
			end
			gfx.popContext()
		else
			-- Fallback: text
			gfx.setColor(gfx.kColorBlack)
			drawCenteredText(character.name, frameX + (frameWidth / 2), frameY + (frameHeight / 2) - 4)
		end
		
		-- Draw Frame Border
		gfx.setColor(gfx.kColorBlack)
		if slot.isSelected then
			gfx.setLineWidth(3)
			gfx.drawPolygon(framePoly)
			gfx.setLineWidth(1)
		else
			gfx.drawPolygon(framePoly)
		end
		
		-- Draw character info below frame (only for selected)
		if slot.isSelected then
			local nameY = math.max(p3y, p4y) + 8
			gfx.setColor(gfx.kColorBlack)
			drawCenteredText(character.name, frameX + (frameWidth / 2), nameY)
			
			if not character.alive then
				drawCenteredText("DEAD", frameX + (frameWidth / 2), nameY + 12)
			else
				if character.sick then
					drawCenteredText("(SICK)", frameX + (frameWidth / 2), nameY + 12)
				elseif character.hurt then
					drawCenteredText("(HURT)", frameX + (frameWidth / 2), nameY + 12)
				elseif character.vaccinated then
					drawCenteredText("(VACC)", frameX + (frameWidth / 2), nameY + 12)
				end
			end
		end
	end

	local infoY = 178
	local lineHeight = 16

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(10, infoY - 4, 380, 62)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(10, infoY - 4, 380, 62)

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
		if startY + (i - 1) * lineHeight > infoY + 50 then
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
	local lineHeight = 14

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(panelX, panelY, panelWidth, panelHeight)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(panelX, panelY, panelWidth, panelHeight)

	local y = panelY + 8
	gfx.drawText("Debug mode", panelX + 6, y)
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
		gfx.drawText(floorLine, panelX + 6, y)
		y = y + lineHeight
	end

	y = y + 4
	gfx.drawText("Last calc:", panelX + 6, y)
	y = y + lineHeight

	for _, line in ipairs(game.cutscene:getDebugLines()) do
		if y > panelY + panelHeight - lineHeight then
			break
		end
		gfx.drawText(line, panelX + 6, y)
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
