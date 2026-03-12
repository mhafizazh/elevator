import "CoreLibs/graphics"
import "core/game"

local pd = playdate
local game = Game.new()

function pd.update()
	game:update()
	game:draw()
end
