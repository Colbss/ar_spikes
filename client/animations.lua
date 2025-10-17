local config = require('config')
local playerProps = {}

-- Animation state management
local animationState = {
    isPlaying = false,
    currentType = nil
}

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
    TaskPlayAnim(playerPed, animConfig.dict, animConfig.name, 4.0, -4.0, -1, 49, 0, false, false, false)
    
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
    TaskPlayAnim(playerPed, animConfig.dict, animConfig.name, 4.0, -4.0, 1500, 0, 0, false, false, false)
    
    animationState.isPlaying = true
    animationState.currentType = 'deploy'
    
    -- Wait for animation timing then execute callback
    SetTimeout(800, function()
        if callback then callback() end
        
        -- Clean up after animation completes
        SetTimeout(700, function()
            LocalPlayer.state:set('deployer:prop', { active = false }, true)
            animationState.isPlaying = false
            animationState.currentType = nil
        end)
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
