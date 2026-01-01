local config = require 'config'
local shared = require 'shared'

local SpikeRoll = {}

SpikeRoll.DeployState = 0 -- 0 == not deploying, 1 == holding roll, 2 == placing spikes
SpikeRoll.SpikeLength = 1
SpikeRoll.RollProps = {}
SpikeRoll.SpikeZones = {}

function SpikeRoll.StopCarry()
    
    local isCarrying = LocalState.spikes_carry_roll
    if isCarrying then
        LocalState:set('spikes_carry_roll', false, true)
    end
    SpikeRoll.DeployState = 0
    
    local animConfig = config.roll.anim.carry

    StopAnimTask(cache.ped, animConfig.dict, animConfig.name, 4.0)
    ClearPedTasks(cache.ped)

    -- lib.hideTextUI()
    SendNUIMessage({
        action = 'hideUI',
    })

end

function SpikeRoll.DeploySpikes()
    if SpikeRoll.DeployState ~= 1 then return end

    SpikeRoll.DeployState = 2

    SendNUIMessage({
        action = 'hideUI',
    })
    
    local playerCoords = GetEntityCoords(cache.ped)
    local playerHeading = GetEntityHeading(cache.ped)
    
    local animConfig = config.roll.anim.use
    if lib.progressBar({
        duration = 2000,
        label = 'Deploying spike strips...',
        useWhileDead = false,
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

        -- Clean up roll prop immediately after successful deployment
        SpikeRoll.StopCarry()

        local positions = common.GetSpikePositions(SpikeRoll.SpikeLength, playerCoords, playerHeading)
        local tempProps = {}
        for i = 1, SpikeRoll.SpikeLength do
            local pos = positions[i]
            tempProps[i] = common.DeployTempSpikes(pos.x, pos.y, pos.z, pos.w)
        end
        
        TriggerServerEvent('ar_spikes:server:createSpike', {
            type = shared.SPIKE_TYPES.STANDALONE,
            positions = positions,
            length = SpikeRoll.SpikeLength
        })
        
        for i = 1, SpikeRoll.SpikeLength do
            if DoesEntityExist(tempProps[i]) then
                DeleteEntity(tempProps[i])
            end
        end
    else
        
        SpikeRoll.DeployState = 1

        local animConfig = config.roll.anim.carry
        lib.requestAnimDict(animConfig.dict)
        TaskPlayAnim(cache.ped, animConfig.dict, animConfig.name, 4.0, -4.0, -1, 49, 0, false, false, false)

        SendNUIMessage({
            action = 'showUI',
            data = {
                keys = {
                    increaseLabel = common.GetKeyLabel(keybinds.increase.hash),
                    decreaseLabel = common.GetKeyLabel(keybinds.decrease.hash),
                    confirmLabel = common.GetKeyLabel(keybinds.select.hash),
                    cancelLabel = common.GetKeyLabel(keybinds.cancel.hash)
                },
                initialLength = SpikeRoll.SpikeLength
            }
        })
    end
end

-- ██████ ██  ██ ███  ██ ▄█████ ██████ ██ ▄████▄ ███  ██ ▄█████ 
-- ██▄▄   ██  ██ ██ ▀▄██ ██       ██   ██ ██  ██ ██ ▀▄██ ▀▀▀▄▄▄ 
-- ██     ▀████▀ ██   ██ ▀█████   ██   ██ ▀████▀ ██   ██ █████▀ 

function ConfirmSpikePlacement()
    if SpikeRoll.DeployState ~= 1 then return end
    SpikeRoll.DeploySpikes()
end

function CancelSpikePlacement()
    if SpikeRoll.DeployState ~= 1 then return end
    SpikeRoll.StopCarry()
end

function ChangeSpikeCount(amount)
    if SpikeRoll.DeployState ~= 1 then return end

    SpikeRoll.SpikeLength = SpikeRoll.SpikeLength + amount
    if SpikeRoll.SpikeLength < 1 then
        SpikeRoll.SpikeLength = 1
    elseif SpikeRoll.SpikeLength > 4 then
        SpikeRoll.SpikeLength = 4
    end

    SendNUIMessage({
        action = 'setLength',
        data = {
            length = SpikeRoll.SpikeLength
        }
    })

end

-- ▄█████ ██████ ▄████▄ ██████ ██████   ██  ██ ▄████▄ ███  ██ ████▄  ██     ██████ █████▄  ▄█████ 
-- ▀▀▀▄▄▄   ██   ██▄▄██   ██   ██▄▄     ██████ ██▄▄██ ██ ▀▄██ ██  ██ ██     ██▄▄   ██▄▄██▄ ▀▀▀▄▄▄ 
-- █████▀   ██   ██  ██   ██   ██▄▄▄▄   ██  ██ ██  ██ ██   ██ ████▀  ██████ ██▄▄▄▄ ██   ██ █████▀ 

AddStateBagChangeHandler('spikes_carry_roll', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end
    
    local playerId = GetPlayerFromStateBagName(bagName)
    if playerId == -1 then return end
    
    local targetPed = GetPlayerPed(playerId)
    if not DoesEntityExist(targetPed) then return end
    
    if value then
        
        local rollModel = GetHashKey(config.roll.prop)
        lib.requestModel(rollModel, 2000)
        local prop = CreateObject(rollModel, 0, 0, 0, false, false, false)
        local animConfig = config.roll.anim.carry
        AttachEntityToEntity(prop, targetPed, GetPedBoneIndex(targetPed, animConfig.bone), 
            animConfig.offset.x, animConfig.offset.y, animConfig.offset.z,
            animConfig.rotation.x, animConfig.rotation.y, animConfig.rotation.z,
            true, true, false, true, 1, true)

        SetModelAsNoLongerNeeded(rollModel)
        
        SpikeRoll.RollProps[playerId] = prop
    else
        local prop = SpikeRoll.RollProps[playerId]
        if prop and DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
        SpikeRoll.RollProps[playerId] = nil
    end
end)

-- ██████ ██  ██ █████▄ ▄████▄ █████▄  ██████ ▄█████ 
-- ██▄▄    ████  ██▄▄█▀ ██  ██ ██▄▄██▄   ██   ▀▀▀▄▄▄ 
-- ██▄▄▄▄ ██  ██ ██     ▀████▀ ██   ██   ██   █████▀ 

exports('useRoll', function(data, slot)
    exports.ox_inventory:useItem(data, function(data)
        if data then

            local canDeploy = lib.callback.await('ar_spikes:server:checkMaxSpikes', false, shared.SPIKE_TYPES.STANDALONE)
            if not canDeploy then
                return lib.notify({
                    description = 'You have reached the maximum number of spike rolls you can deploy.',
                    type = 'error'
                })
            end

            if SpikeRoll.DeployState ~= 0 then
                return lib.notify({
                    description = 'You are already deploying a spike roll.',
                    type = 'error'
                })
            end
            
            if cache.vehicle then
                return lib.notify({
                    description = 'You cannot use this in a vehicle.',
                    type = 'error'
                })
            end
            
            local animConfig = config.roll.anim.carry
            lib.requestAnimDict(animConfig.dict)
            TaskPlayAnim(cache.ped, animConfig.dict, animConfig.name, 4.0, -4.0, -1, animConfig.flags, 0, false, false, false)
            
            SpikeRoll.DeployState = 1
            LocalState:set('spikes_carry_roll', true, true)

            SendNUIMessage({
                action = 'showUI',
                data = {
                    keys = {
                        increaseLabel = common.GetKeyLabel(keybinds.increase.hash),
                        decreaseLabel = common.GetKeyLabel(keybinds.decrease.hash),
                        confirmLabel = common.GetKeyLabel(keybinds.select.hash),
                        cancelLabel = common.GetKeyLabel(keybinds.cancel.hash)
                    },
                    initialLength = SpikeRoll.SpikeLength
                }
            })
            
            -- Handle input for spike placement
            CreateThread(function()
                while SpikeRoll.DeployState > 0 do
                    
                    if not IsEntityPlayingAnim(cache.ped, animConfig.dict, animConfig.name, 3) and SpikeRoll.DeployState ~= 2 then
                        TaskPlayAnim(cache.ped, animConfig.dict, animConfig.name, 4.0, -4.0, -1, animConfig.flags, 0, false, false, false)
                    end

                    if cache.vehicle then
                        SpikeRoll.StopCarry()
                        lib.notify({
                            description = 'Spike roll placement cancelled - entered vehicle.',
                            type = 'error'
                        })
                        break
                    end

                    Wait(500)
                end
                RemoveAnimDict(animConfig.dict)
            end)
        end
    end)
end)

-- ██████ ██  ██ ██████ ███  ██ ██████ ▄█████ 
-- ██▄▄   ██▄▄██ ██▄▄   ██ ▀▄██   ██   ▀▀▀▄▄▄ 
-- ██▄▄▄▄  ▀██▀  ██▄▄▄▄ ██   ██   ██   █████▀ 

RegisterNetEvent('ar_spikes:client:createStandaloneSpikes', function(spikeId, spikeData, ownerServerId)

    local spikes = common.CreateSpikeStrip(spikeData.positions, spikeId)
    common.AddSpikeToSystem(spikeId, shared.SPIKE_TYPES.STANDALONE, spikes)
    
    if #spikes > 0 then

        local firstSpike = spikes[1]
        local lastSpike = spikes[#spikes]
        local firstPos = GetEntityCoords(firstSpike.entity)
        local lastPos = GetEntityCoords(lastSpike.entity)
        local centerX = (firstPos.x + lastPos.x) / 2
        local centerY = (firstPos.y + lastPos.y) / 2
        local centerZ = (firstPos.z + lastPos.z) / 2
        local heightDiff = math.abs(firstPos.z - lastPos.z)
        local stripLength = #(firstPos - lastPos) + 3.5
        local spikeHeading = GetEntityHeading(firstSpike.entity)
        local zoneRotation = spikeHeading - 90.0
        if zoneRotation < 0 then
            zoneRotation = zoneRotation + 360.0
        end
        
        local zoneId = exports.ox_target:addBoxZone({
            coords = vector3(centerX, centerY, centerZ),
            size = vector3(stripLength + 1.0, 1.0, math.max(1.0, heightDiff*2)),
            rotation = zoneRotation,
            options = {
                {
                    name = 'pickup_standalone_spikes_' .. spikeId,
                    icon = 'fas fa-hand-paper',
                    label = 'Pick Up Spike Strips',
                    canInteract = function()
                        return common.HasJobAccess(config.roll.jobs)
                    end,
                    onSelect = function()

                        local spikeSystem = common.GetSpikeInSystem(spikeId)
                        if not spikeSystem or not spikeSystem.spikes then return end
                        local spikes = spikeSystem.spikes
                        
                        local firstSpike = spikes[1]
                        local lastSpike = spikes[#spikes]
                        local firstPos = GetEntityCoords(firstSpike.entity)
                        local lastPos = GetEntityCoords(lastSpike.entity)
                        local centerCoords = vector3(
                            (firstPos.x + lastPos.x) / 2,
                            (firstPos.y + lastPos.y) / 2,
                            (firstPos.z + lastPos.z) / 2
                        )
                        
                        common.FaceCoords(centerCoords, function()
                            
                            local animConfig = config.roll.anim.use
                            if lib.progressBar({
                                duration = 3000,
                                label = 'Picking up spike strips...',
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
                                TriggerServerEvent('ar_spikes:server:pickupStandaloneSpikes', spikeId)
                            end
                        end)
                    end
                }
            }
        })
        
        SpikeRoll.SpikeZones[spikeId] = {
            zoneId = zoneId,
            owner = ownerServerId
        }
    end
end)

RegisterNetEvent('ar_spikes:client:removeStandaloneSpikes', function(spikeId)

    local spikeSystem = common.GetSpikeInSystem(spikeId)
    if spikeSystem and spikeSystem.spikes then
        for _, spike in pairs(spikeSystem.spikes) do
            if DoesEntityExist(spike.entity) then
                DeleteEntity(spike.entity)
            end
        end
    end
    common.RemoveSpikeFromSystem(spikeId)
    
    local targetData = SpikeRoll.SpikeZones[spikeId]
    if targetData and targetData.zoneId then
        exports.ox_target:removeZone(targetData.zoneId)
    end
    
    SpikeRoll.SpikeZones[spikeId] = nil
end)

-- ██  ██ ▄████▄ ███  ██ ████▄  ██     ██████ █████▄  ▄█████ 
-- ██████ ██▄▄██ ██ ▀▄██ ██  ██ ██     ██▄▄   ██▄▄██▄ ▀▀▀▄▄▄ 
-- ██  ██ ██  ██ ██   ██ ████▀  ██████ ██▄▄▄▄ ██   ██ █████▀ 

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    if SpikeRoll.IsCarryingRoll then
        SpikeRoll.StopCarry()
    end
    
    -- Clean up all tracked roll props
    for playerId, prop in pairs(SpikeRoll.RollProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    SpikeRoll.RollProps = {}
    
    -- Clean up target zones only (spikes handled by unified system)
    for spikeId, targetData in pairs(SpikeRoll.SpikeZones) do
        if targetData.zoneId then
            exports.ox_target:removeZone(targetData.zoneId)
        end
    end
    SpikeRoll.SpikeZones = {}
end)