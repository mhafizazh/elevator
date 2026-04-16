import "core/game_utilities"
import "core/data/items"

InventoryManager = {}
InventoryManager.__index = InventoryManager

function InventoryManager.new()
	local self = setmetatable({}, InventoryManager)
	
	-- Owned inventory
	self.ownedItemIds = {}
	
	-- Floor equipment (pending for current floor)
	self.pendingEquippedItemIds = {}
	
	-- Loot phase
	self.currentLootItems = {}
	self.selectedLootItemIds = {}
	
	-- Collectible phase
	self.currentCollectibleItems = {}
	self.selectedCollectibleItemIds = {}
	self.maxCollectibleCapacity = 3
	self.hasBackpackFound = false
	
	-- Starting phase
	self.selectedStartingItemIds = {}
	
	-- Item options (cached for rendering)
	self.itemOptions = buildSortedItemOptions()
	self.startingItemOptions = buildStartingItemOptions()
	
	return self
end

-- === OWNED INVENTORY ===

function InventoryManager:addItemToOwned(itemId)
	if not self:hasItem(itemId) then
		table.insert(self.ownedItemIds, itemId)
	end
end

function InventoryManager:removeItemFromOwned(itemId)
	removeValue(self.ownedItemIds, itemId)
end

function InventoryManager:hasItem(itemId)
	return containsValue(self.ownedItemIds, itemId)
end

function InventoryManager:getOwnedItems()
	return self.ownedItemIds
end

function InventoryManager:getOwnedItemOptions()
	local options = {}
	for _, itemId in ipairs(self.ownedItemIds) do
		local item = Items[itemId]
		if item then
			options[#options + 1] = { id = itemId, name = item.name }
		end
	end
	table.sort(options, function(a, b) return a.name < b.name end)
	return options
end

function InventoryManager:clearOwnedItems()
	self.ownedItemIds = {}
end

-- === FLOOR EQUIPMENT (PENDING) ===

function InventoryManager:addEquippedItem(itemId)
	if not containsValue(self.pendingEquippedItemIds, itemId) then
		table.insert(self.pendingEquippedItemIds, itemId)
	end
end

function InventoryManager:removeEquippedItem(itemId)
	removeValue(self.pendingEquippedItemIds, itemId)
end

function InventoryManager:getEquippedItems()
	return self.pendingEquippedItemIds
end

function InventoryManager:getEquippedItemCount()
	return #self.pendingEquippedItemIds
end

function InventoryManager:canEquipMore(limit)
	return #self.pendingEquippedItemIds < (limit or 2)
end

function InventoryManager:toggleEquippedItem(itemId, limit)
	limit = limit or 2
	if containsValue(self.pendingEquippedItemIds, itemId) then
		removeValue(self.pendingEquippedItemIds, itemId)
	else
		if #self.pendingEquippedItemIds < limit then
			table.insert(self.pendingEquippedItemIds, itemId)
		end
	end
end

function InventoryManager:clearPendingEquipped()
	self.pendingEquippedItemIds = {}
end

function InventoryManager:getPreviewItemIds()
	if #self.pendingEquippedItemIds > 0 then
		return self.pendingEquippedItemIds
	else
		return self.ownedItemIds
	end
end

-- === LOOT MANAGEMENT ===

function InventoryManager:setAvailableLoot(items)
	self.currentLootItems = items or {}
	self.selectedLootItemIds = {}
	for _, itemId in ipairs(self.ownedItemIds) do
		table.insert(self.selectedLootItemIds, itemId)
	end
end

function InventoryManager:getAvailableLoot()
	return self.currentLootItems
end

function InventoryManager:toggleLootSelection(itemId, limit)
	limit = limit or 2
	if containsValue(self.selectedLootItemIds, itemId) then
		removeValue(self.selectedLootItemIds, itemId)
	else
		if #self.selectedLootItemIds < limit then
			table.insert(self.selectedLootItemIds, itemId)
		end
	end
end

function InventoryManager:confirmLootSelection()
	self.ownedItemIds = cloneList(self.selectedLootItemIds)
	self.selectedLootItemIds = {}
	self.currentLootItems = {}
end

-- === COLLECTIBLE MANAGEMENT ===

function InventoryManager:setAvailableCollectibles(items)
	self.currentCollectibleItems = items or {}
	self.selectedCollectibleItemIds = {}
	for _, itemId in ipairs(self.ownedItemIds) do
		table.insert(self.selectedCollectibleItemIds, itemId)
	end
end

function InventoryManager:getAvailableCollectibles()
	return self.currentCollectibleItems
end

function InventoryManager:toggleCollectibleSelection(itemId)
	if containsValue(self.selectedCollectibleItemIds, itemId) then
		removeValue(self.selectedCollectibleItemIds, itemId)
	else
		if #self.selectedCollectibleItemIds < self.maxCollectibleCapacity then
			table.insert(self.selectedCollectibleItemIds, itemId)
		end
	end
end

function InventoryManager:confirmCollectibleSelection()
	self.ownedItemIds = cloneList(self.selectedCollectibleItemIds)
	self.selectedCollectibleItemIds = {}
	self.currentCollectibleItems = {}
end

function InventoryManager:getCollectibles()
	return self.selectedCollectibleItemIds
end

function InventoryManager:getCollectibleCapacity()
	return self.maxCollectibleCapacity
end

function InventoryManager:increaseCapacity()
	self.maxCollectibleCapacity = 5
	self.hasBackpackFound = true
end

-- === STARTING INVENTORY ===

function InventoryManager:toggleStartingItem(itemId, limit)
	limit = limit or 3
	if containsValue(self.selectedStartingItemIds, itemId) then
		removeValue(self.selectedStartingItemIds, itemId)
	else
		if #self.selectedStartingItemIds < limit then
			table.insert(self.selectedStartingItemIds, itemId)
		end
	end
end

function InventoryManager:confirmStartingItems()
	self.ownedItemIds = cloneList(self.selectedStartingItemIds)
	self.selectedStartingItemIds = {}
end

function InventoryManager:getStartingItemCount()
	return #self.selectedStartingItemIds
end

function InventoryManager:canAddStartingItem(limit)
	return #self.selectedStartingItemIds < (limit or 3)
end
