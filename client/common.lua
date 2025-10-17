local config = require('config')
local playerProps = {}

-- Animation state management
local animationState = {
    isPlaying = false,
    currentType = nil
}

-- Shared spike types
SPIKE_TYPES = {
    STANDALONE = 'standalone',
    REMOTE_DEPLOYER = 'remote_deployer'
}

SPIKE_STATES = {
    PLACED = 'placed',
    DEPLOYED = 'deployed'
}

-- Shared functions
function PlayDeployAudio(entity)
    lib.requestAudioBank("dlc_stinger/stinger")
	local soundId = GetSoundId()
	PlaySoundFromEntity(soundId, "deploy_stinger", entity, "stinger", false, 0)
	ReleaseSoundId(soundId)
	ReleaseNamedScriptAudioBank("stinger")
end

function deploySpikes(x, y, z, h)
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

function getSpikePositions(num, origin, heading)
    local positions = {}
    for i = 1, num do
        local pos = GetOffsetFromCoordAndHeadingInWorldCoords(origin.x, origin.y, origin.z, heading, 0.0, -1.5 + (3.5 * i), 0.15)
        positions[i] = vector4(pos.x, pos.y, pos.z, heading)
    end
    return positions
end

function createSpikeStrip(positions, parentId)
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

function hasJobAccess(jobConfig)
    if not jobConfig then return true end -- No job restriction
    
    local PlayerData = exports.qbx_core:GetPlayerData()
    if not PlayerData or not PlayerData.job then return false end
    
    local playerJob = PlayerData.job
    local requiredGrade = jobConfig[playerJob.name]
    if not requiredGrade then return false end
    
    return playerJob.grade.level >= requiredGrade
end

-- Handle statebag changes for prop attachments
AddStateBagChangeHandler('deployer:prop', nil, function(bagName, key, value, reserved, replicated)
    if replicated then return end
    
    local playerId = GetPlayerFromStateBagName(bagName)
    if playerId == 0 then return end
    
    local playerPed = GetPlayerPed(playerId)
    if not DoesEntityExist(playerPed) then return end
    
    -- Remove existing prop
    if playerProps[playerId] then
        DeleteEntity(playerProps[playerId])
        playerProps[playerId] = nil
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
        
        playerProps[playerId] = prop
    end
end)

-- Start tune animation (loops indefinitely)
function StartTuneAnimation()
    if animationState.isPlaying then return end
    
    local playerPed = cache.ped
    local animConfig = config.deployer.anim.tune
    
    -- Set statebag for prop attachment
    LocalPlayer.state:set('deployer:prop', {
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
function StopTuneAnimation()
    if not animationState.isPlaying or animationState.currentType ~= 'tune' then return end
    
    local playerPed = cache.ped
    
    -- Clear statebag
    LocalPlayer.state:set('deployer:prop', { active = false }, true)
    
    -- Stop animation
    ClearPedTasks(playerPed)
    
    animationState.isPlaying = false
    animationState.currentType = nil
end

-- Play deploy animation (one-time with delay)
function PlayDeployAnimation(callback)
    if animationState.isPlaying then return end
    
    local playerPed = cache.ped
    local animConfig = config.deployer.anim.deploy
    
    -- Set statebag for prop attachment
    LocalPlayer.state:set('deployer:prop', {
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
            LocalPlayer.state:set('deployer:prop', { active = false }, true)
            animationState.isPlaying = false
            animationState.currentType = nil
        end)
        if callback then callback() end
    end)
end

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    -- Clean up all props
    for playerId, prop in pairs(playerProps) do
        if DoesEntityExist(prop) then
            DeleteEntity(prop)
        end
    end
    
    -- Clear own statebag
    LocalPlayer.state:set('deployer:prop', { active = false }, true)
end)

-- Export functions
exports('StartTuneAnimation', StartTuneAnimation)
exports('StopTuneAnimation', StopTuneAnimation)
exports('PlayDeployAnimation', PlayDeployAnimation)
