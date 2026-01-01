local config = require('config')
LocalState = LocalPlayer.state

-- ▄█████ ▄████▄ ██▄  ▄██ ██▄  ▄██ ▄████▄ ███  ██ 
-- ██     ██  ██ ██ ▀▀ ██ ██ ▀▀ ██ ██  ██ ██ ▀▄██ 
-- ▀█████ ▀████▀ ██    ██ ██    ██ ▀████▀ ██   ██ 

common = {}

common.DeployedSpikes = {}
common.NearbyCount = 0
common.NearbySpikes = {}
common.StingersTick = nil

common.SPIKE_TYPES = {
    STANDALONE = 'standalone',
    REMOTE_DEPLOYER = 'remote_deployer'
}
common.SPIKE_STATES = {
    PLACED = 'placed',
    DEPLOYED = 'deployed'
}

function common.AddSpikeToSystem(spikeId, spikeType, spikes)
    common.DeployedSpikes[spikeId] = {
        type = spikeType,
        spikes = spikes
    }
end

function common.RemoveSpikeFromSystem(spikeId)
    common.DeployedSpikes[spikeId] = nil
end

function common.GetSpikeInSystem(spikeId)
    return common.DeployedSpikes[spikeId]
end

function common.DeploySpikes(x, y, z, h)
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
    playDeployAudio(stinger)
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

function common.GetSpikePositions(num, origin, heading)
    local positions = {}
    for i = 1, num do
        local pos = GetOffsetFromCoordAndHeadingInWorldCoords(origin.x, origin.y, origin.z, heading, 0.0, -1.5 + (3.5 * i), 0.15)
        positions[i] = vector4(pos.x, pos.y, pos.z, heading)
    end
    return positions
end

function common.CreateSpikeStrip(positions, parentId)
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

function common.HasJobAccess(jobConfig)
    if not jobConfig then return true end
    
    local PlayerData = exports.qbx_core:GetPlayerData()
    if not PlayerData or not PlayerData.job then return false end
    
    local playerJob = PlayerData.job
    local requiredGrade = jobConfig[playerJob.name]
    if not requiredGrade then return false end
    
    return playerJob.grade.level >= requiredGrade
end

function common.FaceCoords(coords, callback)
    local heading = headingToCoords(cache.ped, coords)
    TaskAchieveHeading(cache.ped, heading, 3000)
    local startTime = GetGameTimer()
    
    CreateThread(function()
        while GetGameTimer() - startTime < 3000 do
            if isPlayerFacingHeading(cache.ped, heading, 10) then
                break
            end
            TaskAchieveHeading(cache.ped, heading, 3000)
            Wait(100)
        end
        
        if callback then callback() end
    end)
end

-- ██████ ██  ██ ███  ██ ▄█████ ██████ ██ ▄████▄ ███  ██ ▄█████ 
-- ██▄▄   ██  ██ ██ ▀▄██ ██       ██   ██ ██  ██ ██ ▀▄██ ▀▀▀▄▄▄ 
-- ██     ▀████▀ ██   ██ ▀█████   ██   ██ ▀████▀ ██   ██ █████▀ 

function playDeployAudio(entity)
    lib.requestAudioBank("dlc_stinger/stinger")
	local soundId = GetSoundId()
	PlaySoundFromEntity(soundId, "deploy_stinger", entity, "stinger", false, 0)
	ReleaseSoundId(soundId)
	ReleaseNamedScriptAudioBank("stinger")
end

function headingToCoords(ped, coords) 
	local from = GetEntityCoords(ped)
	local to = coords       		
	local dx = to.x - from.x
	local dy = to.y - from.y
	local heading = GetHeadingFromVector_2d(dx, dy)
    return heading
end

function calculateHeadingDifference(heading1, heading2)
    local diff = math.abs(heading1 - heading2) % 360
    if diff > 180 then
        diff = 360 - diff
    end
    return diff
end

function isPlayerFacingHeading(ped, heading, threshold)
    local playerHeading = GetEntityHeading(ped)
    local difference = calculateHeadingDifference(playerHeading, heading)
    return difference <= threshold
end

local bones = {
    { bone = "wheel_lf", index = 0 },
    { bone = "wheel_rf", index = 1 },
    { bone = "wheel_lm1", index = 2 },
    { bone = "wheel_rm1", index = 3 },
    { bone = "wheel_lr", index = 4 },
    { bone = "wheel_rr", index = 5 },
    { bone = "wheel_lm2", index = 45 },
    { bone = "wheel_lm3", index = 46 },
    { bone = "wheel_rm2", index = 47 },
    { bone = "wheel_rm3", index = 48 },
}

function handleTouching(minOffset, maxOffset, vehicle)
    for i = 1, #bones do
        local bone = bones[i]
        local boneIndex = GetEntityBoneIndexByName(vehicle, bone.bone)

        if boneIndex == -1 or IsVehicleTyreBurst(vehicle, bone.index, false) then
            goto nextBone
        end

        local boneCoords = GetWorldPositionOfEntityBone(vehicle, boneIndex)
        local wheelTouching = IsPointInAngledArea(
            boneCoords.x, boneCoords.y, boneCoords.z,
            minOffset.x, minOffset.y, minOffset.z,
            maxOffset.x, maxOffset.y, maxOffset.z,
            0.45, false, false
        )

        if wheelTouching then
            SetVehicleTyreBurst(vehicle, bone.index, false, 100.0)
        end

        ::nextBone::
    end
end

-- ██████ ██  ██ █████▄  ██████ ▄████▄ ████▄  ▄█████ 
--   ██   ██████ ██▄▄██▄ ██▄▄   ██▄▄██ ██  ██ ▀▀▀▄▄▄ 
--   ██   ██  ██ ██   ██ ██▄▄▄▄ ██  ██ ████▀  █████▀ 

function processStingers()
    local vehicle = cache.vehicle

    if not vehicle or (vehicle and config.immune[GetEntityModel(vehicle)]) then
        return
    end

    local vehicleCoords = GetEntityCoords(vehicle)
    for id, spikeData in pairs(common.NearbySpikes) do
        if spikeData.spikes then
            for _, spike in pairs(spikeData.spikes) do
                if vehicle and #(vehicleCoords - spike.coords.xyz) < 10.0 then
                    if IsEntityTouchingEntity(spike.entity, vehicle) then
                        -- Calculate collision boundaries for this spike
                        local spikeCoords = GetEntityCoords(spike.entity)
                        local minOffset = GetOffsetFromEntityInWorldCoords(spike.entity, 0.0, -1.84, -0.1)
                        local maxOffset = GetOffsetFromEntityInWorldCoords(spike.entity, 0.0, 1.84, 0.1)
                        handleTouching(minOffset, maxOffset, vehicle)
                    end
                end
            end
        end
    end
end

CreateThread(function()
    while true do
        if common.NearbyCount ~= 0 then
            table.wipe(common.NearbySpikes)
            common.NearbyCount = 0
        end

        local coords = GetEntityCoords(cache.ped)

        for id, spikeData in pairs(common.DeployedSpikes) do
            if spikeData.spikes and #spikeData.spikes > 0 then
                local distance = #(coords - spikeData.spikes[1].coords.xyz)

                if distance > 100.0 then
                    goto continue
                end

                common.NearbyCount = common.NearbyCount + 1
                common.NearbySpikes[id] = spikeData

                ::continue::
            end
        end

        if common.NearbyCount > 0 and cache.seat == -1 then
            if not common.StingersTick then
                common.StingersTick = SetInterval(processStingers)
            end
        elseif common.StingersTick then
            common.StingersTick = ClearInterval(common.StingersTick)
        end

        Wait(250)
    end
end)

-- ██  ██ ▄████▄ ███  ██ ████▄  ██     ██████ █████▄  ▄█████ 
-- ██████ ██▄▄██ ██ ▀▄██ ██  ██ ██     ██▄▄   ██▄▄██▄ ▀▀▀▄▄▄ 
-- ██  ██ ██  ██ ██   ██ ████▀  ██████ ██▄▄▄▄ ██   ██ █████▀ 

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    
    if common.StingersTick then
        ClearInterval(common.StingersTick)
    end
    
    for id, spikeData in pairs(common.DeployedSpikes) do
        if spikeData.spikes then
            for _, spike in pairs(spikeData.spikes) do
                if DoesEntityExist(spike.entity) then
                    DeleteEntity(spike.entity)
                end
            end
        end
    end
end)
