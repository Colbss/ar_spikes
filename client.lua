local config = require 'config'

-- Table to store deployed spikes
local deployedSpikes = {}
local isCarryingRoll = false
local rollProp = nil
local rollStateBag = nil

--
--  FUNCTIONS
--

local function cleanupAllSpikes()
    for spikeId, spikeData in pairs(deployedSpikes) do
        if DoesEntityExist(spikeData.entity) then
            -- Remove target before deleting entity
            exports.ox_target:removeLocalEntity(spikeData.entity)
            DeleteEntity(spikeData.entity)
        end
    end
    deployedSpikes = {}
end

local function cleanupRoll()
    if rollProp and DoesEntityExist(rollProp) then
        DeleteEntity(rollProp)
        rollProp = nil
    end
    if rollStateBag then
        rollStateBag:set('spikestripCarrying', false, true)
        rollStateBag = nil
    end
    isCarryingRoll = false
    ClearPedTasks(cache.ped)
    lib.hideTextUI()
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
RegisterNetEvent('spikes:client:createSpikeProp', function(coords, heading, spikeId, ownerServerId, frequency)
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
        owner = ownerServerId,
        frequency = frequency
    }
    
    -- Add target to the spike
    exports.ox_target:addLocalEntity(spike, {
        {
            name = 'spike_get_frequency',
            icon = 'fas fa-broadcast-tower',
            label = 'Get Frequency',
            onSelect = function()
                lib.notify({
                    title = 'Spike Strip Deployer',
                    description = 'Frequency: ' .. frequency .. ' MHz',
                    type = 'inform'
                })
            end
        },
        {
            name = 'spike_pickup',
            icon = 'fas fa-hand-paper',
            label = 'Pick Up Deployer',
            canInteract = function()
                return ownerServerId == cache.serverId
            end,
            onSelect = function()
                TriggerServerEvent('spikes:server:pickupSpike', spikeId)
            end
        }
    })
end)

-- Event to remove specific spike
RegisterNetEvent('spikes:client:removeSpike', function(spikeId)
    if deployedSpikes[spikeId] then
        if DoesEntityExist(deployedSpikes[spikeId].entity) then
            -- Remove target before deleting entity
            exports.ox_target:removeLocalEntity(deployedSpikes[spikeId].entity)
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
                -- Remove target before deleting entity
                exports.ox_target:removeLocalEntity(spikeData.entity)
                DeleteEntity(spikeData.entity)
            end
            deployedSpikes[spikeId] = nil
        end
    end
end)

-- Statebag handler for roll carrying
AddStateBagChangeHandler('spikestripCarrying', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end
    
    local playerId = GetPlayerFromStateBagName(bagName)
    if playerId == -1 then return end
    
    local targetPed = GetPlayerPed(playerId)
    if not DoesEntityExist(targetPed) then return end
    
    if value then
        -- Player started carrying roll - attach prop for all players (including self)
        local rollModel = GetHashKey(config.roll.prop)
        lib.requestModel(rollModel)
        
        local prop = CreateObject(rollModel, 0, 0, 0, false, false, false)
        AttachEntityToEntity(prop, targetPed, GetPedBoneIndex(targetPed, config.roll.anim.bone), 
            config.roll.anim.offset.x, config.roll.anim.offset.y, config.roll.anim.offset.z,
            config.roll.anim.rotation.x, config.roll.anim.rotation.y, config.roll.anim.rotation.z,
            true, true, false, true, 1, true)
        
        -- Store for cleanup
        if playerId == cache.playerId then
            rollProp = prop
        else
            Entity(targetPed).state.rollProp = prop
        end
    else
        -- Player stopped carrying roll
        if playerId == cache.playerId then
            if rollProp and DoesEntityExist(rollProp) then
                DeleteEntity(rollProp)
                rollProp = nil
            end
        else
            local prop = Entity(targetPed).state.rollProp
            if prop and DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
            Entity(targetPed).state.rollProp = nil
        end
    end
end)

--
--  EXPORTS
--

exports('useRoll', function(data, slot)
    exports.ox_inventory:useItem(data, function(data)

        if data then

            if isCarryingRoll then
                return lib.notify({
                    description = 'You are already carrying a spike roll.',
                    type = 'error'
                })
            end
            
            if cache.vehicle then
                return lib.notify({
                    description = 'You cannot use this in a vehicle.',
                    type = 'error'
                })
            end
            
            -- Load animation
            lib.requestAnimDict(config.roll.anim.dict)
            
            -- Start animation (upper body only)
            TaskPlayAnim(cache.ped, config.roll.anim.dict, config.roll.anim.name, 8.0, 8.0, -1, 49, 0, false, false, false)
            
            -- Set state
            isCarryingRoll = true
            rollStateBag = LocalPlayer.state
            rollStateBag:set('spikestripCarrying', true, true)
            
            -- Show text UI
            lib.showTextUI('Deploying spikes - [BACKSPACE] or [ESC] to cancel')
            
            -- Watch for vehicle entry
            lib.onCache('vehicle', function(vehicle)
                if isCarryingRoll and vehicle then
                    cleanupRoll()
                    lib.notify({
                        description = 'Spike roll placement cancelled - entered vehicle.',
                        type = 'error'
                    })
                end
            end)
            
            -- Handle input for cancellation
            CreateThread(function()
                while isCarryingRoll do
                    Wait(0)
                    
                    -- Check for cancel keys
                    if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 322) then -- Backspace or ESC
                        cleanupRoll()
                        break
                    end
                end
            end)

        end

    end)
end)

exports('useDeployer', function(data)
    exports.ox_inventory:useItem(data, function(data)

        if data then

            if cache.vehicle then
                return lib.notify({
                    description = 'You cannot deploy in a vehicle.',
                    type = 'error'
                })
            end
    
            local playerCoords = GetEntityCoords(cache.ped)
            local playerHeading = GetEntityHeading(cache.ped) - 90.0
            
            -- Calculate position in front of player
            local forwardVector = GetEntityForwardVector(cache.ped)
            local deployCoords = vector3(
                playerCoords.x + forwardVector.x * 1.0,
                playerCoords.y + forwardVector.y * 1.0,
                playerCoords.z
            )
            
            -- Start animation
            lib.requestAnimDict('mp_weapons_deal_sting')
            TaskPlayAnim(cache.ped, 'mp_weapons_deal_sting', 'crackhead_bag_loop', 8.0, 8.0, -1, 1, 0, false, false, false)
            
            -- Show progress bar
            if lib.progressBar({
                duration = 3000,
                label = 'Dropping Spike Deployer...',
                useWhileDead = false,
                allowCuffed = false,
                allowSwimming = false,
                canCancel = true,
                disable = {
                    car = true,
                    move = true,
                    combat = true
                }
            }) then
                -- Progress completed successfully
                ClearPedTasks(cache.ped)
                TriggerServerEvent('spikes:server:deployDeployer', deployCoords, playerHeading)
            else
                -- Progress was cancelled
                ClearPedTasks(cache.ped)
            end

        end

    end)
end)

exports('useRemote', function(data)
    exports.ox_inventory:useItem(data, function(data)

        if data then

            print('OK')
            lib.print.info(data)
    
            -- Check if the remote has a frequency set
            if not data.metadata or not data.metadata?.frequency then
                return lib.notify({
                    description = 'Remote is not tuned to a frequency.',
                    type = 'error'
                })
            end
            
            local frequency = data.metadata.frequency
            
            -- Look for a deployer with matching frequency
            local foundDeployer = false
            for spikeId, spikeData in pairs(deployedSpikes) do
                if spikeData.frequency == frequency then
                    foundDeployer = true
                    -- Trigger server event to deploy the spikes from this deployer
                    TriggerServerEvent('spikes:server:deployRemoteSpikes', spikeId)
                    break
                end
            end
            
            if not foundDeployer then
                lib.notify({
                    description = 'No deployer found on frequency ' .. frequency .. ' MHz.',
                    type = 'error'
                })
            end

        end


    end)
end)

exports('tuneFrequency', function(data)

    exports.ox_inventory:useItem(data, function(data)
        if data then

            print('OK')
            lib.print.info(data)

            -- Show input dialog to tune the frequency
            local input = lib.inputDialog('Tune Remote Frequency', {
                {type = 'number', label = 'Frequency (MHz)', description = 'Enter frequency between 100-999', default = 100, min = 100, max = 999}
            })
            
            if not input or not input[1] then return end
            
            local frequency = math.floor(input[1])
            
            -- Update the metadata on the server
            TriggerServerEvent('spikes:server:tuneRemoteFrequency', data.slot, frequency)
            
            lib.notify({
                description = 'Remote tuned to ' .. frequency .. ' MHz',
                type = 'success'
            })
        end
    end)
end)

-- 
--  HANDLERS
--

exports.ox_inventory:displayMetadata({
    frequency = 'Frequency',
})

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end

    -- Clean up roll if carrying
    if isCarryingRoll then
        cleanupRoll()
    end
    
	-- Clean up all spikes
	cleanupAllSpikes()
end)

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    
    -- Clean up any existing spikes on restart
    cleanupAllSpikes()
    
    -- Clean up roll state
    if isCarryingRoll then
        cleanupRoll()
    end
end)