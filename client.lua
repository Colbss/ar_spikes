local config = require 'config'

-- Table to store deployed spikes
local deployedSpikes = {}
local deployedSpikeStrips = {} -- For standalone spike strips
local isCarryingRoll = false
local rollProp = nil
local rollStateBag = nil
local isPlacingSpikes = false
local spikeLength = 1

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
    
    -- Clean up spike strips
    for stripId, stripData in pairs(deployedSpikeStrips) do
        for _, spikeData in pairs(stripData.spikes) do
            if DoesEntityExist(spikeData.entity) then
                DeleteEntity(spikeData.entity)
            end
        end
    end
    deployedSpikeStrips = {}
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
    isPlacingSpikes = false
    ClearPedTasks(PlayerPedId())
    lib.hideTextUI()
end

local function PlayDeployAudio(entity)
    lib.requestAudioBank("dlc_stinger/stinger")
	local soundId = GetSoundId()
	PlaySoundFromEntity(soundId, "deploy_stinger", entity, "stinger", false, 0)
	ReleaseSoundId(soundId)
	ReleaseNamedScriptAudioBank("stinger")
end

local function deploySpikes(x, y, z, h)
    local spikeModel = 'p_ld_stinger_s'
    lib.requestModel(spikeModel)
    lib.requestAnimDict('P_ld_stinger_s')
    
    local stinger = CreateObject(spikeModel, x, y, z, true, true, false)
    SetEntityAsMissionEntity(stinger, true, true)
    SetEntityHeading(stinger, h)
    FreezeEntityPosition(stinger, true)
    PlaceObjectOnGroundProperly(stinger)
    SetEntityVisible(stinger, false)
    
    -- Play deploy animation
    PlayEntityAnim(stinger, "P_Stinger_S_Deploy", 'P_ld_stinger_s', 1000.0, false, true, 0, 0.0, 0)
    
    -- Wait for animation to start
    while not IsEntityPlayingAnim(stinger, 'P_ld_stinger_s', "P_Stinger_S_Deploy", 3) do
        Wait(0)
    end
    
    SetEntityAnimSpeed(stinger, 'P_ld_stinger_s', "P_Stinger_S_Deploy", 1.75)
    PlayDeployAudio(stinger)
    SetEntityVisible(stinger, true)
    
    -- Wait for deploy animation to finish
    while IsEntityPlayingAnim(stinger, 'P_ld_stinger_s', "P_Stinger_S_Deploy", 3) and 
          GetEntityAnimCurrentTime(stinger, "p_ld_stinger_s", "P_Stinger_S_Deploy") <= 0.99 do
        Wait(0)
    end
    
    -- Play idle animation
    PlayEntityAnim(stinger, "p_stinger_s_idle_deployed", 'P_ld_stinger_s', 1000.0, false, true, 0, 0.99, 0)
    
    return stinger
end

local function getSpikePositions(num, origin, heading)
    local positions = {}
    for i = 1, num do
        local pos = GetOffsetFromCoordAndHeadingInWorldCoords(origin.x, origin.y, origin.z, heading, 0.0, -1.5 + (3.5 * i), 0.15)
        positions[i] = vector4(pos.x, pos.y, pos.z, heading)
    end
    return positions
end

local function deployStandaloneSpikeStrip()
    if not isCarryingRoll or not isPlacingSpikes then return end
    
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    -- Start deploy animation
    lib.requestAnimDict('mp_weapons_deal_sting')
    TaskPlayAnim(playerPed, 'mp_weapons_deal_sting', 'crackhead_bag_loop', 5.0, 5.0, -1, 49, 1.0, false, false, false)
    
    -- Show progress bar
    if lib.progressBar({
        duration = 2000,
        label = 'Deploying spike strips...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        }
    }) then
        -- Get spike positions
        local positions = getSpikePositions(spikeLength, playerCoords, playerHeading)
        local tempProps = {}
        
        -- Deploy each spike strip
        for i = 1, spikeLength do
            local pos = positions[i]
            tempProps[i] = deploySpikes(pos.x, pos.y, pos.z, pos.w)
        end
        
        -- Send to server to create permanent spikes
        TriggerServerEvent('spikes:server:createSpikeStrip', positions)
        
        -- Clean up temporary props
        Wait(1000) -- Let players see the deployment
        for i = 1, spikeLength do
            if DoesEntityExist(tempProps[i]) then
                DeleteEntity(tempProps[i])
            end
        end
        
        -- Clean up
        cleanupRoll()
        
        lib.notify({
            description = 'Spike strips deployed successfully',
            type = 'success'
        })
    else
        -- Progress cancelled
        ClearPedTasks(playerPed)
    end
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

-- Event to create standalone spike strip
RegisterNetEvent('spikes:client:createSpikeStrip', function(stripId, positions, ownerServerId)
    local spikes = {}
    local spikeModel = 'p_ld_stinger_s'
    lib.requestModel(spikeModel)
    
    for i, pos in ipairs(positions) do
        local spike = CreateObject(spikeModel, pos.x, pos.y, pos.z, false, false, false)
        SetEntityHeading(spike, pos.w)
        PlaceObjectOnGroundProperly(spike)
        FreezeEntityPosition(spike, true)
        
        -- Set to deployed state
        PlayEntityAnim(spike, "p_stinger_s_idle_deployed", 'P_ld_stinger_s', 1000.0, false, true, 0, 0.99, 0)
        
        spikes[i] = {
            entity = spike,
            coords = pos
        }
    end
    
    deployedSpikeStrips[stripId] = {
        spikes = spikes,
        owner = ownerServerId
    }
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

-- Event to remove spike strip
RegisterNetEvent('spikes:client:removeSpikeStrip', function(stripId)
    if deployedSpikeStrips[stripId] then
        for _, spikeData in pairs(deployedSpikeStrips[stripId].spikes) do
            if DoesEntityExist(spikeData.entity) then
                DeleteEntity(spikeData.entity)
            end
        end
        deployedSpikeStrips[stripId] = nil
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
    
    local ped = GetPlayerPed(playerId)
    if not DoesEntityExist(ped) then return end
    
    if value then
        -- Player started carrying roll - attach prop for all players (including self)
        local rollModel = GetHashKey(config.roll.prop)
        lib.requestModel(rollModel)
        
        local prop = CreateObject(rollModel, 0, 0, 0, false, false, false)
        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, config.roll.anim.bone), 
            config.roll.anim.offset.x, config.roll.anim.offset.y, config.roll.anim.offset.z,
            config.roll.anim.rotation.x, config.roll.anim.rotation.y, config.roll.anim.rotation.z,
            true, true, false, true, 1, true)
        
        -- Store for cleanup
        if playerId == PlayerId() then
            rollProp = prop
        else
            Entity(ped).state.rollProp = prop
        end
    else
        -- Player stopped carrying roll
        if playerId == PlayerId() then
            if rollProp and DoesEntityExist(rollProp) then
                DeleteEntity(rollProp)
                rollProp = nil
            end
        else
            local prop = Entity(ped).state.rollProp
            if prop and DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
            Entity(ped).state.rollProp = nil
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
            
            local playerPed = PlayerPedId()
            
            -- Load animation
            lib.requestAnimDict(config.roll.anim.dict)
            
            -- Start animation (upper body only)
            TaskPlayAnim(playerPed, config.roll.anim.dict, config.roll.anim.name, 8.0, 8.0, -1, 49, 0, false, false, false)
            
            -- Set state
            isCarryingRoll = true
            isPlacingSpikes = true
            rollStateBag = LocalPlayer.state
            rollStateBag:set('spikestripCarrying', true, true)
            
            -- Show initial text UI
            lib.showTextUI(string.format(
                'Current Length: %d\n[UP] Increase Length\n[DOWN] Decrease Length\n[E] Deploy Spikes\n[BACKSPACE/ESC] Cancel',
                spikeLength
            ))
            
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
            
            -- Handle input for spike placement
            CreateThread(function()
                while isCarryingRoll and isPlacingSpikes do
                    Wait(0)
                    
                    -- Increase length
                    if IsControlJustPressed(0, 172) then -- UP Arrow
                        if spikeLength < 4 then
                            spikeLength = spikeLength + 1
                            lib.showTextUI(string.format(
                                'Current Length: %d\n[UP] Increase Length\n[DOWN] Decrease Length\n[E] Deploy Spikes\n[BACKSPACE/ESC] Cancel',
                                spikeLength
                            ))
                        end
                    end
                    
                    -- Decrease length
                    if IsControlJustPressed(0, 173) then -- DOWN Arrow
                        if spikeLength > 1 then
                            spikeLength = spikeLength - 1
                            lib.showTextUI(string.format(
                                'Current Length: %d\n[UP] Increase Length\n[DOWN] Decrease Length\n[E] Deploy Spikes\n[BACKSPACE/ESC] Cancel',
                                spikeLength
                            ))
                        end
                    end
                    
                    -- Deploy spikes
                    if IsControlJustPressed(0, 38) then -- E
                        deployStandaloneSpikeStrip()
                        break
                    end
                    
                    -- Cancel
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
                    TriggerServerEvent('spikes:server:remoteDeploySpikes', spikeId)
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