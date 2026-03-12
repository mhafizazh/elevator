import "core/data/items"

ItemEffectSystem = {}
ItemEffectSystem.__index = ItemEffectSystem

function ItemEffectSystem.new(itemCatalog)
	local self = setmetatable({}, ItemEffectSystem)
	self.items = itemCatalog or Items
	return self
end

function ItemEffectSystem:calculateItemBonus(floorType, characterId, equippedItemIds)
	local totalBonus = 0
	local requirementMet = true
	local itemDebugLines = {}
	local hasRequirementProvider = false

	for _, itemId in ipairs(equippedItemIds or {}) do
		local item = self.items[itemId]
		if item then
			local floorBonus = 0
			if item.floorBonus and item.floorBonus[floorType] then
				floorBonus = floorBonus + item.floorBonus[floorType]
			end

			if item.characterBonus and item.characterBonus[characterId] and item.characterBonus[characterId][floorType] then
				floorBonus = floorBonus + item.characterBonus[characterId][floorType]
			end

			totalBonus = totalBonus + floorBonus
			itemDebugLines[#itemDebugLines + 1] = item.name .. " bonus: +" .. tostring(floorBonus)

			if item.grantsRequirement and item.grantsRequirement[floorType] then
				hasRequirementProvider = true
			end
		end
	end

	if floorType == "radiation" and not hasRequirementProvider then
		requirementMet = false
		itemDebugLines[#itemDebugLines + 1] = "Missing requirement: gas_mask"
	end

	return {
		totalBonus = totalBonus,
		requirementMet = requirementMet,
		debugLines = itemDebugLines,
	}
end
