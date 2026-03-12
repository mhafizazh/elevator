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
    medkit = {
        id = "medkit",
        name = "Medkit",
        floorBonus = {
            trap = 20,
            radiation = 8,
        }
    }
}

return Items