import "systems/item_effect_system"

SurvivalSystem = {}
SurvivalSystem.__index = SurvivalSystem

function SurvivalSystem.new(itemEffectSystem)
    local self = setmetatable({}, SurvivalSystem)
    self.itemEffectSystem = itemEffectSystem or ItemEffectSystem.new()
    return self
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

function SurvivalSystem:calculateSurvivalChance(floorType, character, equippedItemIds, floorRule)
    local itemResult = self.itemEffectSystem:calculateItemBonus(floorType, character.id, equippedItemIds)
    if not itemResult.requirementMet then
        return {
            chance = 0,
            baseChance = floorRule.baseChance,
            statBonus = 0,
            itemBonus = itemResult.totalBonus,
            requirementMet = false,
            breakdown = {
                "Base chance: " .. tostring(floorRule.baseChance),
                "Requirement failed for floor type: " .. floorType,
            },
            itemDebugLines = itemResult.debugLines,
        }
    end

    local statBonus = 0
    local statBreakdown = {}
    for statName, weight in pairs(floorRule.statWeights or {}) do
        local statValue = character.stats[statName] or 0
        local contribution = statValue * weight
        statBonus = statBonus + contribution
        statBreakdown[#statBreakdown + 1] = statName .. " bonus: +" .. string.format("%.1f", contribution)
    end

    local breakdown = {
        "Base chance: " .. tostring(floorRule.baseChance),
    }
    for _, line in ipairs(statBreakdown) do
        breakdown[#breakdown + 1] = line
    end

    local chance = floorRule.baseChance + statBonus + itemResult.totalBonus
    
    if character.sick then
        chance = chance - 40
        breakdown[#breakdown + 1] = "Sick penalty: -40.0"
    end
    if character.hurt then
        chance = chance - 40
        breakdown[#breakdown + 1] = "Hurt penalty: -40.0"
    end
    if character.vaccinated and floorType == "zombie" then
        chance = chance + 50
        breakdown[#breakdown + 1] = "Vaccinated bonus: +50.0"
    end
    
    chance = clamp(math.floor(chance + 0.5), 0, 95)

    return {
        chance = chance,
        baseChance = floorRule.baseChance,
        statBonus = statBonus,
        itemBonus = itemResult.totalBonus,
        requirementMet = true,
        breakdown = breakdown,
        itemDebugLines = itemResult.debugLines,
    }
end

function SurvivalSystem:resolveSurvival(chance)
    local roll = math.random(1, 100)
    return {
        roll = roll,
        survived = roll <= chance,
    }
end
