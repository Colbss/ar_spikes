local config = require 'config'

-- Table to store deployed spikes
local deployedSpikes = {}

--
--  FUNCTIONS
--

local function cleanupAllSpikes()
    for spikeId, spikeData in pairs(deployedSpikes) do
        if DoesEntityExist(spikeData.entity) then
            DeleteEntity(spikeData.entity)
        end
    end
    deployedSpikes = {}
end

-- 
--  THREADS
--



--
-- EVENTS
--

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
	Wait(2000)
    
    -- Get active spikes

end)

-- Add event to create spike prop for all clients
RegisterNetEvent('spikes:client:createSpikeProp', function(coords, heading, spikeId, ownerServerId)
    local spikeModel = GetHashKey(config.deployer.prop)
    
    lib.requestModel(spikeModel)
    
    local spike = CreateObject(spikeModel, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(spike, heading)
    PlaceObjectOnGroundProperly(spike)
    FreezeEntityPosition(spike, true)
    
    -- Store spike for cleanup
    deployedSpikes[spikeId] = {
        entity = spike,
        coords = coords,
        heading = heading,
        owner = ownerServerId
    }
end)

-- Event to remove specific spike
RegisterNetEvent('spikes:client:removeSpike', function(spikeId)
    if deployedSpikes[spikeId] then
        if DoesEntityExist(deployedSpikes[spikeId].entity) then
            DeleteEntity(deployedSpikes[spikeId].entity)
        end
        deployedSpikes[spikeId] = nil
    end
end)

-- Event to cleanup spikes when player leaves
RegisterNetEvent('spikes:client:cleanupPlayerSpikes', function(serverId)
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.owner == serverId then
            if DoesEntityExist(spikeData.entity) then
                DeleteEntity(spikeData.entity)
            end
            deployedSpikes[spikeId] = nil
        end
    end
end)

--
--  EXPORTS
--

exports('useRoll', function(data, slot)

    exports.ox_inventory:useItem(data, function(data)
        print('Using Roll')
    end)

end)

exports('useDeployer', function(data, slot)
    exports.ox_inventory:useItem(data, function(data)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local playerHeading = GetEntityHeading(playerPed) - 90.0
        
        -- Calculate position in front of player
        local forwardVector = GetEntityForwardVector(playerPed)
        local deployCoords = vector3(
            playerCoords.x + forwardVector.x * 1.0,
            playerCoords.y + forwardVector.y * 1.0,
            playerCoords.z
        )
        
        -- Start animation
        lib.requestAnimDict('amb@world_human_gardener_plant@male@base')
        TaskPlayAnim(playerPed, 'amb@world_human_gardener_plant@male@base', 'base', 8.0, 8.0, -1, 1, 0, false, false, false)
        
        -- Show progress bar
        if lib.progressBar({
            duration = 3000,
            label = 'Dropping Spike Deployer...',
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            }
        }) then
            -- Progress completed successfully
            ClearPedTasks(playerPed)
            TriggerServerEvent('spikes:server:deploySpikes', deployCoords, playerHeading)
        else
            -- Progress was cancelled
            ClearPedTasks(playerPed)
        end
    end)
end)

exports('useRemote', function(data, slot)

    exports.ox_inventory:useItem(data, function(data)
        print('Using Remote')
    end)

end)

-- 
--  HANDLERS
--

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end

	-- Clean up all spikes
	cleanupAllSpikes()
end)