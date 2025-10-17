local config = require 'config'

-- Deployer specific variables (for targets and UI only)
local deployerTargets = {}
local playerRemoteProps = {}

-- Animation state management
local animationState = {
    isPlaying = false,
    currentType = nil
}

-- Handle statebag changes for prop attachments
AddStateBagChangeHandler('spikes_remote_prop', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end
    
    local playerId = GetPlayerFromStateBagName(bagName)
    if playerId == 0 then return end
    
    local playerPed = GetPlayerPed(playerId)
    if not DoesEntityExist(playerPed) then return end
    
    -- Remove existing prop
    if playerRemoteProps[playerId] then
        DeleteEntity(playerRemoteProps[playerId])
        playerRemoteProps[playerId] = nil
    end
    
    -- Attach new prop if specified
    if value and value.active then
        local propHash = GetHashKey(config.deployer.anim.prop)
        lib.requestModel(propHash, 5000)
        
        local prop = CreateObject(propHash, 0.0, 0.0, 0.0, true, true, false)
        SetModelAsNoLongerNeeded(propHash)
        
        local animConfig = config.deployer.anim[value.type]
        AttachEntityToEntity(
            prop, playerPed, GetPedBoneIndex(playerPed, animConfig.bone),
            animConfig.offset.x, animConfig.offset.y, animConfig.offset.z,
            animConfig.rotation.x, animConfig.rotation.y, animConfig.rotation.z,
            true, true, false, true, 1, true
        )
        
        playerRemoteProps[playerId] = prop
    end
end)

-- Start tune animation (loops indefinitely)
local function StartTuneAnimation()
    if animationState.isPlaying then return end
    
    local playerPed = cache.ped
    local animConfig = config.deployer.anim.tune
    
    -- Set statebag for prop attachment
    LocalPlayer.state:set('spikes_remote_prop', {
        active = true,
        type = 'tune'
    }, true)
    
    -- Play animation
    lib.requestAnimDict(animConfig.dict, 5000)
    TaskPlayAnim(playerPed, animConfig.dict, animConfig.name, 4.0, -4.0, -1, animConfig.flags, 0, false, false, false)
    
    animationState.isPlaying = true
    animationState.currentType = 'tune'
end

-- Stop tune animation
local function StopTuneAnimation()
    if not animationState.isPlaying or animationState.currentType ~= 'tune' then return end
    
    local playerPed = cache.ped
    
    -- Clear statebag
    LocalPlayer.state:set('spikes_remote_prop', { active = false }, true)
    
    -- Stop animation
    ClearPedTasks(playerPed)
    
    animationState.isPlaying = false
    animationState.currentType = nil
end

-- Play deploy animation (one-time with delay)
local function PlayDeployAnimation(callback)
    if animationState.isPlaying then return end
    
    local playerPed = cache.ped
    local animConfig = config.deployer.anim.deploy
    
    -- Set statebag for prop attachment
    LocalPlayer.state:set('spikes_remote_prop', {
        active = true,
        type = 'deploy'
    }, true)
    
    -- Play animation
    lib.requestAnimDict(animConfig.dict, 5000)
    TaskPlayAnim(playerPed, animConfig.dict, animConfig.name, 4.0, -4.0, 1500, animConfig.flags, 0, false, false, false)
    
    animationState.isPlaying = true
    animationState.currentType = 'deploy'
    
    -- Wait briefly then start spike strip animation
    SetTimeout(500, function()
        -- Delete remote prop after spike deployment starts
        SetTimeout(500, function()
            LocalPlayer.state:set('spikes_remote_prop', { active = false }, true)
            animationState.isPlaying = false
            animationState.currentType = nil
        end)
        if callback then callback() end
    end)
end

local function cleanupAllSpikes()
    -- Clean up all deployer targets and entities
    for spikeId, targetData in pairs(deployerTargets) do
        if targetData.deployer and DoesEntityExist(targetData.deployer.entity) then
            exports.ox_target:removeLocalEntity(targetData.deployer.entity)
            DeleteEntity(targetData.deployer.entity)
        end
    end
    deployerTargets = {}
end

local function resetRemoteDeployer(spikeId)
    local targetData = deployerTargets[spikeId]
    if not targetData or not targetData.deployer then return end
    
    local deployerCoords = GetEntityCoords(targetData.deployer.entity)
    
    -- Face the deployer first
    FaceCoords(deployerCoords, function()
        -- Play reset animation (same as deployer placement)
        lib.requestAnimDict('mp_weapons_deal_sting')
        TaskPlayAnim(cache.ped, 'mp_weapons_deal_sting', 'crackhead_bag_loop', 4.0, -4.0, -1, 1, 0, false, false, false)
        
        -- Show progress bar
        if lib.progressBar({
            duration = 3000,
            label = 'Resetting Spike Deployer...',
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
            TriggerServerEvent('colbss-spikes:server:resetDeployer', spikeId)
        else
            -- Progress was cancelled
            ClearPedTasks(cache.ped)
        end
    end)
end

-- Event to create remote deployer
RegisterNetEvent('colbss-spikes:client:createDeployer', function(spikeId, spikeData, ownerServerId)
    -- Create remote deployer prop
    local deployerModel = GetHashKey(config.deployer.prop)
    lib.requestModel(deployerModel)
    
    local deployer = CreateObject(deployerModel, spikeData.coords.x, spikeData.coords.y, spikeData.coords.z, false, false, false)
    SetEntityHeading(deployer, spikeData.heading)
    PlaceObjectOnGroundProperly(deployer)
    FreezeEntityPosition(deployer, true)
    
    -- Store in local table for target management
    deployerTargets[spikeId] = {
        type = SPIKE_TYPES.REMOTE_DEPLOYER,
        state = SPIKE_STATES.PLACED,
        owner = ownerServerId,
        frequency = spikeData.frequency,
        deployer = {
            entity = deployer,
            coords = spikeData.coords,
            heading = spikeData.heading
        }
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
                return hasJobAccess(config.deployer.jobs) and deployerTargets[spikeId].state == SPIKE_STATES.PLACED
            end,
            onSelect = function()
                local deployerCoords = GetEntityCoords(spikeData.deployer.entity)
                FaceCoords(deployerCoords, function()
                    TriggerServerEvent('colbss-spikes:server:pickupSpike', spikeId)
                end)
            end
        },
        {
            name = 'spike_reset_deployer',
            icon = 'fas fa-undo',
            label = 'Reset Deployer',
            canInteract = function()
                return hasJobAccess(config.deployer.jobs)
            end,
            onSelect = function()
                resetRemoteDeployer(spikeId)
            end
        }
    })
end)

-- Event to deploy spikes from a remote deployer
RegisterNetEvent('colbss-spikes:client:deployRemoteSpikes', function(spikeId, positions)
    local targetData = deployerTargets[spikeId]
    if not targetData or targetData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or targetData.state ~= SPIKE_STATES.PLACED then
        return
    end
    
    -- Create the spike strips
    local spikes = createSpikeStrip(positions, spikeId)
    
    -- Add to unified spike tracking system
    AddSpikeSystem(spikeId, SPIKE_TYPES.REMOTE_DEPLOYER, spikes)
    
    -- Update the local target data
    targetData.state = SPIKE_STATES.DEPLOYED
    
    -- Update target options (replace pickup with reset since spikes are deployed)
    if DoesEntityExist(targetData.deployer.entity) then
        exports.ox_target:removeLocalEntity(targetData.deployer.entity)
        exports.ox_target:addLocalEntity(targetData.deployer.entity, {
            {
                name = 'spike_get_frequency',
                icon = 'fas fa-broadcast-tower',
                label = 'Get Frequency',
                onSelect = function()
                    lib.notify({
                        title = 'Spike Strip Deployer',
                        description = 'Frequency: ' .. targetData.frequency .. ' MHz',
                        type = 'inform'
                    })
                end
            },
            {
                name = 'spike_reset_deployer',
                icon = 'fas fa-undo',
                label = 'Reset Deployer',
                canInteract = function()
                    return hasJobAccess(config.deployer.jobs)
                end,
                onSelect = function()
                    resetRemoteDeployer(spikeId)
                end
            }
        })
    end
end)

-- Event to reset a remote deployer
RegisterNetEvent('colbss-spikes:client:resetDeployer', function(spikeId)
    local targetData = deployerTargets[spikeId]
    if not targetData or targetData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or targetData.state ~= SPIKE_STATES.DEPLOYED then
        return
    end
    
    -- Remove from unified spike tracking and clean up spike entities
    local spikeSystem = GetSpikeSystem(spikeId)
    if spikeSystem and spikeSystem.spikes then
        for _, spike in pairs(spikeSystem.spikes) do
            if DoesEntityExist(spike.entity) then
                DeleteEntity(spike.entity)
            end
        end
    end
    RemoveSpikeSystem(spikeId)
    
    -- Update the local target data
    targetData.state = SPIKE_STATES.PLACED
    
    -- Update target options (restore pickup option since spikes are reset)
    if DoesEntityExist(targetData.deployer.entity) then
        exports.ox_target:removeLocalEntity(targetData.deployer.entity)
        exports.ox_target:addLocalEntity(targetData.deployer.entity, {
            {
                name = 'spike_get_frequency',
                icon = 'fas fa-broadcast-tower',
                label = 'Get Frequency',
                onSelect = function()
                    lib.notify({
                        title = 'Spike Strip Deployer',
                        description = 'Frequency: ' .. targetData.frequency .. ' MHz',
                        type = 'inform'
                    })
                end
            },
            {
                name = 'spike_pickup',
                icon = 'fas fa-hand-paper',
                label = 'Pick Up Deployer',
                canInteract = function()
                    return hasJobAccess(config.deployer.jobs) and deployerTargets[spikeId].state == SPIKE_STATES.PLACED
                end,
                onSelect = function()
                    TriggerServerEvent('colbss-spikes:server:pickupSpike', spikeId)
                end
            }
        })
    end
end)

-- Event to remove deployer
RegisterNetEvent('colbss-spikes:client:removeDeployer', function(spikeId)
    local targetData = deployerTargets[spikeId]
    if not targetData then return end
    
    -- Remove from unified spike tracking
    RemoveSpikeSystem(spikeId)
    
    if targetData.type == SPIKE_TYPES.REMOTE_DEPLOYER then
        -- Remove deployer prop
        if DoesEntityExist(targetData.deployer.entity) then
            exports.ox_target:removeLocalEntity(targetData.deployer.entity)
            DeleteEntity(targetData.deployer.entity)
        end
    end
    
    deployerTargets[spikeId] = nil
end)

-- Export for using deployer
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
            TaskPlayAnim(cache.ped, 'mp_weapons_deal_sting', 'crackhead_bag_loop', 4.0, -4.0, -1, 1, 0, false, false, false)
            
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

-- Export for using remote
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
            
            -- Always play animation regardless of outcome
            PlayDeployAnimation(function()
                -- Request validation from server
                local result = lib.callback.await('colbss-spikes:server:validateRemoteDeployment', false, frequency)
                
                if result.success then
                    -- Valid deployment - proceed with spike deployment
                    lib.notify({
                        description = 'Deploying spikes on frequency ' .. frequency .. ' MHz...',
                        type = 'info'
                    })
                    
                    local deployerData = result.deployerData
                    local spikeId = result.spikeId
                    
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
                    
                    -- Clean up temporary props
                    for i = 1, 2 do
                        if DoesEntityExist(tempProps[i]) then
                            DeleteEntity(tempProps[i])
                        end
                    end
                    
                    -- Update server with new spike positions
                    TriggerServerEvent('colbss-spikes:server:updateSpikeState', spikeId, positions)
                else
                    -- Invalid deployment - show error message
                    lib.notify({
                        description = result.message,
                        type = 'inform'
                    })
                end
            end)
        end
    end)
end)

-- Export for tuning frequency
exports('tuneFrequency', function(data)
    exports.ox_inventory:useItem(data, function(data)
        if data then
            -- Start tune animation
            StartTuneAnimation()
            
            -- Show input dialog to tune the frequency
            local input = lib.inputDialog('Tune Remote Frequency', {
                {type = 'number', label = 'Frequency (MHz)', description = 'Enter frequency between 100-999', default = 100, min = 100, max = 999}
            })
            
            -- Stop tune animation when dialog closes
            StopTuneAnimation()
            
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

-- Display metadata
exports.ox_inventory:displayMetadata({
    frequency = 'Frequency',
})

-- Cleanup on resource events
AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    cleanupAllSpikes()
    
    -- Clean up all props
    for playerId, prop in pairs(playerRemoteProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    
    -- Clear own statebag
    LocalPlayer.state:set('spikes_remote_prop', { active = false }, true)
end)

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    cleanupAllSpikes()
    
    -- Clear own statebag
    LocalPlayer.state:set('spikes_remote_prop', { active = false }, true)
end)