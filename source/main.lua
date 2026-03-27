import "CoreLibs/graphics"
import "core/build_flags"
import "core/game"

local pd = playdate
local game = Game.new()

function pd.update()
	game:update()
	game:draw()
end
