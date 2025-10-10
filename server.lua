local config = require 'config'

-- Table to store deployed spikes
local deployedSpikes = {}
local spikeIdCounter = 0

--
-- FUNCTIONS
--

local function generateSpikeId()
    spikeIdCounter = spikeIdCounter + 1
    return spikeIdCounter
end

local function generateFrequency()
    return math.random(config.deployer.frequency.min, config.deployer.frequency.max)
end

local function removePlayerSpikes(serverId)
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.owner == serverId then
            -- Remove from tracking
            deployedSpikes[spikeId] = nil
            -- Tell all clients to remove this spike
            TriggerClientEvent('spikes:client:removeSpike', -1, spikeId)
        end
    end
end

--
-- EVENTS
--

RegisterNetEvent('spikes:server:deployDeployer', function(coords, heading)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    -- Verify player has the deployer item
    local hasItem = exports.ox_inventory:GetItem(src, 'spike_deployer', nil, true)
    
    if hasItem and hasItem >= 1 then
        -- Remove one deployer from inventory
        exports.ox_inventory:RemoveItem(src, 'spike_deployer', 1)
        
        -- Generate unique spike ID and frequency
        local spikeId = generateSpikeId()
        local frequency = generateFrequency()
        
        -- Store spike data
        deployedSpikes[spikeId] = {
            owner = src,
            coords = coords,
            heading = heading,
            frequency = frequency,
            timestamp = os.time()
        }
        
        -- Broadcast to all players to create the spike prop
        TriggerClientEvent('spikes:client:createSpikeProp', -1, coords, heading, spikeId, src, frequency)
        
        -- Optional: Add notification
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip',
            description = 'Spike strip deployed on frequency: ' .. frequency .. ' MHz',
            type = 'success'
        })
    else
        -- Player doesn't have the item (possible exploit attempt)
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip',
            description = 'You don\'t have a spike deployer',
            type = 'error'
        })
    end
end)

RegisterNetEvent('spikes:server:pickupSpike', function(spikeId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip Deployer',
            description = 'Deployer not found',
            type = 'error'
        })
    end
    
    -- Check if player is the owner
    if spikeData.owner ~= src then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip Deployer',
            description = 'You can only pick up your own deployer',
            type = 'error'
        })
    end
    
    -- Check distance (optional security measure)
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local distance = #(playerCoords - vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z))
    
    if distance > 5.0 then
        return TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip Deployer',
            description = 'You are too far away from the deployer',
            type = 'error'
        })
    end
    
    -- Give back the deployer item
    exports.ox_inventory:AddItem(src, 'spike_deployer', 1)
    
    -- Remove spike from tracking
    deployedSpikes[spikeId] = nil
    
    -- Tell all clients to remove this spike
    TriggerClientEvent('spikes:client:removeSpike', -1, spikeId)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Spike Strip Deployer',
        description = 'Deployer picked up',
        type = 'success'
    })
end)

-- Server-side event to tune the remote
RegisterNetEvent('spikes:server:tuneRemoteFrequency', function(slot, frequency)
    local src = source
    
    -- Verify item ownership again (for security)
    local item = exports.ox_inventory:GetSlot(src, slot)
    if item and item.name == 'spike_deployer_remote' then
        exports.ox_inventory:SetMetadata(src, slot, {frequency = frequency})
    end
end)

-- Server-side event to deploy spikes remotely
RegisterNetEvent('spikes:server:deployRemoteSpikes', function(spikeId)
    local src = source
    
    -- Get the spike data from your server-side storage
    local spikeData = deployedSpikes[spikeId]
    
    if spikeData then
        -- Notify all clients to activate these spikes
        TriggerClientEvent('spikes:client:activateSpikes', -1, spikeId)
    end
end)