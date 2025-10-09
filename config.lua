return {

    deployer = {  -- Spike Deployer
        prop = 'spike_deployer', -- Prop model for deployer
        max = 2, -- Max per player
        frequency = { -- Frequency range for remote
            min = 100,
            max = 999,
        }
    },

    roll = { -- Spike Strip Roll
        prop = 'stinger_roll', -- Prop model for roll
        max = 2, -- Max per player
    },

    immune = { -- Vehicles immune to spike strips
        [`monster`] = true,
    },

}