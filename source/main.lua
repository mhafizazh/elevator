import "CoreLibs/graphics"

local pd = playdate
local gfx = pd.graphics

local value = 0
local crankAccumulator = 0
local degreesPerStep = 360
local defaultBackgroundImage = gfx.image.new("image/game_bg")
local alternateBackgroundImage = gfx.image.new("image/game_bg2")
local useAlternateBackground = false
local numberX = 200
local numberY = 50
local characterOptions = { "Dad", "Mom", "Son", "Daughter" }
local selectedCharacterIndex = 1

local function updateCharacterSelection()
	if pd.buttonJustPressed(pd.kButtonUp) then
		selectedCharacterIndex = selectedCharacterIndex - 1
		if selectedCharacterIndex < 1 then
			selectedCharacterIndex = #characterOptions
		end
	elseif pd.buttonJustPressed(pd.kButtonDown) then
		selectedCharacterIndex = selectedCharacterIndex + 1
		if selectedCharacterIndex > #characterOptions then
			selectedCharacterIndex = 1
		end
	end
end

local function drawCharacterSelectionUi()
	local startX = 20
	local startY = 140
	local lineHeight = 18
	local panelWidth = 170
	local panelHeight = 20 + (#characterOptions * lineHeight) + 8

	gfx.setColor(gfx.kColorWhite)
	gfx.fillRect(startX - 8, startY - 8, panelWidth, panelHeight)
	gfx.setColor(gfx.kColorBlack)
	gfx.drawRect(startX - 8, startY - 8, panelWidth, panelHeight)

	gfx.drawText("Choose character:", startX, startY)

	for index, characterName in ipairs(characterOptions) do
		local cursor = "  "
		if index == selectedCharacterIndex then
			cursor = "> "
		end
		gfx.drawText(cursor .. characterName, startX, startY + (index * lineHeight))
	end
end

function pd.update()
	local crankChange = pd.getCrankChange()
	crankAccumulator = crankAccumulator + crankChange

	while math.abs(crankAccumulator) >= degreesPerStep do
		if crankAccumulator > 0 then
			value = value + 1
			crankAccumulator = crankAccumulator - degreesPerStep
		else
			value = value - 1
			crankAccumulator = crankAccumulator + degreesPerStep
		end
	end

	if pd.buttonJustPressed(pd.kButtonA) then
		useAlternateBackground = not useAlternateBackground
	end

	if useAlternateBackground then
		updateCharacterSelection()
	end

	gfx.clear(gfx.kColorWhite)
	local backgroundToDraw = defaultBackgroundImage
	if useAlternateBackground and alternateBackgroundImage then
		backgroundToDraw = alternateBackgroundImage
	end

	if backgroundToDraw then
		backgroundToDraw:draw(0, 0)
	end

	local text = tostring(value)
	gfx.drawText(text, numberX, numberY)

	if useAlternateBackground then
		drawCharacterSelectionUi()
	end
end
