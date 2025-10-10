local config = require 'config'

-- Unified table for all spike systems
local deployedSpikes = {}
local spikeIdCounter = 0

-- Spike types and states
local SPIKE_TYPES = {
    STANDALONE = 'standalone',
    REMOTE_DEPLOYER = 'remote_deployer'
}

local SPIKE_STATES = {
    PLACED = 'placed',      -- For remote deployers (not deployed)
    DEPLOYED = 'deployed'   -- For both types when spikes are active
}

local function generateSpikeId()
    spikeIdCounter = spikeIdCounter + 1
    return spikeIdCounter
end

local function generateFrequency()
    return math.random(config.deployer.frequency.min, config.deployer.frequency.max)
end

local function getSpikePositions(num, origin, heading)
    local positions = {}
    for i = 1, num do
        local pos = GetOffsetFromCoordAndHeadingInWorldCoords(origin.x, origin.y, origin.z, heading, 0.0, -1.5 + (3.5 * i), 0.15)
        positions[i] = vector4(pos.x, pos.y, pos.z, heading)
    end
    return positions
end

local function removePlayerSpikes(serverId)
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.owner == serverId then
            deployedSpikes[spikeId] = nil
            TriggerClientEvent('spikes:client:removeSpike', -1, spikeId)
        end
    end
end

-- Unified event to create any spike type
RegisterNetEvent('spikes:server:createSpike', function(spikeData)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local spikeId = generateSpikeId()
    
    if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER then
        -- Handle remote deployer
        local hasItem = exports.ox_inventory:GetItem(src, 'spike_deployer', nil, true)
        
        if hasItem and hasItem >= 1 then
            exports.ox_inventory:RemoveItem(src, 'spike_deployer', 1)
            
            local frequency = generateFrequency()
            
            -- Store spike data
            deployedSpikes[spikeId] = {
                type = SPIKE_TYPES.REMOTE_DEPLOYER,
                state = SPIKE_STATES.PLACED,
                owner = src,
                coords = spikeData.coords,
                heading = spikeData.heading,
                frequency = frequency,
                timestamp = os.time()
            }
            
            -- Send to all clients
            TriggerClientEvent('spikes:client:createSpike', -1, spikeId, {
                type = SPIKE_TYPES.REMOTE_DEPLOYER,
                coords = spikeData.coords,
                heading = spikeData.heading,
                frequency = frequency
            }, src)
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Spike Strip',
                description = 'Spike deployer placed on frequency: ' .. frequency .. ' MHz',
                type = 'success'
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Spike Strip',
                description = 'You don\'t have a spike deployer',
                type = 'error'
            })
        end
        
    elseif spikeData.type == SPIKE_TYPES.STANDALONE then
        -- Handle standalone spike strip
        local hasItem = exports.ox_inventory:GetItem(src, 'spike_roll', nil, true)
        
        if hasItem and hasItem >= 1 then
            exports.ox_inventory:RemoveItem(src, 'spike_roll', 1)
            
            -- Store spike data
            deployedSpikes[spikeId] = {
                type = SPIKE_TYPES.STANDALONE,
                state = SPIKE_STATES.DEPLOYED,
                owner = src,
                positions = spikeData.positions,
                length = spikeData.length,
                timestamp = os.time()
            }
            
            -- Send to all clients
            TriggerClientEvent('spikes:client:createSpike', -1, spikeId, {
                type = SPIKE_TYPES.STANDALONE,
                positions = spikeData.positions
            }, src)
            
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Spike Strips',
                description = 'Spike strips deployed successfully',
                type = 'success'
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Spike Strips',
                description = 'You don\'t have a spike roll',
                type = 'error'
            })
        end
    end
end)

-- Callback to verify remote spike deployment
lib.callback.register('spikes:server:verifyRemoteDeployment', function(source, spikeId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then
        return { success = false, message = "Player not found" }
    end
    
    local spikeData = deployedSpikes[spikeId]
    if not spikeData or spikeData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= SPIKE_STATES.PLACED then
        return { 
            success = false, 
            message = "Deployer not found or already deployed" 
        }
    end
    
    -- Check distance from player to deployer
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local deployerCoords = vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z)
    local distance = #(playerCoords - deployerCoords)
    
    if distance > config.deployer.maxDistance then
        return { 
            success = false, 
            message = string.format('Deployer is too far away (%.1fm). Max range: %.1fm', distance, config.deployer.maxDistance)
        }
    end
    
    -- Return deployer data for client-side processing
    return { 
        success = true, 
        deployerData = {
            coords = spikeData.coords,
            heading = spikeData.heading,
            frequency = spikeData.frequency
        }
    }
end)

-- Event to update spike state after client deployment
RegisterNetEvent('spikes:server:updateSpikeState', function(spikeId, positions)
    local src = source
    local spikeData = deployedSpikes[spikeId]
    
    if not spikeData or spikeData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= SPIKE_STATES.PLACED then
        return
    end
    
    -- Update server data
    deployedSpikes[spikeId].state = SPIKE_STATES.DEPLOYED
    deployedSpikes[spikeId].positions = positions
    
    -- Tell all clients to deploy the spikes
    TriggerClientEvent('spikes:client:deployRemoteSpikes', -1, spikeId, positions)
    
    -- Notify the player
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Spike Strip',
        description = 'Remote spikes deployed successfully',
        type = 'success'
    })
end)

RegisterNetEvent('spikes:server:tuneRemoteFrequency', function(slot, frequency)
    local src = source
    
    -- Verify item ownership again (for security)
    local item = exports.ox_inventory:GetSlot(src, slot)
    if item and item.name == 'spike_deployer_remote' then
        exports.ox_inventory:SetMetadata(src, slot, {frequency = frequency})
    end
end)

RegisterNetEvent('spikes:server:pickupSpike', function(spikeId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip',
            description = 'Spike system not found',
            type = 'error'
        })
    end
    
    -- Check if player is the owner
    if spikeData.owner ~= src then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip',
            description = 'You can only pick up your own equipment',
            type = 'error'
        })
    end
    
    -- Only allow pickup of remote deployers that haven't deployed spikes
    if spikeData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= SPIKE_STATES.PLACED then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip',
            description = 'Cannot pick up deployed spike systems',
            type = 'error'
        })
    end
    
    -- Check distance
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local distance = #(playerCoords - vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z))
    
    if distance > 5.0 then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip',
            description = 'You are too far away',
            type = 'error'
        })
    end
    
    -- Give back the appropriate item
    if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER then
        exports.ox_inventory:AddItem(src, 'spike_deployer', 1)
    end
    
    -- Remove spike from tracking
    deployedSpikes[spikeId] = nil
    
    -- Tell all clients to remove this spike
    TriggerClientEvent('spikes:client:removeSpike', -1, spikeId)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Spike Strip',
        description = 'Equipment picked up',
        type = 'success'
    })
end)

-- Clean up spikes when player disconnects
AddEventHandler('playerDropped', function(reason)
    local src = source
    removePlayerSpikes(src)
end)