local config = require 'config'

-- Unified table for all spike systems
local deployedSpikes = {}
local spikeIdCounter = 0

-- Spike types and states
local SPIKE_TYPES = {
    STANDALONE = 'standalone',
    REMOTE_DEPLOYER = 'remote_deployer'
}

local SPIKE_STATES = {
    PLACED = 'placed',      -- For remote deployers (not deployed)
    DEPLOYED = 'deployed'   -- For both types when spikes are active
}

local function generateSpikeId()
    spikeIdCounter = spikeIdCounter + 1
    return spikeIdCounter
end

local function generateFrequency()
    return math.random(config.deployer.frequency.min, config.deployer.frequency.max)
end

local function getSpikePositions(num, origin, heading)
    local positions = {}
    for i = 1, num do
        local pos = GetOffsetFromCoordAndHeadingInWorldCoords(origin.x, origin.y, origin.z, heading, 0.0, -1.5 + (3.5 * i), 0.15)
        positions[i] = vector4(pos.x, pos.y, pos.z, heading)
    end
    return positions
end

local function removePlayerSpikes(serverId)
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.owner == serverId then
            deployedSpikes[spikeId] = nil
            if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER then
                TriggerClientEvent('colbss-spikes:client:removeDeployer', -1, spikeId)
            elseif spikeData.type == SPIKE_TYPES.STANDALONE then
                TriggerClientEvent('colbss-spikes:client:removeStandaloneSpikes', -1, spikeId)
            end
        end
    end
end

local function hasJobAccess(Player, jobConfig)
    if not jobConfig then return true end -- No job restriction
    
    local playerJob = Player.PlayerData.job
    if not playerJob then return false end
    
    local requiredGrade = jobConfig[playerJob.name]
    if not requiredGrade then return false end
    
    return playerJob.grade.level >= requiredGrade
end

-- Unified event to create any spike type
RegisterNetEvent('colbss-spikes:server:createSpike', function(spikeData)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local deployCoords
    
    if spikeData.type == SPIKE_TYPES.STANDALONE then
        -- For standalone spikes, use the first position in the array
        if spikeData.positions and #spikeData.positions > 0 then
            deployCoords = vector3(spikeData.positions[1].x, spikeData.positions[1].y, spikeData.positions[1].z)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                description = 'Invalid spike positions data',
                type = 'error'
            })
            return
        end
    else
        -- For remote deployer, use the coords directly
        deployCoords = vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z)
    end
    
    local distance = #(playerCoords - deployCoords)
    
    if distance > 5.0 then
        TriggerClientEvent('ox_lib:notify', src, {
            description = 'You cannot place spikes this far away',
            type = 'error'
        })
        return
    end

    local spikeId = generateSpikeId()
    
    if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER then
        -- Check job access for deployer
        if not hasJobAccess(Player, config.deployer.jobs) then
            return TriggerClientEvent('ox_lib:notify', src, {
                description = 'You do not have permission to use spike deployers',
                type = 'error'
            })
        end
        
        -- Handle remote deployer
        local hasItem = exports.ox_inventory:GetItem(src, 'spike_deployer', nil, true)
        
        if hasItem and hasItem >= 1 then
            exports.ox_inventory:RemoveItem(src, 'spike_deployer', 1)
            
            local frequency = generateFrequency()
            
            -- Store spike data
            deployedSpikes[spikeId] = {
                type = SPIKE_TYPES.REMOTE_DEPLOYER,
                state = SPIKE_STATES.PLACED,
                owner = src,
                coords = spikeData.coords,
                heading = spikeData.heading,
                frequency = frequency,
                timestamp = os.time()
            }
            
            -- Send to all clients
            TriggerClientEvent('colbss-spikes:client:createDeployer', -1, spikeId, {
                type = SPIKE_TYPES.REMOTE_DEPLOYER,
                coords = spikeData.coords,
                heading = spikeData.heading,
                frequency = frequency
            }, src)
            
            TriggerClientEvent('ox_lib:notify', src, {
                description = 'Spike deployer placed on frequency: ' .. frequency .. ' MHz',
                type = 'success'
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                description = 'You don\'t have a spike deployer',
                type = 'error'
            })
        end
        
    elseif spikeData.type == SPIKE_TYPES.STANDALONE then
        -- Check job access for roll
        if not hasJobAccess(Player, config.roll.jobs) then
            return TriggerClientEvent('ox_lib:notify', src, {
                description = 'You do not have permission to use spike rolls',
                type = 'error'
            })
        end
        
        -- Handle standalone spike strip
        local hasItem = exports.ox_inventory:GetItem(src, 'spike_roll', nil, true)
        
        if hasItem and hasItem >= 1 then
            exports.ox_inventory:RemoveItem(src, 'spike_roll', 1)
            
            -- Store spike data
            deployedSpikes[spikeId] = {
                type = SPIKE_TYPES.STANDALONE,
                state = SPIKE_STATES.DEPLOYED,
                owner = src,
                positions = spikeData.positions,
                length = spikeData.length,
                timestamp = os.time()
            }
            
            -- Send to all clients
            TriggerClientEvent('colbss-spikes:client:createStandaloneSpikes', -1, spikeId, {
                type = SPIKE_TYPES.STANDALONE,
                positions = spikeData.positions
            }, src)
            
            TriggerClientEvent('ox_lib:notify', src, {
                description = 'Spike strips deployed successfully',
                type = 'success'
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                description = 'You don\'t have a spike roll',
                type = 'error'
            })
        end
    end
end)

-- Callback to validate remote deployment request
lib.callback.register('colbss-spikes:server:validateRemoteDeployment', function(source, frequency)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then
        return { 
            success = false, 
            message = "Player not found" 
        }
    end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    
    -- Look for a remote deployer with matching frequency that hasn't been deployed yet
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER and 
           spikeData.frequency == frequency and 
           spikeData.state == SPIKE_STATES.PLACED then
            
            -- Check distance from player to deployer
            local deployerCoords = vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z)
            local distance = #(playerCoords - deployerCoords)
            
            if distance > config.deployer.maxDistance then
                return { 
                    success = false, 
                    message = string.format('Deployer is too far away (%.1fm). Max range: %.1fm', distance, config.deployer.maxDistance)
                }
            end
            
            -- Valid deployment - return deployer data
            return { 
                success = true, 
                spikeId = spikeId,
                deployerData = {
                    coords = spikeData.coords,
                    heading = spikeData.heading,
                    frequency = spikeData.frequency
                }
            }
        end
    end
    
    -- Check if there's a deployer but already deployed
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER and 
           spikeData.frequency == frequency and
           spikeData.state == SPIKE_STATES.DEPLOYED then
            return { 
                success = false, 
                message = 'Spikes already deployed on frequency ' .. frequency .. ' MHz.'
            }
        end
    end
    
    -- No deployer found on frequency
    return { 
        success = false, 
        message = 'No deployer found on frequency ' .. frequency .. ' MHz.'
    }
end)

-- Event to update spike state after client deployment
RegisterNetEvent('colbss-spikes:server:updateSpikeState', function(spikeId, positions)
    local src = source
    local spikeData = deployedSpikes[spikeId]

    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local deployerCoords = vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z)
    local distance = #(playerCoords - deployerCoords)
            
    if distance > config.deployer.maxDistance then
        return
    end
    
    if not spikeData or spikeData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= SPIKE_STATES.PLACED then
        return
    end
    
    -- Update server data
    deployedSpikes[spikeId].state = SPIKE_STATES.DEPLOYED
    deployedSpikes[spikeId].positions = positions
    
    -- Tell all clients to deploy the spikes
    TriggerClientEvent('colbss-spikes:client:deployRemoteSpikes', -1, spikeId, positions)
    
    -- Notify the player
    -- TriggerClientEvent('ox_lib:notify', src, {
    --     description = 'Remote spikes deployed successfully',
    --     type = 'success'
    -- })
end)

-- Event to reset a remote deployer
RegisterNetEvent('colbss-spikes:server:resetDeployer', function(spikeId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'Deployer not found',
            type = 'error'
        })
    end
    
    -- Check job access instead of ownership
    if not hasJobAccess(Player, config.deployer.jobs) then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'You do not have permission to reset deployers',
            type = 'error'
        })
    end
    
    -- Only allow reset of deployed remote deployers
    if spikeData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= SPIKE_STATES.DEPLOYED then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'Deployer is not deployed or invalid',
            type = 'error'
        })
    end
    
    -- Check distance
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local deployerCoords = vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z)
    local distance = #(playerCoords - deployerCoords)
    
    if distance > 5.0 then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'You are too far away from the deployer',
            type = 'error'
        })
    end
    
    -- Update server data
    deployedSpikes[spikeId].state = SPIKE_STATES.PLACED
    deployedSpikes[spikeId].positions = nil
    
    -- Tell all clients to reset the deployer
    TriggerClientEvent('colbss-spikes:client:resetDeployer', -1, spikeId)
    
    TriggerClientEvent('ox_lib:notify', src, {
        description = 'Deployer reset successfully',
        type = 'success'
    })
end)

RegisterNetEvent('colbss-spikes:server:tuneRemoteFrequency', function(slot, frequency)
    local src = source
    
    -- Verify item ownership again (for security)
    local item = exports.ox_inventory:GetSlot(src, slot)
    if item and item.name == 'spike_deployer_remote' then
        exports.ox_inventory:SetMetadata(src, slot, {frequency = frequency})
    end
end)

RegisterNetEvent('colbss-spikes:server:pickupSpike', function(spikeId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'Spike system not found',
            type = 'error'
        })
    end
    
    -- Check job access instead of ownership
    if not hasJobAccess(Player, config.deployer.jobs) then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'You do not have permission to pick up equipment',
            type = 'error'
        })
    end
    
    -- Only allow pickup of remote deployers that haven't deployed spikes
    if spikeData.type ~= SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= SPIKE_STATES.PLACED then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'Cannot pick up deployed spike systems',
            type = 'error'
        })
    end
    
    -- Check distance
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local distance = #(playerCoords - vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z))
    
    if distance > 5.0 then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'You are too far away',
            type = 'error'
        })
    end
    
    -- Give back the appropriate item
    if spikeData.type == SPIKE_TYPES.REMOTE_DEPLOYER then
        exports.ox_inventory:AddItem(src, 'spike_deployer', 1)
    end
    
    -- Remove spike from tracking
    deployedSpikes[spikeId] = nil
    
    -- Tell all clients to remove this spike
    TriggerClientEvent('colbss-spikes:client:removeDeployer', -1, spikeId)
    
    TriggerClientEvent('ox_lib:notify', src, {
        description = 'Equipment picked up',
        type = 'success'
    })
end)

-- Event to pickup standalone spike strips
RegisterNetEvent('colbss-spikes:server:pickupStandaloneSpikes', function(spikeId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'Spike system not found',
            type = 'error'
        })
    end
    
    -- Check job access for roll pickup
    if not hasJobAccess(Player, config.roll.jobs) then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'You do not have permission to pick up spike strips',
            type = 'error'
        })
    end
    
    -- Only allow pickup of standalone spikes
    if spikeData.type ~= SPIKE_TYPES.STANDALONE then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'Invalid spike system type',
            type = 'error'
        })
    end
    
    -- Check distance to any spike in the strip
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local minDistance = math.huge
    
    for _, pos in ipairs(spikeData.positions) do
        local distance = #(playerCoords - vector3(pos.x, pos.y, pos.z))
        if distance < minDistance then
            minDistance = distance
        end
    end
    
    if minDistance > 5.0 then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = 'You are too far away',
            type = 'error'
        })
    end
    
    -- Give back spike roll
    exports.ox_inventory:AddItem(src, 'spike_roll', 1)
    
    -- Remove spike from tracking
    deployedSpikes[spikeId] = nil
    
    -- Tell all clients to remove this spike
    TriggerClientEvent('colbss-spikes:client:removeStandaloneSpikes', -1, spikeId)
    
    TriggerClientEvent('ox_lib:notify', src, {
        description = 'Spike strips picked up',
        type = 'success'
    })
end)

-- Clean up spikes when player disconnects
AddEventHandler('playerDropped', function(reason)
    local src = source
    removePlayerSpikes(src)
end)