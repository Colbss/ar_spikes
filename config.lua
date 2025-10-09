return {

    remote = {  -- Remote Deployer
        max = 2 -- Max per player
        frequency = { -- Frequency range for remote
            min = 100,
            max = 999,
        }
    },

    roll = { -- Spike Strip Roll
        max = 2 -- Max per player
    }

    immune = { -- Vehicles immune to spike strips
        [`monster`] = true
    }

}