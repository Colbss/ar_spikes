return {

    deployer = {  -- Spike Deployer
        prop = 'spike_deployer', -- Prop model for deployer
        max = 2, -- Max per player
        frequency = { -- Frequency range for remote
            min = 100,
            max = 999,
        },
        maxDistance = 100.0, -- Max distance to deploy spikes
    },

    roll = { -- Spike Strip Roll
        prop = 'stinger_roll', -- Prop model for roll
        max = 2, -- Max per player
        anim = {
            bone = 28422,
            offset = vec3(0.1536, -0.0054, -0.0223),
            rotation = vec3(0.0, 0.0, 0.0),
            dict = 'move_weapon@jerrycan@generic',
            name = 'idle',
        }
    },

    immune = { -- Vehicles immune to spike strips
        [`monster`] = true,
    },

}