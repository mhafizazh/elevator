import "systems/survival_system"

FloorChallengeSystem = {}
FloorChallengeSystem.__index = FloorChallengeSystem

FloorChallengeSystem.RULES = {
    safe = {
        baseChance = 100,
        statWeights = {},
        guaranteed = true,
        event = "rest",
    },
    zombie = {
        baseChance = 30,
        statWeights = { combat = 2.8, survival = 1.2 },
        deathReason = "zombie attack",
    },
    criminal = {
        baseChance = 40,
        statWeights = { combat = 3.0, stealth = 0.8 },
        deathReason = "criminal ambush",
    },
    trap = {
        baseChance = 50,
        statWeights = { stealth = 2.0, luck = 1.8 },
        deathReason = "trap injuries",
    },
    loot = {
        baseChance = 100,
        statWeights = { luck = 1.5 },
        guaranteed = true,
        event = "loot",
    },
    radiation = {
        baseChance = 10,
        statWeights = { survival = 2.5, luck = 0.6 },
        deathReason = "radiation exposure",
    },
    exit = {
        baseChance = 100,
        statWeights = {},
        guaranteed = true,
        event = "exit",
    },
}

function FloorChallengeSystem.new(survivalSystem)
    local self = setmetatable({}, FloorChallengeSystem)
    self.survivalSystem = survivalSystem or SurvivalSystem.new()
    return self
end

local function joinItems(equippedItemIds)
    if not equippedItemIds or #equippedItemIds == 0 then
        return "none"
    end
    return table.concat(equippedItemIds, ", ")
end

function FloorChallengeSystem:printDebugLog(lines)
    if not DEBUG_MODE then
        return
    end

    for _, line in ipairs(lines) do
        print(line)
    end
end

function FloorChallengeSystem:resolveFloorChallenge(floorType, character, equippedItemIds)
    local rule = FloorChallengeSystem.RULES[floorType]
    if not rule then
        return {
            survived = false,
            roll = 100,
            chance = 0,
            deathReason = "unknown floor",
            floorType = floorType,
            debugLines = { "Unknown floor type: " .. tostring(floorType) },
        }
    end

    if rule.guaranteed then
        return {
            survived = true,
            roll = 1,
            chance = 100,
            floorType = floorType,
            event = rule.event,
            debugLines = {
                "Base chance: 100",
                "This floor is non-lethal.",
            },
        }
    end

    local chanceResult = self.survivalSystem:calculateSurvivalChance(floorType, character, equippedItemIds, rule)
    local rollResult = self.survivalSystem:resolveSurvival(chanceResult.chance)

    return {
        survived = rollResult.survived,
        roll = rollResult.roll,
        chance = chanceResult.chance,
        floorType = floorType,
        deathReason = rule.deathReason,
        debugLines = chanceResult.breakdown,
        itemDebugLines = chanceResult.itemDebugLines,
    }
end

function FloorChallengeSystem:getFloorPreview(floorType, character, equippedItemIds)
    local rule = FloorChallengeSystem.RULES[floorType]
    if not rule then
        return {
            floorType = floorType,
            chance = 0,
            debugLines = { "Unknown floor type: " .. tostring(floorType) },
            itemDebugLines = {},
        }
    end

    if rule.guaranteed then
        return {
            floorType = floorType,
            chance = 100,
            debugLines = {
                "Base chance: 100",
                "This floor is non-lethal.",
            },
            itemDebugLines = {},
            guaranteed = true,
            event = rule.event,
        }
    end

    local chanceResult = self.survivalSystem:calculateSurvivalChance(floorType, character, equippedItemIds, rule)
    return {
        floorType = floorType,
        chance = chanceResult.chance,
        debugLines = chanceResult.breakdown,
        itemDebugLines = chanceResult.itemDebugLines,
        requirementMet = chanceResult.requirementMet,
    }
end

function FloorChallengeSystem:enterFloor(floorNumber, floorType, character, equippedItemIds)
    local lines = {
        "Entering Floor " .. tostring(floorNumber),
        "Floor Type: " .. tostring(floorType),
        "Character: " .. tostring(character.name),
        "Items: " .. joinItems(equippedItemIds),
        "",
    }

    local result = self:resolveFloorChallenge(floorType, character, equippedItemIds)

    for _, line in ipairs(result.debugLines or {}) do
        lines[#lines + 1] = line
    end
    for _, line in ipairs(result.itemDebugLines or {}) do
        lines[#lines + 1] = line
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Total survival chance: " .. tostring(result.chance)
    lines[#lines + 1] = "Roll: " .. tostring(result.roll)

    if result.survived then
        lines[#lines + 1] = "Result: SURVIVED"
        if result.event == "loot" then
            lines[#lines + 1] = "Loot floor completed. Reward items can be granted here."
        elseif result.event == "exit" then
            lines[#lines + 1] = "Exit floor reached. Win condition triggered."
        end
    else
        lines[#lines + 1] = "Result: DIED"
        lines[#lines + 1] = character.name .. " died on floor " .. tostring(floorNumber) .. " (" .. tostring(result.deathReason) .. ")"
    end

    self:printDebugLog(lines)

    return result
end
