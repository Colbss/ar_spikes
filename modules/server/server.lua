local config = require 'config'
local shared = require 'shared'
lib.locale()

local deployedSpikes = {}
local spikeIdCounter = 0

local function generateSpikeId()
    spikeIdCounter = spikeIdCounter + 1
    return spikeIdCounter
end

local function generateFrequency()
    return math.random(config.deployer.frequency.min, config.deployer.frequency.max)
end

local function removePlayerSpikes(serverId)
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.owner == serverId then
            deployedSpikes[spikeId] = nil
            if spikeData.type == shared.SPIKE_TYPES.REMOTE_DEPLOYER then
                TriggerClientEvent('ar_spikes:client:removeDeployer', -1, spikeId)
            elseif spikeData.type == shared.SPIKE_TYPES.STANDALONE then
                TriggerClientEvent('ar_spikes:client:removeStandaloneSpikes', -1, spikeId)
            end
        end
    end
end

local function hasJobAccess(Player, jobConfig)
    if not jobConfig then return true end
    
    local playerJob = Player.PlayerData.job
    if not playerJob then return false end
    
    local requiredGrade = jobConfig[playerJob.name]
    if not requiredGrade then return false end
    
    return playerJob.grade.level >= requiredGrade
end

RegisterNetEvent('ar_spikes:server:createSpike', function(spikeData)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local deployCoords
    
    if spikeData.type == shared.SPIKE_TYPES.STANDALONE then
        if spikeData.positions and #spikeData.positions > 0 then
            deployCoords = vector3(spikeData.positions[1].x, spikeData.positions[1].y, spikeData.positions[1].z)
        else
            TriggerClientEvent('ox_lib:notify', src, {
                description = locale('server_invalid_spike_position'),
                type = 'error'
            })
            return
        end
    else
        deployCoords = vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z)
    end
    
    local distance = #(playerCoords - deployCoords)
    
    if distance > 5.0 then
        TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_too_far'),
            type = 'error'
        })
        return
    end

    local spikeId = generateSpikeId()
    
    if spikeData.type == shared.SPIKE_TYPES.REMOTE_DEPLOYER then
        if not hasJobAccess(Player, config.deployer.jobs) then
            return TriggerClientEvent('ox_lib:notify', src, {
                description = locale('no_permission'),
                type = 'error'
            })
        end
        
        local hasItem = exports.ox_inventory:GetItem(src, 'spike_deployer', nil, true)
        
        if hasItem and hasItem >= 1 then
            exports.ox_inventory:RemoveItem(src, 'spike_deployer', 1)
            
            local frequency = generateFrequency()
            
            deployedSpikes[spikeId] = {
                type = shared.SPIKE_TYPES.REMOTE_DEPLOYER,
                state = shared.SPIKE_STATES.PLACED,
                owner = src,
                coords = spikeData.coords,
                heading = spikeData.heading,
                frequency = frequency,
                timestamp = os.time()
            }
            
            TriggerClientEvent('ar_spikes:client:createDeployer', -1, spikeId, {
                type = shared.SPIKE_TYPES.REMOTE_DEPLOYER,
                coords = spikeData.coords,
                heading = spikeData.heading,
                frequency = frequency
            }, src)
            
            TriggerClientEvent('ox_lib:notify', src, {
                description = locale('server_deployer_placed', frequency),
                type = 'success'
            })

            CreateLog(src, locale('logs_deployer_placed'), locale('logs_deployer_placed_description'), {
                id = spikeId,
                type = shared.SPIKE_TYPES.REMOTE_DEPLOYER,
                coords = {
                    x = tonumber(string.format("%.2f", spikeData.coords.x)),
                    y = tonumber(string.format("%.2f", spikeData.coords.y)),
                    z = tonumber(string.format("%.2f", spikeData.coords.z))
                },
                frequency = frequency
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                description = locale('server_no_deployer'),
                type = 'error'
            })
        end
        
    elseif spikeData.type == shared.SPIKE_TYPES.STANDALONE then
        if not hasJobAccess(Player, config.roll.jobs) then
            return TriggerClientEvent('ox_lib:notify', src, {
                description = locale('no_permission'),
                type = 'error'
            })
        end
        
        local hasItem = exports.ox_inventory:GetItem(src, 'spike_roll', nil, true)
        
        if hasItem and hasItem >= 1 then
            exports.ox_inventory:RemoveItem(src, 'spike_roll', 1)
            
            deployedSpikes[spikeId] = {
                type = shared.SPIKE_TYPES.STANDALONE,
                state = shared.SPIKE_STATES.DEPLOYED,
                owner = src,
                positions = spikeData.positions,
                length = spikeData.length,
                timestamp = os.time()
            }
            
            TriggerClientEvent('ar_spikes:client:createStandaloneSpikes', -1, spikeId, {
                type = shared.SPIKE_TYPES.STANDALONE,
                positions = spikeData.positions
            }, src)
            
            TriggerClientEvent('ox_lib:notify', src, {
                description = locale('server_spikes_placed'),
                type = 'success'
            })

            CreateLog(src, locale('logs_spikes_placed'), locale('logs_spikes_placed_description'), {
                id = spikeId,
                type = shared.SPIKE_TYPES.STANDALONE,
                coords = {
                    x = tonumber(string.format("%.2f", spikeData.positions[1].x)),
                    y = tonumber(string.format("%.2f", spikeData.positions[1].y)),
                    z = tonumber(string.format("%.2f", spikeData.positions[1].z))
                },
                length = spikeData.length
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                description = locale('server_no_spikes'),
                type = 'error'
            })
        end
    end
end)

lib.callback.register('ar_spikes:server:validateRemoteDeployment', function(source, frequency)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then
        return { 
            success = false, 
            message = "Player not found" 
        }
    end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.type == shared.SPIKE_TYPES.REMOTE_DEPLOYER and 
           spikeData.frequency == frequency and 
           spikeData.state == shared.SPIKE_STATES.PLACED then
            
            local deployerCoords = vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z)
            local distance = #(playerCoords - deployerCoords)
            
            if distance > config.deployer.maxDistance then
                return { 
                    success = false, 
                    message = string.format('Deployer is too far away (%.1fm). Max range: %.1fm', distance, config.deployer.maxDistance)
                }
            end
            
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
    
    for spikeId, spikeData in pairs(deployedSpikes) do
        if spikeData.type == shared.SPIKE_TYPES.REMOTE_DEPLOYER and 
           spikeData.frequency == frequency and
           spikeData.state == shared.SPIKE_STATES.DEPLOYED then
            return { 
                success = false, 
                message = 'Spikes already deployed on frequency ' .. frequency .. ' MHz.'
            }
        end
    end
    
    return { 
        success = false, 
        message = 'No deployer found on frequency ' .. frequency .. ' MHz.'
    }
end)

lib.callback.register('ar_spikes:server:checkMaxSpikes', function(source, sType)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then
        return false
    end

    local maxSpikes = sType == shared.SPIKE_TYPES.STANDALONE and config.roll.max or config.deployer.max
    local deployedCount = 0

    for _, spikeData in pairs(deployedSpikes) do
        if spikeData.owner == src and spikeData.type == sType then
            deployedCount = deployedCount + 1
        end
    end

    if deployedCount >= maxSpikes then
        return false
    end

    return true
end)

RegisterNetEvent('ar_spikes:server:deployRemoteSpikes', function(spikeId, positions)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end

    local spikeData = deployedSpikes[spikeId]
    if not spikeData then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_not_found'),
            type = 'error'
        })
    end

    local count = exports.ox_inventory:GetItem(src, 'spike_deployer_remote', {frequency = spikeData.frequency}, true)
    if count < 1 then
        return
    end

    local deployerCoords = vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z)
    for _, pos in ipairs(positions) do
        local positionCoords = vector3(pos.x, pos.y, pos.z)
        local distance = #(positionCoords - deployerCoords)
        if distance > 10.0 then
            return
        end
    end

    if spikeData.type ~= shared.SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= shared.SPIKE_STATES.PLACED then
        return
    end

    deployedSpikes[spikeId].state = shared.SPIKE_STATES.DEPLOYED
    deployedSpikes[spikeId].positions = positions

    TriggerClientEvent('ar_spikes:client:deployRemoteSpikes', -1, spikeId, positions)

    CreateLog(src, locale('logs_remote_used'), locale('logs_remote_used_description'), {
        id = spikeId,
        type = shared.SPIKE_TYPES.REMOTE_DEPLOYER,
        coords = {
            x = tonumber(string.format("%.2f", spikeData.coords.x)),
            y = tonumber(string.format("%.2f", spikeData.coords.y)),
            z = tonumber(string.format("%.2f", spikeData.coords.z))
        },
        frequency = spikeData.frequency,
    })
end)

RegisterNetEvent('ar_spikes:server:resetDeployer', function(spikeId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_deployer_not_found'),
            type = 'error'
        })
    end
    
    if not hasJobAccess(Player, config.deployer.jobs) then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('no_permission'),
            type = 'error'
        })
    end
    
    if spikeData.type ~= shared.SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= shared.SPIKE_STATES.DEPLOYED then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_deployer_invalid'),
            type = 'error'
        })
    end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local deployerCoords = vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z)
    local distance = #(playerCoords - deployerCoords)
    
    if distance > 5.0 then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_too_far'),
            type = 'error'
        })
    end
    
    deployedSpikes[spikeId].state = shared.SPIKE_STATES.PLACED
    deployedSpikes[spikeId].positions = nil
    
    TriggerClientEvent('ar_spikes:client:resetDeployer', -1, spikeId)
    
    TriggerClientEvent('ox_lib:notify', src, {
        description = locale('server_deployer_reset'),
        type = 'success'
    })

    CreateLog(src, locale('logs_deployer_reset'), locale('logs_deployer_reset_description'), {
        id = spikeId,
        type = shared.SPIKE_TYPES.REMOTE_DEPLOYER,
        coords = {
            x = tonumber(string.format("%.2f", spikeData.coords.x)),
            y = tonumber(string.format("%.2f", spikeData.coords.y)),
            z = tonumber(string.format("%.2f", spikeData.coords.z))
        },
    })
end)

RegisterNetEvent('ar_spikes:server:tuneRemoteFrequency', function(slot, frequency)
    local src = source
    local item = exports.ox_inventory:GetSlot(src, slot)
    if item and item.name == 'spike_deployer_remote' then
        exports.ox_inventory:SetMetadata(src, slot, {frequency = frequency})
    end
end)

RegisterNetEvent('ar_spikes:server:pickupSpikeDeployer', function(spikeId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_not_found'),
            type = 'error'
        })
    end
    
    if not hasJobAccess(Player, config.deployer.jobs) then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('no_permission'),
            type = 'error'
        })
    end
    
    if spikeData.type ~= shared.SPIKE_TYPES.REMOTE_DEPLOYER or spikeData.state ~= shared.SPIKE_STATES.PLACED then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_deployer_cannot_pickup'),
            type = 'error'
        })
    end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(src))
    local distance = #(playerCoords - vector3(spikeData.coords.x, spikeData.coords.y, spikeData.coords.z))
    
    if distance > 5.0 then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_too_far'),
            type = 'error'
        })
    end
    
    exports.ox_inventory:AddItem(src, 'spike_deployer', 1)
    
    deployedSpikes[spikeId] = nil
    
    TriggerClientEvent('ar_spikes:client:removeDeployer', -1, spikeId)
    
    TriggerClientEvent('ox_lib:notify', src, {
        description = locale('server_deployer_picked_up'),
        type = 'success'
    })

    CreateLog(src, locale('logs_deployer_pickup'), locale('logs_deployer_pickup_description'), {
        id = spikeId,
        type = shared.SPIKE_TYPES.REMOTE_DEPLOYER,
        coords = {
            x = tonumber(string.format("%.2f", spikeData.coords.x)),
            y = tonumber(string.format("%.2f", spikeData.coords.y)),
            z = tonumber(string.format("%.2f", spikeData.coords.z))
        },
    })
end)

RegisterNetEvent('ar_spikes:server:pickupStandaloneSpikes', function(spikeId)
    local src = source
    local Player = exports.qbx_core:GetPlayer(src)
    
    if not Player then return end
    
    local spikeData = deployedSpikes[spikeId]
    if not spikeData then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_not_found'),
            type = 'error'
        })
    end
    
    if not hasJobAccess(Player, config.roll.jobs) then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('no_permission'),
            type = 'error'
        })
    end
    
    if spikeData.type ~= shared.SPIKE_TYPES.STANDALONE then
        return TriggerClientEvent('ox_lib:notify', src, {
            description = locale('server_spikes_invalid'),
            type = 'error'
        })
    end
    
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
            description = locale('server_too_far'),
            type = 'error'
        })
    end
    
    exports.ox_inventory:AddItem(src, 'spike_roll', 1)
    
    deployedSpikes[spikeId] = nil
    
    TriggerClientEvent('ar_spikes:client:removeStandaloneSpikes', -1, spikeId)
    
    TriggerClientEvent('ox_lib:notify', src, {
        description = locale('server_spikes_picked_up'),
        type = 'success'
    })

    CreateLog(src, locale('logs_spikes_picked_up'), locale('logs_spikes_picked_up_description'), {
        id = spikeId,
        type = shared.SPIKE_TYPES.STANDALONE,
        positions = spikeData.positions,
    })
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    removePlayerSpikes(src)
end)