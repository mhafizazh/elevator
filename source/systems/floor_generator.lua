if DEBUG_MODE then
	print("floor_generator.lua loaded")
end

FloorGenerator = {}
FloorGenerator.__index = FloorGenerator

FloorGenerator.CONFIG = {
    minFloorCount = 20,
    maxFloorCount = 30,
    segmentSize = 10,
    dangerousPerSegment = 5,
    safePerSegment = 4,
    rewardPerSegment = 1,
    floorCategories = {
        dangerous = { "zombie", "criminal", "trap", "radiation" },
        safe = { "safe" },
        reward = { "loot" },
    },
    dangerousWeights = {
        zombie = 3.0,
        criminal = 2.5,
        trap = 2.0,
        radiation = 1.0,
    },
    safeWeights = {
        safe = 1.0,
    },
    rewardWeights = {
        loot = 1.0,
    },
    lootItemsMin = 3,
    lootItemsMax = 7,
    collectibleItemsMin = 2,
    collectibleItemsMax = 5,
}

local runCounter = 0

function FloorGenerator.new()
    local self = setmetatable({}, FloorGenerator)
    return self
end

function FloorGenerator:_pickWeighted(category, weights)
    local items = FloorGenerator.CONFIG.floorCategories[category]
    if not items or #items == 0 then
        return nil
    end

    if #items == 1 then
        return items[1]
    end

    local totalWeight = 0
    local cumulativeWeights = {}
    for _, item in ipairs(items) do
        local weight = weights[item] or 1.0
        totalWeight = totalWeight + weight
        cumulativeWeights[#cumulativeWeights + 1] = { item = item, threshold = totalWeight }
    end

    local roll = math.random() * totalWeight
    for _, entry in ipairs(cumulativeWeights) do
        if roll <= entry.threshold then
            return entry.item
        end
    end

    return items[#items]
end

function FloorGenerator:_fillSegment(floors, dangerousRemaining, safeRemaining, rewardRemaining)
    local segmentFloors = {}

    for i = 1, FloorGenerator.CONFIG.segmentSize do
        local floorType

        if dangerousRemaining > 0 and (safeRemaining == 0 or math.random() < 0.6) then
            floorType = self:_pickWeighted("dangerous", FloorGenerator.CONFIG.dangerousWeights)
            dangerousRemaining = dangerousRemaining - 1
        elseif safeRemaining > 0 and (rewardRemaining == 0 or math.random() < 0.7) then
            floorType = self:_pickWeighted("safe", FloorGenerator.CONFIG.safeWeights)
            safeRemaining = safeRemaining - 1
        elseif rewardRemaining > 0 then
            floorType = self:_pickWeighted("reward", FloorGenerator.CONFIG.rewardWeights)
            rewardRemaining = rewardRemaining - 1
        else
            floorType = self:_pickWeighted("dangerous", FloorGenerator.CONFIG.dangerousWeights)
        end

        segmentFloors[#segmentFloors + 1] = floorType
    end

    for _, floorType in ipairs(segmentFloors) do
        floors[#floors + 1] = floorType
    end

    return dangerousRemaining, safeRemaining, rewardRemaining
end

function FloorGenerator:_generateLootItems()
    local count = math.random(
        FloorGenerator.CONFIG.lootItemsMin,
        FloorGenerator.CONFIG.lootItemsMax
    )
    local allItems = {"gun", "knife", "flashlight", "gas_mask"}
    local lootItems = {}
    local used = {}
    local generated = 0
    while generated < count and generated < #allItems do
        local itemIndex = math.random(1, #allItems)
        local itemId = allItems[itemIndex]
        if not used[itemId] then
            used[itemId] = true
            generated = generated + 1
            lootItems[#lootItems + 1] = itemId
        end
    end
    return lootItems
end

function FloorGenerator:_generateCollectibleItems()
    local count = math.random(
        FloorGenerator.CONFIG.collectibleItemsMin,
        FloorGenerator.CONFIG.collectibleItemsMax
    )
    -- All collectible items excluding medkit
    local allItems = {"gun", "knife", "flashlight", "gas_mask", "grappling_hook", "rope", "compass", "strength_drink"}
    local collectibleItems = {}
    local used = {}
    local generated = 0
    while generated < count and generated < #allItems do
        local itemIndex = math.random(1, #allItems)
        local itemId = allItems[itemIndex]
        if not used[itemId] then
            used[itemId] = true
            generated = generated + 1
            collectibleItems[#collectibleItems + 1] = itemId
        end
    end
    return collectibleItems
end

function FloorGenerator:_placeExitKey(floors, lootByFloor)
    local totalFloors = #floors - 1
    local lastQuarterStart = math.floor(totalFloors * 0.75)
    
    -- First priority: find a 'loot' floor in the last quarter
    local validLootFloors = {}
    for i = lastQuarterStart, totalFloors - 1 do
        if floors[i] == "loot" then
            validLootFloors[#validLootFloors + 1] = i
        end
    end
    if #validLootFloors > 0 then
        return validLootFloors[math.random(1, #validLootFloors)]
    end
    
    -- Second priority: find any 'loot' floor in the tower
    for i = 1, totalFloors - 1 do
        if floors[i] == "loot" then
            validLootFloors[#validLootFloors + 1] = i
        end
    end
    if #validLootFloors > 0 then
        return validLootFloors[math.random(1, #validLootFloors)]
    end
    
    -- Fallback: pick a random floor in the last quarter and forcefully change it to 'loot'
    local validFloors = {}
    for i = lastQuarterStart, totalFloors - 1 do
        if floors[i] ~= "exit" then
            validFloors[#validFloors + 1] = i
        end
    end
    if #validFloors > 0 then
        local chosenIndex = validFloors[math.random(1, #validFloors)]
        floors[chosenIndex] = "loot"
        if lootByFloor then
            lootByFloor[chosenIndex] = self:_generateLootItems()
        end
        return chosenIndex
    end
    return -1
end

function FloorGenerator:generate(minFloor, maxFloor)
    runCounter = runCounter + 1
    local currentRun = runCounter

    local totalFloors = math.random(
        minFloor or FloorGenerator.CONFIG.minFloorCount,
        maxFloor or FloorGenerator.CONFIG.maxFloorCount
    )
    local floors = {}
    local lootByFloor = {}
    local collectibleByFloor = {}
    local exitKeyFloor = -1

    local dangerousRemaining = FloorGenerator.CONFIG.dangerousPerSegment
    local safeRemaining = FloorGenerator.CONFIG.safePerSegment
    local rewardRemaining = FloorGenerator.CONFIG.rewardPerSegment

    local currentSegment = 0
    local floorsInCurrentSegment = 0

    while #floors < totalFloors - 1 do
        if floorsInCurrentSegment >= FloorGenerator.CONFIG.segmentSize then
            currentSegment = currentSegment + 1
            floorsInCurrentSegment = 0
            dangerousRemaining = FloorGenerator.CONFIG.dangerousPerSegment
            safeRemaining = FloorGenerator.CONFIG.safePerSegment
            rewardRemaining = FloorGenerator.CONFIG.rewardPerSegment
        end

        local floorType
        -- Ensure floor 2 is safe to guarantee the player gets the backpack
        if #floors == 1 then
            floorType = "safe"
            if safeRemaining > 0 then safeRemaining = safeRemaining - 1 end
        elseif dangerousRemaining > 0 and (safeRemaining == 0 or math.random() < 0.6) then
            floorType = self:_pickWeighted("dangerous", FloorGenerator.CONFIG.dangerousWeights)
            dangerousRemaining = dangerousRemaining - 1
        elseif safeRemaining > 0 and (rewardRemaining == 0 or math.random() < 0.7) then
            floorType = self:_pickWeighted("safe", FloorGenerator.CONFIG.safeWeights)
            safeRemaining = safeRemaining - 1
        elseif rewardRemaining > 0 then
            floorType = self:_pickWeighted("reward", FloorGenerator.CONFIG.rewardWeights)
            rewardRemaining = rewardRemaining - 1
        else
            floorType = self:_pickWeighted("dangerous", FloorGenerator.CONFIG.dangerousWeights)
        end

        floors[#floors + 1] = floorType
        if floorType == "loot" then
            lootByFloor[#floors] = self:_generateLootItems()
        end
        
        -- Generate collectible items for every floor
        local collectibles = self:_generateCollectibleItems()
        collectibleByFloor[#floors] = collectibles
        
        floorsInCurrentSegment = floorsInCurrentSegment + 1
    end

    floors[#floors + 1] = "exit"
    exitKeyFloor = self:_placeExitKey(floors, lootByFloor)
    
    -- Place backpack on floor 2 (index 2, which is the 3rd floor since floor 1 is at index 1)
    if #collectibleByFloor >= 2 then
        table.insert(collectibleByFloor[2], "backpack")
    end
    
    -- Place medkit every 5 floors
    for i = 5, #collectibleByFloor, 5 do
        table.insert(collectibleByFloor[i], "medkit")
    end

	if DEBUG_MODE then
		print("")
		print("=== FLOOR GENERATION DEBUG (Run #" .. currentRun .. ") ===")
		print("Total floors: " .. #floors)
		print("Segments: " .. math.ceil(#floors / FloorGenerator.CONFIG.segmentSize))
        print("Exit key on floor: " .. exitKeyFloor)
		print("--- Floor List ---")
		for i, floorType in ipairs(floors) do
			local segment = math.ceil(i / FloorGenerator.CONFIG.segmentSize)
            local lootInfo = ""
            if floorType == "loot" then
                local items = lootByFloor[i]
                if items then
                    lootInfo = " -> " .. #items .. " items"
                end
            end
            local collectibleInfo = ""
            if collectibleByFloor[i] then
                collectibleInfo = " -> " .. #collectibleByFloor[i] .. " collectibles"
            end
            local keyMarker = ""
            if i == exitKeyFloor then
                keyMarker = " [EXIT KEY]"
            end
			print(string.format("[%02d] Seg %d: %s%s%s%s", i, segment, floorType, lootInfo, collectibleInfo, keyMarker))
		end
		print("===========================")
		print("")
	end

	return floors, lootByFloor, exitKeyFloor, collectibleByFloor
end

function FloorGenerator:getFloorType(gameData, floorIndex)
    if floorIndex == 0 then
        return "safe"
    end
    return gameData.floors[floorIndex]
end
