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

RegisterNetEvent('spikes:server:deploySpikes', function(coords, heading)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    -- Verify player has the deployer item
    local hasItem = exports.ox_inventory:GetItem(src, 'spike_deployer', nil, true)
    
    if hasItem and hasItem >= 1 then
        -- Remove one deployer from inventory
        exports.ox_inventory:RemoveItem(src, 'spike_deployer', 1)
        
        -- Generate unique spike ID
        local spikeId = generateSpikeId()
        
        -- Store spike data
        deployedSpikes[spikeId] = {
            owner = src,
            coords = coords,
            heading = heading,
            timestamp = os.time()
        }
        
        -- Broadcast to all players to create the spike prop
        TriggerClientEvent('spikes:client:createSpikeProp', -1, coords, heading, spikeId, src)
        
        -- Optional: Add notification
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Spike Strip',
            description = 'Spike strip deployed successfully',
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