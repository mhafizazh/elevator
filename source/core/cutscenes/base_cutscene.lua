import "CoreLibs/graphics"

BaseCutscene = {}
BaseCutscene.__index = BaseCutscene

local RESULT_CUTSCENE_FRAMES = 90
local RESULT_CUTSCENE_HOLD_FRAMES = 35

function BaseCutscene.new()
	local self = setmetatable({}, BaseCutscene)
	self.cutsceneTimer = 0
	self.cutsceneHoldTimer = 0
	self.sound = nil
	return self
end

function BaseCutscene:start()
	self.cutsceneTimer = RESULT_CUTSCENE_FRAMES
	self.cutsceneHoldTimer = RESULT_CUTSCENE_HOLD_FRAMES
	if self.sound then
		self.sound:play()
	end
end

function BaseCutscene:update()
	if self.cutsceneTimer > 0 then
		self.cutsceneTimer = self.cutsceneTimer - 1
	elseif self.cutsceneHoldTimer > 0 then
		self.cutsceneHoldTimer = self.cutsceneHoldTimer - 1
	end
end

function BaseCutscene:isActive()
	return self.cutsceneTimer > 0 or self.cutsceneHoldTimer > 0
end

function BaseCutscene:skip()
	self.cutsceneTimer = 0
	self.cutsceneHoldTimer = 0
end

function BaseCutscene:getHoldTimer()
	return self.cutsceneHoldTimer
end

-- Must be implemented by child classes
function BaseCutscene:draw(gfx, images, uiState)
end
