-- source/core/data/characters.lua
Characters = {
    dad = {
        id = "dad",
        name = "Dad",
        alive = true,
        stats = { combat = 8, stealth = 2, survival = 4, luck = 3 },
        imagePath = "image/character/dad"
    },
    mom = {
        id = "mom",
        name = "Mom",
        alive = true,
        stats = { combat = 3, stealth = 7, survival = 6, luck = 4 },
        imagePath = "image/character/mom"
    },
    son = {
        id = "son",
        name = "Leo",
        alive = true,
        stats = { combat = 4, stealth = 4, survival = 3, luck = 4 },
        imagePath = "image/character/leo"
    },
    daughter = {
        id = "daughter",
        name = "Mia",
        alive = true,
        stats = { combat = 3, stealth = 5, survival = 4, luck = 8 },
        imagePath = "image/character/Mia"
    },
}

return Characters