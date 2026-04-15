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
    local allItems = {"gun", "knife", "flashlight", "gas_mask", "medkit"}
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

function FloorGenerator:_placeExitKey(floors)
    local totalFloors = #floors - 1
    local lastQuarterStart = math.floor(totalFloors * 0.75)
    local validFloors = {}
    for i = lastQuarterStart, totalFloors - 1 do
        if floors[i] ~= "exit" then
            validFloors[#validFloors + 1] = i
        end
    end
    if #validFloors > 0 then
        local chosenIndex = validFloors[math.random(1, #validFloors)]
        return chosenIndex
    end
    return -1
end

function FloorGenerator:generate()
    runCounter = runCounter + 1
    local currentRun = runCounter

    local totalFloors = math.random(
        FloorGenerator.CONFIG.minFloorCount,
        FloorGenerator.CONFIG.maxFloorCount
    )
    local floors = {}
    local lootByFloor = {}
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

        floors[#floors + 1] = floorType
        if floorType == "loot" then
            lootByFloor[#floors] = self:_generateLootItems()
        end
        floorsInCurrentSegment = floorsInCurrentSegment + 1
    end

	floors[#floors + 1] = "exit"
    exitKeyFloor = self:_placeExitKey(floors)

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
            local keyMarker = ""
            if i == exitKeyFloor then
                keyMarker = " [EXIT KEY]"
            end
			print(string.format("[%02d] Seg %d: %s%s%s", i, segment, floorType, lootInfo, keyMarker))
		end
		print("===========================")
		print("")
	end

	return floors, lootByFloor, exitKeyFloor
end

function FloorGenerator:getFloorType(gameData, floorIndex)
    if floorIndex == 0 then
        return "safe"
    end
    return gameData.floors[floorIndex]
end
