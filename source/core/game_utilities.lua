import "core/data/items"

local gfx = playdate.graphics

-- === CHARACTER CLONING ===

function cloneCharacterState(character)
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

-- === LIST UTILITIES ===

function cloneList(values)
	local copy = {}
	for index, value in ipairs(values or {}) do
		copy[index] = value
	end
	return copy
end

function containsValue(values, target)
	for _, value in ipairs(values) do
		if value == target then
			return true
		end
	end
	return false
end

function removeValue(values, target)
	for index, value in ipairs(values) do
		if value == target then
			table.remove(values, index)
			return true
		end
	end
	return false
end

-- === ITEM UTILITIES ===

function buildSortedItemOptions()
	local itemOptions = {}
	for itemId, item in pairs(Items) do
		itemOptions[#itemOptions + 1] = { id = itemId, name = item.name }
	end

	table.sort(itemOptions, function(left, right)
		return left.name < right.name
	end)

	return itemOptions
end

function buildStartingItemOptions()
	-- Limited set of 5 starting items (excluding collectible-only items like backpack)
	local startingItemIds = { "gun", "knife", "flashlight", "gas_mask", "medkit" }
	local itemOptions = {}
	
	for _, itemId in ipairs(startingItemIds) do
		local item = Items[itemId]
		if item then
			itemOptions[#itemOptions + 1] = { id = itemId, name = item.name }
		end
	end

	table.sort(itemOptions, function(left, right)
		return left.name < right.name
	end)

	return itemOptions
end

function joinItemNames(itemIds)
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

-- === TEXT & UI UTILITIES ===

function wrapText(text, maxWidth)
	local words = {}
	for word in text:gmatch("%S+") do
		words[#words + 1] = word
	end
	
	local lines = {}
	local currentLine = ""
	
	for _, word in ipairs(words) do
		local testLine = currentLine == "" and word or currentLine .. " " .. word
		local textWidth = gfx.getTextSize(testLine)
		if textWidth > maxWidth and currentLine ~= "" then
			lines[#lines + 1] = currentLine
			currentLine = word
		else
			currentLine = testLine
		end
	end
	
	if currentLine ~= "" then
		lines[#lines + 1] = currentLine
	end
	
	return lines
end

function drawCenteredText(text, centerX, y)
	local textWidth = gfx.getTextSize(text)
	gfx.drawText(text, math.floor(centerX - (textWidth / 2)), y)
end

function clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

-- === DIALOGUE & HINTS ===

FloorHints = {
	explored = {
		"This floor is already explored",
		"We went through here before",
		"Nothing left here",
	},
	radiation = {
		"It smells strange...",
		"The air feels heavy here",
		"I feel dizzy already",
	},
	criminal = {
		"I hear shooting guns",
		"Someone's in there...",
		"Sounds like a firefight",
	},
	zombie = {
		"Those sounds... not human",
		"Something shuffles nearby",
		"I hear groaning...",
	},
	trap = {
		"This doesn't look right",
		"Too quiet...",
		"Something feels off",
	},
	safe = {
		"Seems peaceful",
		"We can rest here",
		"Clear for now",
	},
	loot = {
		"I see something shiny",
		"There might be supplies",
		"Could be useful loot",
	},
	exit = {
		"Almost there!",
		"The exit is close",
		"End of the line",
	},
}

function getRandomHint(floorType, isExplored)
	if isExplored then
		return FloorHints.explored[math.random(1, #FloorHints.explored)]
	end
	local hints = FloorHints[floorType]
	if hints then
		return hints[math.random(1, #hints)]
	end
	return ""
end

function getAliveCharacterNames(characters, characterOptions)
	local names = {}
	for _, characterId in ipairs(characterOptions) do
		if characters[characterId].alive then
			names[#names + 1] = characters[characterId].name
		end
	end
	return names
end
