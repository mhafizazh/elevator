import "CoreLibs/graphics"

local gfx = playdate.graphics

Images = {}

function Images.load()
	return {
		defaultBackground = gfx.image.new("image/game_bg"),
		alternateBackground = gfx.image.new("image/game_bg2"),
	}
end
