return {

    deployer = {  -- Spike Deployer
        prop = 'spike_deployer', -- Prop model for deployer
        max = 2, -- Max per player
        frequency = { -- Frequency range for remote
            min = 100,
            max = 999,
        },
        maxDistance = 200.0, -- Max distance to deploy spikes
        anim = {
            prop = 'deployer_remote',
            tune = {
                bone = 28422,
                offset = vec3(0.00, 0.01, 0.0),
                rotation = vec3(99.41, -3.64, -0.60),
                dict = 'cellphone@',
                name = 'cellphone_text_read_base',
                flags = 49,
            },
            deploy = {
                bone = 28422,
                offset = vec3(0.0, 0.01, 0.0),
                rotation = vec3(0.0, 0.0, 0.0),
                dict = 'anim@mp_player_intmenu@key_fob@', 
                name = 'fob_click',
                flags = 48,
            },
            use = {
                dict = 'mp_weapons_deal_sting',
                name = 'crackhead_bag_loop',
                flags = 1,
            }

        },
        jobs = { -- job, min rank
            ['police'] = 2,
        }
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
        },
        jobs = nil, -- Refer above
    },

    immune = { -- Vehicles immune to spike strips
        [`monster`] = true,
    },

}