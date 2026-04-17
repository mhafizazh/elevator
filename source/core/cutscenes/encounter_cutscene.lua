import "core/cutscenes/base_cutscene"

local pd = playdate
local snd = pd.sound
local gfx = pd.graphics

EncounterCutscene = setmetatable({}, {__index = BaseCutscene})
EncounterCutscene.__index = EncounterCutscene

function EncounterCutscene.new(lines)
	local self = setmetatable(BaseCutscene.new(), EncounterCutscene)
	self.lines = lines or {}
	self.sound = snd.sampleplayer.new("sound/cutscene")
	return self
end

local function drawCenteredText(text, centerX, y)
	local textWidth = gfx.getTextSize(text)
	gfx.drawText(text, math.floor(centerX - (textWidth / 2)), y)
end

function EncounterCutscene:draw(gfx, images, uiState)
	-- Strong visual frame so the transition reads as a cutscene.
	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(24, 36, 352, 170)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(24, 36, 352, 170)

	drawCenteredText("Encounter Result", 200, 64)

	local y = 92
	for _, line in ipairs(self.lines) do
		drawCenteredText(line, 200, y)
		y = y + 18
	end

	if self.cutsceneHoldTimer <= 0 then
		drawCenteredText("Press A/B to continue", 200, 196)
	else
		drawCenteredText("...", 200, 196)
	end
end
