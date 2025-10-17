local config = require 'config'

-- Unified table for all spike systems
local deployedSpikes = {} -- Now stores both types
local isCarryingRoll = false
local rollProp = nil
local rollStateBag = nil
local isPlacingSpikes = false
local spikeLength = 1

-- Spike types and states
local SPIKE_TYPES = {
    STANDALONE = 'standalone',
    REMOTE_DEPLOYER = 'remote_deployer'
}

local SPIKE_STATES = {
    PLACED = 'placed',      -- For remote deployers (not deployed)
    DEPLOYED = 'deployed'   -- For both types when spikes are active
}

local function cleanupAllSpikes()
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER then
            -- Remote deployer cleanup
            if DoesEntityExist(spikeData.deployer.entity) then
                exports.ox_target:removeLocalEntity(spikeData.deployer.entity)
                DeleteEntity(spikeData.deployer.entity)
            end
            -- Clean up deployed spikes if any
            if spikeData.spikes then
                for _, spike in pairs(spikeData.spikes) do
                    if DoesEntityExist(spike.entity) then
                        DeleteEntity(spike.entity)
                    end
                end
            end
        elseif spikeData.type == SPIKE_TYPES.STANDALONE then
            -- Standalone spike strip cleanup
            if spikeData.spikes then
                for _, spike in pairs(spikeData.spikes) do
                    if DoesEntityExist(spike.entity) then
                        DeleteEntity(spike.entity)
                    end
                end
            end
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
    isPlacingSpikes = false
    ClearPedTasks(cache.ped)
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

local function createSpikeStrip(positions, parentId)
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
    
    return spikes
end

local function deployStandaloneSpikeStrip()
    if not isCarryingRoll or not isPlacingSpikes then return end
    
    local playerCoords = GetEntityCoords(cache.ped)
    local playerHeading = GetEntityHeading(cache.ped)
    
    -- Start deploy animation
    lib.requestAnimDict('mp_weapons_deal_sting')
    TaskPlayAnim(cache.ped, 'mp_weapons_deal_sting', 'crackhead_bag_loop', 5.0, 5.0, -1, 49, 1.0, false, false, false)
    
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
        TriggerServerEvent('colbss-spikes:server:createSpike', {
            type = SPIKE_TYPES.STANDALONE,
            positions = positions,
            length = spikeLength
        })
        
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
        ClearPedTasks(cache.ped)
    end
end

local function deployRemoteSpikes(spikeId)
    -- Verify with server that deployment is allowed
    local result = lib.callback.await('colbss-spikes:server:verifyRemoteDeployment', false, spikeId)
    
    if not result.success then
        return lib.notify({
            title = 'Spike Strip',
            description = result.message,
            type = 'error'
        })
    end
    
    local deployerData = result.deployerData
    
    -- Adjust heading to deploy spikes 90 degrees left of the deployer
    local spikeHeading = deployerData.heading + 90.0
    if spikeHeading >= 360.0 then
        spikeHeading = spikeHeading - 360.0
    end
    
    -- Get spike positions relative to deployer (perpendicular to deployer heading)
    local positions = getSpikePositions(2, deployerData.coords, spikeHeading)
    local tempProps = {}
    
    -- Deploy each spike strip with animation
    for i = 1, 2 do
        local pos = positions[i]
        tempProps[i] = deploySpikes(pos.x, pos.y, pos.z, pos.w)
    end
    
    -- Wait for deployment animation
    Wait(1000)
    
    -- Clean up temporary props
    for i = 1, 2 do
        if DoesEntityExist(tempProps[i]) then
            DeleteEntity(tempProps[i])
        end
    end
    
    -- Update server with new spike positions
    TriggerServerEvent('colbss-spikes:server:updateSpikeState', spikeId, positions)
end

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
        if playerId == PlayerId() then
            rollProp = prop
        else
            Entity(targetPed).state.rollProp = prop
        end
    else
        -- Player stopped carrying roll
        if playerId == PlayerId() then
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

-- Unified event to create any spike type
RegisterNetEvent('colbss-spikes:client:createSpike', function(spikeId, spikeData, ownerServerId)
    if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER then
        -- Create remote deployer prop
        local deployerModel = GetHashKey(config.deployer.prop)
        lib.requestModel(deployerModel)
        
        local deployer = CreateObject(deployerModel, spikeData.coords.x, spikeData.coords.y, spikeData.coords.z, false, false, false)
        SetEntityHeading(deployer, spikeData.heading)
        PlaceObjectOnGroundProperly(deployer)
        FreezeEntityPosition(deployer, true)
        
        -- Store in unified table
        deployedSpikes[spikeId] = {
            type = SPIKE_TYPES.REMOTE_DEPLOYER,
            state = SPIKE_STATES.PLACED,
            owner = ownerServerId,
            frequency = spikeData.frequency,
            deployer = {
                entity = deployer,
                coords = spikeData.coords,
                heading = spikeData.heading
            },
            spikes = nil -- No spikes deployed yet
        }
        
        -- Add target to the deployer
        exports.ox_target:addLocalEntity(deployer, {
            {
                name = 'spike_get_frequency',
                icon = 'fas fa-broadcast-tower',
                label = 'Get Frequency',
                onSelect = function()
                    lib.notify({
                        title = 'Spike Strip Deployer',
                        description = 'Frequency: ' .. spikeData.frequency .. ' MHz',
                        type = 'inform'
                    })
                end
            },
            {
                name = 'spike_pickup',
                icon = 'fas fa-hand-paper',
                label = 'Pick Up Deployer',
                canInteract = function()
                    return ownerServerId == cache.serverId and deployedSpikes[spikeId].state == SPIKE_STATES.PLACED
                end,
                onSelect = function()
                    TriggerServerEvent('colbss-spikes:server:pickupSpike', spikeId)
                end
            }
        })
        
    elseif spikeData.type == SPIKE_TYPES.STANDALONE then
        -- Create standalone spike strip
        local spikes = createSpikeStrip(spikeData.positions, spikeId)
        
        -- Store in unified table
        deployedSpikes[spikeId] = {
            type = SPIKE_TYPES.STANDALONE,
            state = SPIKE_STATES.DEPLOYED,
            owner = ownerServerId,
            spikes = spikes
        }
    end
end)

-- Event to deploy spikes from a remote deployer
RegisterNetEvent('colbss-spikes:client:deployRemoteSpikes', function(spikeId, positions)
    local spikeData = deployedSpikes[spikeId]
    if not spikeData or spikeData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= SPIKE_STATES.PLACED then
        return
    end
    
    -- Create the spike strips
    local spikes = createSpikeStrip(positions, spikeId)
    
    -- Update the spike data
    deployedSpikes[spikeId].spikes = spikes
    deployedSpikes[spikeId].state = SPIKE_STATES.DEPLOYED
    
    -- Update target options (replace pickup with reset since spikes are deployed)
    if DoesEntityExist(spikeData.deployer.entity) then
        exports.ox_target:removeLocalEntity(spikeData.deployer.entity)
        exports.ox_target:addLocalEntity(spikeData.deployer.entity, {
            {
                name = 'spike_get_frequency',
                icon = 'fas fa-broadcast-tower',
                label = 'Get Frequency',
                onSelect = function()
                    lib.notify({
                        title = 'Spike Strip Deployer',
                        description = 'Frequency: ' .. spikeData.frequency .. ' MHz',
                        type = 'inform'
                    })
                end
            },
            {
                name = 'spike_reset_deployer',
                icon = 'fas fa-undo',
                label = 'Reset Deployer',
                canInteract = function()
                    return spikeData.owner == cache.serverId
                end,
                onSelect = function()
                    TriggerServerEvent('colbss-spikes:server:resetDeployer', spikeId)
                end
            }
        })
    end
end)

-- Event to reset a remote deployer
RegisterNetEvent('colbss-spikes:client:resetDeployer', function(spikeId)
    local spikeData = deployedSpikes[spikeId]
    if not spikeData or spikeData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= SPIKE_STATES.DEPLOYED then
        return
    end
    
    -- Remove deployed spikes
    if spikeData.spikes then
        for _, spike in pairs(spikeData.spikes) do
            if DoesEntityExist(spike.entity) then
                DeleteEntity(spike.entity)
            end
        end
    end
    
    -- Update the spike data
    deployedSpikes[spikeId].spikes = nil
    deployedSpikes[spikeId].state = SPIKE_STATES.PLACED
    
    -- Update target options (restore pickup option since spikes are reset)
    if DoesEntityExist(spikeData.deployer.entity) then
        exports.ox_target:removeLocalEntity(spikeData.deployer.entity)
        exports.ox_target:addLocalEntity(spikeData.deployer.entity, {
            {
                name = 'spike_get_frequency',
                icon = 'fas fa-broadcast-tower',
                label = 'Get Frequency',
                onSelect = function()
                    lib.notify({
                        title = 'Spike Strip Deployer',
                        description = 'Frequency: ' .. spikeData.frequency .. ' MHz',
                        type = 'inform'
                    })
                end
            },
            {
                name = 'spike_pickup',
                icon = 'fas fa-hand-paper',
                label = 'Pick Up Deployer',
                canInteract = function()
                    return spikeData.owner == cache.serverId and deployedSpikes[spikeId].state == SPIKE_STATES.PLACED
                end,
                onSelect = function()
                    TriggerServerEvent('colbss-spikes:server:pickupSpike', spikeId)
                end
            }
        })
    end
end)

-- Unified event to remove spikes
RegisterNetEvent('colbss-spikes:client:removeSpike', function(spikeId)
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then return end
    
    if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER then
        -- Remove deployer prop
        if DoesEntityExist(spikeData.deployer.entity) then
            exports.ox_target:removeLocalEntity(spikeData.deployer.entity)
            DeleteEntity(spikeData.deployer.entity)
        end
        -- Remove deployed spikes if any
        if spikeData.spikes then
            for _, spike in pairs(spikeData.spikes) do
                if DoesEntityExist(spike.entity) then
                    DeleteEntity(spike.entity)
                end
            end
        end
    elseif spikeData.type == SPIKE_TYPES.STANDALONE then
        -- Remove standalone spikes
        if spikeData.spikes then
            for _, spike in pairs(spikeData.spikes) do
                if DoesEntityExist(spike.entity) then
                    DeleteEntity(spike.entity)
                end
            end
        end
    end
    
    deployedSpikes[spikeId] = nil
end)

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
                TriggerServerEvent('colbss-spikes:server:createSpike', {
                    type = SPIKE_TYPES.REMOTE_DEPLOYER,
                    coords = deployCoords,
                    heading = playerHeading
                })
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
            -- Check if the remote has a frequency set
            if not data.metadata or not data.metadata?.frequency then
                return lib.notify({
                    description = 'Remote is not tuned to a frequency.',
                    type = 'error'
                })
            end
            
            local frequency = data.metadata.frequency
            
            -- Look for a remote deployer with matching frequency that hasn't been deployed yet
            local foundDeployer = false
            for spikeId, spikeData in pairs(deployedSpikes) do
                if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER and 
                   spikeData.frequency == frequency and 
                   spikeData.state == SPIKE_STATES.PLACED then
                    foundDeployer = true
                    
                    lib.notify({
                        description = 'Deploying spikes on frequency ' .. frequency .. ' MHz...',
                        type = 'info'
                    })
                    
                    -- Deploy the spikes
                    deployRemoteSpikes(spikeId)
                    break
                end
            end
            
            if not foundDeployer then
                lib.notify({
                    description = 'No available deployer found on frequency ' .. frequency .. ' MHz.',
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
            TriggerServerEvent('colbss-spikes:server:tuneRemoteFrequency', data.slot, frequency)
            
            lib.notify({
                description = 'Remote tuned to ' .. frequency .. ' MHz',
                type = 'success'
            })
        end
    end)
end)

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