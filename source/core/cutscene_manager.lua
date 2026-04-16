import "core/cutscenes/encounter_cutscene"
import "core/cutscenes/item_found_cutscene"

CutsceneManager = {}
CutsceneManager.__index = CutsceneManager

local pd = playdate
local snd = pd.sound

function CutsceneManager.new()
	local self = setmetatable({}, CutsceneManager)
	
	self.activeCutscene = nil
	
	-- Debug
	self.lastChallengeDebugLines = {}
	self.lastFloorSurvived = false
	
	-- Dialogue caching
	self.cachedFloorDialogue = ""
	self.cachedDialogueFloor = -1
	
	return self
end

-- === LIFECYCLE ===

function CutsceneManager:playCutscene(cutsceneObject)
	self.activeCutscene = cutsceneObject
	if self.activeCutscene then
		self.activeCutscene:start()
	end
end

-- Keep backwards compatibility interface for now
function CutsceneManager:start(lines, showKeyImage, isItemFound)
	if showKeyImage then
		self:playCutscene(ItemFoundCutscene.new("keyCutscene", "You found the key!"))
	elseif isItemFound then
		-- You can create another image key for regular items later
		-- Using encounter cutscene as fallback but with item sound if needed
		-- For now, if we don't have a specific image, we just use the encounter one
		local encounter = EncounterCutscene.new(lines)
		encounter.sound = snd.sampleplayer.new("sound/item_found")
		self:playCutscene(encounter)
	else
		self:playCutscene(EncounterCutscene.new(lines))
	end
end

function CutsceneManager:update()
	if self.activeCutscene then
		self.activeCutscene:update()
	end
end

function CutsceneManager:isActive()
	if self.activeCutscene then
		return self.activeCutscene:isActive()
	end
	return false
end

function CutsceneManager:skip()
	if self.activeCutscene then
		self.activeCutscene:skip()
	end
end

-- === CONTENT ACCESS ===

function CutsceneManager:drawActive(gfx, images, uiState)
	if self.activeCutscene and self.activeCutscene:isActive() then
		self.activeCutscene:draw(gfx, images, uiState)
	end
end

function CutsceneManager:getHoldTimer()
	if self.activeCutscene then
		return self.activeCutscene:getHoldTimer()
	end
	return 0
end

-- === DEBUG ===

function CutsceneManager:setDebugLines(lines)
	self.lastChallengeDebugLines = lines or {}
end

function CutsceneManager:getDebugLines()
	return self.lastChallengeDebugLines
end

-- === FLOOR OUTCOME ===

function CutsceneManager:setFloorSurvived(survived)
	self.lastFloorSurvived = survived
end

function CutsceneManager:didFloorSurvive()
	return self.lastFloorSurvived
end

-- === DIALOGUE CACHING ===

function CutsceneManager:cacheDialogue(floorIndex, dialogue)
	self.cachedFloorDialogue = dialogue
	self.cachedDialogueFloor = floorIndex
end

function CutsceneManager:getCachedDialogue(floorIndex)
	if self.cachedDialogueFloor == floorIndex then
		return self.cachedFloorDialogue
	end
	return nil
end

function CutsceneManager:clearDialogueCache()
	self.cachedFloorDialogue = ""
	self.cachedDialogueFloor = -1
end
