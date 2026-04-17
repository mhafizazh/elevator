-- source/core/data/items.lua
Items = {
    gun = {
        id = "gun",
        name = "Gun",
        floorBonus = {
            criminal = 25,
            zombie = 15,
        },
        characterBonus = {
            dad = {
                criminal = 10,
                zombie = 5,
            }
        }
    },
    knife = {
        id = "knife",
        name = "Knife",
        floorBonus = {
            criminal = 10,
            zombie = 8,
            trap = 5,
        }
    },
    flashlight = {
        id = "flashlight",
        name = "Flashlight",
        floorBonus = {
            zombie = 20,
            trap = 6,
        }
    },
    gas_mask = {
        id = "gas_mask",
        name = "Gas Mask",
        floorBonus = {
            radiation = 45,
        },
        grantsRequirement = {
            radiation = true,
        }
    },
    backpack = {
        id = "backpack",
        name = "Backpack",
        floorBonus = {},
        isCollectible = true,
        collectibleOnly = true,
    },
    grappling_hook = {
        id = "grappling_hook",
        name = "Grappling Hook",
        floorBonus = {
            trap = 15,
            criminal = 8,
        },
        isCollectible = true,
    },
    rope = {
        id = "rope",
        name = "Rope",
        floorBonus = {
            trap = 12,
            criminal = 6,
        },
        isCollectible = true,
    },
    compass = {
        id = "compass",
        name = "Compass",
        floorBonus = {
            zombie = 10,
            safe = 5,
        },
        isCollectible = true,
    },
    strength_drink = {
        id = "strength_drink",
        name = "Strength Drink",
        floorBonus = {
            criminal = 12,
            zombie = 7,
        },
        isCollectible = true,
    }
}

return Items