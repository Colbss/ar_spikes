local config = require 'config'

-- Roll specific variables
local isCarryingRoll = false
local rollProp = nil
local rollStateBag = nil
local isPlacingSpikes = false
local spikeLength = 1

-- Local tracking of other players' roll props
local playerRollProps = {}

-- Local tracking of standalone spikes for targets
local standaloneSpikes = {}

local function cleanupRoll()
    if rollProp and DoesEntityExist(rollProp) then
        DeleteEntity(rollProp)
        rollProp = nil
    end
    if rollStateBag then
        rollStateBag:set('spikes_carry_roll', false, true)
        rollStateBag = nil
    end
    isCarryingRoll = false
    isPlacingSpikes = false
    ClearPedTasks(cache.ped)
    lib.hideTextUI()
end

local function deployStandaloneSpikeStrip()
    if not isCarryingRoll or not isPlacingSpikes then return end
    
    local playerCoords = GetEntityCoords(cache.ped)
    local playerHeading = GetEntityHeading(cache.ped)
    
    -- Stop the carry animation first
    ClearPedTasks(cache.ped)
    
    -- Start deploy animation
    lib.requestAnimDict('mp_weapons_deal_sting')
    TaskPlayAnim(cache.ped, 'mp_weapons_deal_sting', 'crackhead_bag_loop', 4.0, -4.0, -1, 1, 1.0, false, false, false)
    
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

        -- Clean up roll prop immediately after successful deployment
        cleanupRoll()

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
        for i = 1, spikeLength do
            if DoesEntityExist(tempProps[i]) then
                DeleteEntity(tempProps[i])
            end
        end
        
        lib.notify({
            description = 'Spike strips deployed successfully',
            type = 'success'
        })
    else
        -- Progress cancelled - restart carry animation
        lib.requestAnimDict(config.roll.anim.dict)
        TaskPlayAnim(cache.ped, config.roll.anim.dict, config.roll.anim.name, 4.0, -4.0, -1, 49, 0, false, false, false)
    end
end

-- Statebag handler for roll carrying
AddStateBagChangeHandler('spikes_carry_roll', nil, function(bagName, key, value, reserved, replicated)
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
            playerRollProps[playerId] = prop
        end
    else
        -- Player stopped carrying roll
        if playerId == PlayerId() then
            if rollProp and DoesEntityExist(rollProp) then
                DeleteEntity(rollProp)
                rollProp = nil
            end
        else
            local prop = playerRollProps[playerId]
            if prop and DoesEntityExist(prop) then
                DeleteEntity(prop)
            end
            playerRollProps[playerId] = nil
        end
    end
end)

-- Export for using roll
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
            TaskPlayAnim(cache.ped, config.roll.anim.dict, config.roll.anim.name, 4.0, -4.0, -1, 49, 0, false, false, false)
            
            -- Set state
            isCarryingRoll = true
            isPlacingSpikes = true
            rollStateBag = LocalPlayer.state
            rollStateBag:set('spikes_carry_roll', true, true)
            
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

-- Event to create standalone spike strips
RegisterNetEvent('colbss-spikes:client:createStandaloneSpikes', function(spikeId, spikeData, ownerServerId)
    -- Create the spike strips using the shared function
    local spikes = createSpikeStrip(spikeData.positions, spikeId)
    
    -- Store for cleanup and target management
    standaloneSpikes[spikeId] = {
        spikes = spikes,
        owner = ownerServerId
    }
    
    -- Create target zones for pickup - one zone covering the entire spike strip
    if #spikes > 0 then
        -- Use actual spike entity positions after PlaceObjectOnGroundProperly
        local firstSpike = spikes[1]
        local lastSpike = spikes[#spikes]
        
        local firstPos = GetEntityCoords(firstSpike.entity)
        local lastPos = GetEntityCoords(lastSpike.entity)
        
        -- Calculate center point between first and last spike
        local centerX = (firstPos.x + lastPos.x) / 2
        local centerY = (firstPos.y + lastPos.y) / 2
        local centerZ = (firstPos.z + lastPos.z) / 2

        local heightDiff = math.abs(firstPos.z - lastPos.z)
        
        -- Calculate length of the spike strip (distance between first and last + spike width)
        local stripLength = #(firstPos - lastPos) + 3.5
        
        -- Get the correct rotation - use the spike heading minus 90 degrees
        local spikeHeading = GetEntityHeading(firstSpike.entity)
        local zoneRotation = spikeHeading - 90.0
        if zoneRotation < 0 then
            zoneRotation = zoneRotation + 360.0
        end
        
        -- Create target zone and store the returned ID
        local zoneId = exports.ox_target:addBoxZone({
            coords = vector3(centerX, centerY, centerZ),
            size = vector3(stripLength + 1.0, 1.0, math.max(1.0, heightDiff*2)), -- Extra width for easier targeting
            rotation = zoneRotation, -- Corrected rotation
            options = {
                {
                    name = 'pickup_standalone_spikes_' .. spikeId,
                    icon = 'fas fa-hand-paper',
                    label = 'Pick Up Spike Strips',
                    canInteract = function()
                        return hasJobAccess(config.roll.jobs)
                    end,
                    onSelect = function()
                        -- Calculate center of spike strip for facing
                        local firstSpike = spikes[1]
                        local lastSpike = spikes[#spikes]
                        local firstPos = GetEntityCoords(firstSpike.entity)
                        local lastPos = GetEntityCoords(lastSpike.entity)
                        local centerCoords = vector3(
                            (firstPos.x + lastPos.x) / 2,
                            (firstPos.y + lastPos.y) / 2,
                            (firstPos.z + lastPos.z) / 2
                        )
                        
                        -- Face the spike strip first
                        FaceCoords(centerCoords, function()
                            -- Start pickup animation
                            lib.requestAnimDict('mp_weapons_deal_sting')
                            TaskPlayAnim(cache.ped, 'mp_weapons_deal_sting', 'crackhead_bag_loop', 4.0, -4.0, -1, 1, 0, false, false, false)
                            
                            -- Show progress bar
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
                                }
                            }) then
                                -- Progress completed successfully
                                ClearPedTasks(cache.ped)
                                TriggerServerEvent('colbss-spikes:server:pickupStandaloneSpikes', spikeId)
                            else
                                -- Progress was cancelled
                                ClearPedTasks(cache.ped)
                            end
                        end)
                    end
                }
            }
        })
        
        -- Store the zone ID for cleanup
        standaloneSpikes[spikeId].zoneId = zoneId
    end
end)

-- Event to remove standalone spike strips
RegisterNetEvent('colbss-spikes:client:removeStandaloneSpikes', function(spikeId)
    local spikeData = standaloneSpikes[spikeId]
    if not spikeData then return end
    
    -- Remove spike entities
    if spikeData.spikes then
        for _, spike in pairs(spikeData.spikes) do
            if DoesEntityExist(spike.entity) then
                DeleteEntity(spike.entity)
            end
        end
    end
    
    -- Remove target zone using the stored ID
    if spikeData.zoneId then
        exports.ox_target:removeZone(spikeData.zoneId)
    end
    
    standaloneSpikes[spikeId] = nil
end)

-- Cleanup on resource events
AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    if isCarryingRoll then
        cleanupRoll()
    end
    
    -- Clean up all tracked roll props
    for playerId, prop in pairs(playerRollProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    playerRollProps = {}
    
    -- Clean up standalone spikes and target zones
    for spikeId, spikeData in pairs(standaloneSpikes) do
        if spikeData.spikes then
            for _, spike in pairs(spikeData.spikes) do
                if DoesEntityExist(spike.entity) then
                    DeleteEntity(spike.entity)
                end
            end
        end
        if spikeData.zoneId then
            exports.ox_target:removeZone(spikeData.zoneId)
        end
    end
    standaloneSpikes = {}
end)

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() ~= resource then return end
    if isCarryingRoll then
        cleanupRoll()
    end
    
    -- Clean up all tracked roll props
    for playerId, prop in pairs(playerRollProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    playerRollProps = {}
    
    -- Clean up standalone spikes and target zones
    for spikeId, spikeData in pairs(standaloneSpikes) do
        if spikeData.spikes then
            for _, spike in pairs(spikeData.spikes) do
                if DoesEntityExist(spike.entity) then
                    DeleteEntity(spike.entity)
                end
            end
        end
        if spikeData.zoneId then
            exports.ox_target:removeZone(spikeData.zoneId)
        end
    end
    standaloneSpikes = {}
end)
