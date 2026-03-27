import "CoreLibs/graphics"

local gfx = playdate.graphics

Images = {}

function Images.load()
	return {
		defaultBackground = gfx.image.new("image/dither_it_ChatGPT Image Mar 25, 2026, 09_52_31 PM"),
		alternateBackground = gfx.image.new("image/dither_it_ChatGPT Image Mar 25, 2026, 10_24_51 PM"),
	}
end
