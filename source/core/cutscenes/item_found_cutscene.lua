import "core/cutscenes/base_cutscene"

local pd = playdate
local snd = pd.sound
local gfx = pd.graphics

ItemFoundCutscene = setmetatable({}, {__index = BaseCutscene})
ItemFoundCutscene.__index = ItemFoundCutscene

function ItemFoundCutscene.new(imageKey, titleText)
	local self = setmetatable(BaseCutscene.new(), ItemFoundCutscene)
	self.imageKey = imageKey -- Key inside the 'images' table (e.g. "keyCutscene")
	self.titleText = titleText
	self.sound = snd.sampleplayer.new("sound/item_found")
	return self
end

local function drawCenteredText(text, centerX, y)
	local textWidth = gfx.getTextSize(text)
	gfx.drawText(text, math.floor(centerX - (textWidth / 2)), y)
end

function ItemFoundCutscene:draw(gfx, images, uiState)
	if self.imageKey and images[self.imageKey] then
		images[self.imageKey]:draw(0, 0)
	end
	
	-- Draw a taller banner at the bottom for the text
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(0, 200, 400, 40)
	gfx.setColor(gfx.kColorBlack)
	
	drawCenteredText(self.titleText, 200, 204)
	
	if self.cutsceneHoldTimer <= 0 then
		drawCenteredText("Press A/B to continue", 200, 224)
	else
		drawCenteredText("...", 200, 224)
	end
end
