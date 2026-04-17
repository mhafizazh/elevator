import "CoreLibs/graphics"

local gfx = playdate.graphics

Images = {}

function Images.load()
	return {
		defaultBackground = gfx.image.new("image/dither_it_ChatGPT Image Mar 25, 2026, 09_52_31 PM"),
		alternateBackground = gfx.image.new("image/dither_it_ChatGPT Image Mar 25, 2026, 10_24_51 PM"),
		keyCutscene = gfx.image.new("image/cutscene/key_found"),
		backpackCutscene = gfx.image.new("image/cutscene/backpack_found"),
		medkitCutscene = gfx.image.new("image/cutscene/medkit_found"),
		characters = {
			dad = gfx.image.new("image/character/dad"),
			mom = gfx.image.new("image/character/mom"),
			son = gfx.image.new("image/character/leo"),
			daughter = gfx.image.new("image/character/Mia"),
		},
	}
end
