local config = require 'config'
local shared = require 'shared'

local SpikeDeployer = {}

SpikeDeployer.Spikes = {}
SpikeDeployer.RemoteProps = {}
SpikeDeployer.AnimState = {
    active = false,
    type = nil
}

function SpikeDeployer.StartTuneAnimation()
    if SpikeDeployer.AnimState.active then return end

    LocalState:set('spikes_remote_prop', {
        active = true,
        type = 'tune'
    }, true)

    local animConfig = config.deployer.anim.tune
    lib.requestAnimDict(animConfig.dict, 1000)
    TaskPlayAnim(cache.ped, animConfig.dict, animConfig.name, 4.0, -4.0, -1, animConfig.flags, 0, false, false, false)

    SpikeDeployer.AnimState.active = true
    SpikeDeployer.AnimState.type = 'tune'
end

function SpikeDeployer.StopTuneAnimation()
    if not SpikeDeployer.AnimState.active or SpikeDeployer.AnimState.type ~= 'tune' then return end

    LocalState:set('spikes_remote_prop', { active = false }, true)

    local animConfig = config.deployer.anim.tune
    if IsEntityPlayingAnim(cache.ped, animConfig.dict, animConfig.name, 3) then
        StopAnimTask(cache.ped, animConfig.dict, animConfig.name, 4.0)
    end

    SpikeDeployer.AnimState.active = false
    SpikeDeployer.AnimState.type = nil
end

---@param success boolean Whether the sound type is success or fail
function SpikeDeployer.PlayDeployRemoteSound(success)
    local soundHandle = GetSoundId()
    if success then
        PlaySoundFrontend(soundHandle, "RADAR_ACTIVATE", "DLC_BTL_SECURITY_VANS_RADAR_PING_SOUNDS", true)
    else
        PlaySoundFrontend(soundHandle, "RADAR_READY", "DLC_BTL_SECURITY_VANS_RADAR_PING_SOUNDS", true)
    end
    ReleaseSoundId(soundHandle)
end

---@param callback cb Function to call when remote is pressed during animation
function SpikeDeployer.PlayDeployAnimation(callback)
    if SpikeDeployer.AnimState.active then return end
    
    -- Set statebag for prop attachment
    LocalState:set('spikes_remote_prop', {
        active = true,
        type = 'deploy'
    }, true)
    
    local animConfig = config.deployer.anim.deploy
    lib.requestAnimDict(animConfig.dict, 2000)
    TaskPlayAnim(cache.ped, animConfig.dict, animConfig.name, 4.0, -4.0, 1500, animConfig.flags, 0, false, false, false)
    
    SpikeDeployer.AnimState.active = true
    SpikeDeployer.AnimState.type = 'deploy'
    
    -- Wait briefly then start spike strip animation
    SetTimeout(500, function()
        -- Delete remote prop after spike deployment starts
        SetTimeout(500, function()
            LocalState:set('spikes_remote_prop', { active = false }, true)
            SpikeDeployer.AnimState.active = false
            SpikeDeployer.AnimState.type = nil
        end)
        if callback then callback() end
    end)
end

function SpikeDeployer.RemoveSpikeTargets()
    for spikeId, spikeData in pairs(SpikeDeployer.Spikes) do
        if spikeData.deployer and DoesEntityExist(spikeData.deployer.entity) then
            exports.ox_target:removeLocalEntity(spikeData.deployer.entity)
            DeleteEntity(spikeData.deployer.entity)
        end
    end
    SpikeDeployer.Spikes = {}
end

---@param spikeId number The ID of the spike deployer
function SpikeDeployer.ResetRemoteDeployer(spikeId)
    local spikeData = SpikeDeployer.Spikes[spikeId]
    if not spikeData or not spikeData.deployer then return end
    
    local deployerCoords = GetEntityCoords(spikeData.deployer.entity)
    
    common.FaceCoords(deployerCoords, function()
        local animConfig = config.deployer.anim.use
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
            },
            anim = {
                dict = animConfig.dict,
                clip = animConfig.name,
                flags = animConfig.flags,
                blendIn = 4.0,
                blendOut = -4.0,
            }
        }) then
            TriggerServerEvent('ar_spikes:server:resetDeployer', spikeId)
        end
    end)
end

-- ▄█████ ██████ ▄████▄ ██████ ██████   ██  ██ ▄████▄ ███  ██ ████▄  ██     ██████ █████▄  ▄█████ 
-- ▀▀▀▄▄▄   ██   ██▄▄██   ██   ██▄▄     ██████ ██▄▄██ ██ ▀▄██ ██  ██ ██     ██▄▄   ██▄▄██▄ ▀▀▀▄▄▄ 
-- █████▀   ██   ██  ██   ██   ██▄▄▄▄   ██  ██ ██  ██ ██   ██ ████▀  ██████ ██▄▄▄▄ ██   ██ █████▀ 

AddStateBagChangeHandler('spikes_remote_prop', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end

    local playerId = GetPlayerFromStateBagName(bagName)
    if playerId == 0 then return end
    
    local playerPed = GetPlayerPed(playerId)
    if not DoesEntityExist(playerPed) then return end
    
    -- Remove existing prop
    if SpikeDeployer.RemoteProps[playerId] then
        DeleteEntity(SpikeDeployer.RemoteProps[playerId])
        SpikeDeployer.RemoteProps[playerId] = nil
    end
    
    -- Attach new prop if specified
    if value and value.active then
        local propHash = GetHashKey(config.deployer.anim.prop)
        lib.requestModel(propHash, 2000)
        
        local prop = CreateObject(propHash, 0.0, 0.0, 0.0, false, false, false)
        SetModelAsNoLongerNeeded(propHash)
        
        local animConfig = config.deployer.anim[value.type]
        AttachEntityToEntity(
            prop, playerPed, GetPedBoneIndex(playerPed, animConfig.bone),
            animConfig.offset.x, animConfig.offset.y, animConfig.offset.z,
            animConfig.rotation.x, animConfig.rotation.y, animConfig.rotation.z,
            true, true, false, true, 1, true
        )
        
        SpikeDeployer.RemoteProps[playerId] = prop
    end
end)

-- ██████ ██  ██ ██████ ███  ██ ██████ ▄█████ 
-- ██▄▄   ██▄▄██ ██▄▄   ██ ▀▄██   ██   ▀▀▀▄▄▄ 
-- ██▄▄▄▄  ▀██▀  ██▄▄▄▄ ██   ██   ██   █████▀ 

RegisterNetEvent('ar_spikes:client:createDeployer', function(spikeId, spikeData, ownerServerId)
    -- Create remote deployer prop
    local deployerModel = GetHashKey(config.deployer.prop)
    lib.requestModel(deployerModel, 2000)
    
    local deployer = CreateObject(deployerModel, spikeData.coords.x, spikeData.coords.y, spikeData.coords.z, false, false, false)
    SetEntityHeading(deployer, spikeData.heading)
    PlaceObjectOnGroundProperly(deployer)
    FreezeEntityPosition(deployer, true)
    
    SpikeDeployer.Spikes[spikeId] = {
        type = shared.SPIKE_TYPES.REMOTE_DEPLOYER,
        state = shared.SPIKE_STATES.PLACED,
        owner = ownerServerId,
        frequency = spikeData.frequency,
        deployer = {
            entity = deployer,
            coords = spikeData.coords,
            heading = spikeData.heading
        }
    }
    
    exports.ox_target:addLocalEntity(deployer, {
        {
            name = 'spike_get_frequency',
            icon = 'fas fa-broadcast-tower',
            label = 'Get Frequency',
            onSelect = function()
                lib.notify({
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
                return common.HasJobAccess(config.deployer.jobs) and SpikeDeployer.Spikes[spikeId].state == shared.SPIKE_STATES.PLACED
            end,
            onSelect = function()
                local deployerCoords = GetEntityCoords(deployer)
                common.FaceCoords(deployerCoords, function()
                    TriggerServerEvent('ar_spikes:server:pickupSpike', spikeId)
                end)
            end
        }
    })
end)

RegisterNetEvent('ar_spikes:client:deployRemoteSpikes', function(spikeId, positions)
    local spikeData = SpikeDeployer.Spikes[spikeId]
    if not spikeData or spikeData.type ~= shared.SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= shared.SPIKE_STATES.PLACED then
        return
    end
    
    local spikes = common.CreateSpikeStrip(positions, spikeId)
    common.AddSpikeToSystem(spikeId, shared.SPIKE_TYPES.REMOTE_DEPLOYER, spikes)
    spikeData.state = shared.SPIKE_STATES.DEPLOYED
    
    if DoesEntityExist(spikeData.deployer.entity) then
        exports.ox_target:addLocalEntity(spikeData.deployer.entity, {
            {
                name = 'spike_get_frequency',
                icon = 'fas fa-broadcast-tower',
                label = 'Get Frequency',
                onSelect = function()
                    lib.notify({
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
                    return common.HasJobAccess(config.deployer.jobs)
                end,
                onSelect = function()
                    SpikeDeployer.ResetRemoteDeployer(spikeId)
                end
            }
        })
    end
end)

RegisterNetEvent('ar_spikes:client:resetDeployer', function(spikeId)
    local spikeData = SpikeDeployer.Spikes[spikeId]
    if not spikeData or spikeData.type ~= shared.SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= shared.SPIKE_STATES.DEPLOYED then
        return
    end
    
    -- Remove from unified spike tracking and clean up spike entities
    local spikeSystem = common.GetSpikeInSystem(spikeId)
    if spikeSystem and spikeSystem.spikes then
        for _, spike in pairs(spikeSystem.spikes) do
            if DoesEntityExist(spike.entity) then
                DeleteEntity(spike.entity)
            end
        end
    end
    common.RemoveSpikeFromSystem(spikeId)
    
    -- Update the local target data
    spikeData.state = shared.SPIKE_STATES.PLACED
    
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
                    return common.HasJobAccess(config.deployer.jobs) and SpikeDeployer.Spikes[spikeId].state == shared.SPIKE_STATES.PLACED
                end,
                onSelect = function()
                    TriggerServerEvent('ar_spikes:server:pickupSpike', spikeId)
                end
            }
        })
    end
end)

RegisterNetEvent('ar_spikes:client:removeDeployer', function(spikeId)
    local spikeData = SpikeDeployer.Spikes[spikeId]
    if not spikeData then return end
    
    common.RemoveSpikeFromSystem(spikeId)
    
    if spikeData.type == shared.SPIKE_TYPES.REMOTE_DEPLOYER then
        if DoesEntityExist(spikeData.deployer.entity) then
            exports.ox_target:removeLocalEntity(spikeData.deployer.entity)
            DeleteEntity(spikeData.deployer.entity)
        end
    end
    
    SpikeDeployer.Spikes[spikeId] = nil
end)

-- ██████ ██  ██ █████▄ ▄████▄ █████▄  ██████ ▄█████ 
-- ██▄▄    ████  ██▄▄█▀ ██  ██ ██▄▄██▄   ██   ▀▀▀▄▄▄ 
-- ██▄▄▄▄ ██  ██ ██     ▀████▀ ██   ██   ██   █████▀ 

exports('useDeployer', function(data)
    exports.ox_inventory:useItem(data, function(data)
        if data then

            local canDeploy = lib.callback.await('ar_spikes:server:checkMaxSpikes', false, shared.SPIKE_TYPES.REMOTE_DEPLOYER)
            if not canDeploy then
                return lib.notify({
                    description = 'You have reached the maximum number of active spike deployers.',
                    type = 'error'
                })
            end

            if cache.vehicle then
                return lib.notify({
                    description = 'You cannot deploy in a vehicle.',
                    type = 'error'
                })
            end

            if not common.HasJobAccess(config.deployer.jobs) then
                return lib.notify({
                    description = 'You do not have permission to use the Spike Deployer.',
                    type = 'error'
                })
            end
    
            local playerCoords = GetEntityCoords(cache.ped)
            local playerHeading = GetEntityHeading(cache.ped) - 90.0
            local forwardVector = GetEntityForwardVector(cache.ped)
            local deployCoords = vector3(
                playerCoords.x + forwardVector.x * 1.0,
                playerCoords.y + forwardVector.y * 1.0,
                playerCoords.z
            )

            local animConfig = config.deployer.anim.use
            if lib.progressBar({
                duration = 3000,
                label = 'Using Spike Deployer...',
                useWhileDead = false,
                allowCuffed = false,
                allowSwimming = false,
                canCancel = true,
                disable = {
                    car = true,
                    move = true,
                    combat = true
                },
                anim = {
                    dict = animConfig.dict,
                    clip = animConfig.name,
                    flags = animConfig.flags,
                    blendIn = 4.0,
                    blendOut = -4.0,
                }
            }) then
                TriggerServerEvent('ar_spikes:server:createSpike', {
                    type = shared.SPIKE_TYPES.REMOTE_DEPLOYER,
                    coords = deployCoords,
                    heading = playerHeading
                })
            end

        end
    end)
end)

exports('useRemote', function(data)
    exports.ox_inventory:useItem(data, function(data)
        if data then

            local frequency = data.metadata?.frequency
            if not frequency then
                return lib.notify({
                    description = 'Remote is not tuned to a frequency.',
                    type = 'error'
                })
            end
            
            SpikeDeployer.PlayDeployAnimation(function()

                local result = lib.callback.await('ar_spikes:server:validateRemoteDeployment', false, shared.SPIKE_TYPES.REMOTE_DEPLOYER)
                
                if result.success then

                    SpikeDeployer.PlayDeployRemoteSound(true)
                    
                    local deployerData = result.deployerData
                    local spikeId = result.spikeId
                    
                    local spikeHeading = deployerData.heading + 90.0
                    if spikeHeading >= 360.0 then
                        spikeHeading = spikeHeading - 360.0
                    end
                    local positions = common.GetSpikePositions(2, deployerData.coords, spikeHeading)
                    local tempProps = {}
                    
                    for i = 1, 2 do
                        local pos = positions[i]
                        tempProps[i] = common.DeployTempSpikes(pos.x, pos.y, pos.z, pos.w)
                    end
                    for i = 1, 2 do
                        if DoesEntityExist(tempProps[i]) then
                            DeleteEntity(tempProps[i])
                        end
                    end
                    
                    TriggerServerEvent('ar_spikes:server:updateSpikeState', spikeId, positions)
                else
                    SpikeDeployer.PlayDeployRemoteSound(false)
                end
            end)
        end
    end)
end)

exports('tuneFrequency', function(data)
    exports.ox_inventory:useItem(data, function(data)
        if data then
            
            SpikeDeployer.StartTuneAnimation()

            local input = lib.inputDialog('Tune Remote Frequency', {
                {type = 'number', label = 'Frequency (MHz)', description = 'Enter frequency between 100-999', default = 100, min = 100, max = 999}
            })
            
            SpikeDeployer.StopTuneAnimation()
            
            if not input?[1] then return end
            local frequency = math.floor(input[1])
            TriggerServerEvent('ar_spikes:server:tuneRemoteFrequency', data.slot, frequency)
            
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

-- ██  ██ ▄████▄ ███  ██ ████▄  ██     ██████ █████▄  ▄█████ 
-- ██████ ██▄▄██ ██ ▀▄██ ██  ██ ██     ██▄▄   ██▄▄██▄ ▀▀▀▄▄▄ 
-- ██  ██ ██  ██ ██   ██ ████▀  ██████ ██▄▄▄▄ ██   ██ █████▀ 

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    SpikeDeployer.RemoveSpikeTargets()
    
    for playerId, prop in pairs(SpikeDeployer.RemoteProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    
    LocalState:set('spikes_remote_prop', { active = false }, true)
end)