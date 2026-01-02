local config = require 'config'
LocalState = LocalPlayer.state
lib.locale()

-- ▄█████ ▄████▄ ██▄  ▄██ ██▄  ▄██ ▄████▄ ███  ██ 
-- ██     ██  ██ ██ ▀▀ ██ ██ ▀▀ ██ ██  ██ ██ ▀▄██ 
-- ▀█████ ▀████▀ ██    ██ ██    ██ ▀████▀ ██   ██ 

common = {}

common.DeployedSpikes = {}
common.NearbyCount = 0
common.NearbySpikes = {}
common.StingersTick = nil

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

function common.DeployTempSpikes(x, y, z, h)
    local spikeModel = 'p_ld_stinger_s'
    lib.requestModel(spikeModel)
    lib.requestAnimDict('P_ld_stinger_s')
    
    local stinger = CreateObject(spikeModel, x, y, z, true, true, false)
    SetEntityAsMissionEntity(stinger, true, true)
    SetEntityHeading(stinger, h)
    FreezeEntityPosition(stinger, true)
    PlaceObjectOnGroundProperly(stinger)
    SetEntityVisible(stinger, false)
    
    PlayEntityAnim(stinger, "P_Stinger_S_Deploy", 'P_ld_stinger_s', 1000.0, false, true, 0, 0.0, 0)
    while not IsEntityPlayingAnim(stinger, 'P_ld_stinger_s', "P_Stinger_S_Deploy", 3) do
        Wait(0)
    end
    SetEntityAnimSpeed(stinger, 'P_ld_stinger_s', "P_Stinger_S_Deploy", 1.75)
    playDeployAudio(stinger)
    SetEntityVisible(stinger, true)
    
    while IsEntityPlayingAnim(stinger, 'P_ld_stinger_s', "P_Stinger_S_Deploy", 3) and 
          GetEntityAnimCurrentTime(stinger, "p_ld_stinger_s", "P_Stinger_S_Deploy") <= 0.99 do
        Wait(0)
    end
    
    PlayEntityAnim(stinger, "p_stinger_s_idle_deployed", 'P_ld_stinger_s', 1000.0, false, true, 0, 0.99, 0)

    SetModelAsNoLongerNeeded(spikeModel)
    RemoveAnimDict('P_ld_stinger_s')
    
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
    
    SetModelAsNoLongerNeeded(spikeModel)

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
    TaskAchieveHeading(cache.ped, heading, 500)
    local startTime = GetGameTimer()
    
    CreateThread(function()
        while GetGameTimer() - startTime < 3000 do
            if isPlayerFacingHeading(cache.ped, heading, 10) then
                break
            end
            TaskAchieveHeading(cache.ped, heading, 500)
            Wait(500)
        end
        
        if callback then callback() end
    end)
end

-- ██ ▄█▀ ██████ ██  ██ █████▄ ██ ███  ██ ████▄  ▄█████ 
-- ████   ██▄▄    ▀██▀  ██▄▄██ ██ ██ ▀▄██ ██  ██ ▀▀▀▄▄▄     -- https://patorjk.com/software/taag - ANSI Compact
-- ██ ▀█▄ ██▄▄▄▄   ██   ██▄▄█▀ ██ ██   ██ ████▀  █████▀ 

-- Courtesy of @MadsL
-- https://forum.cfx.re/t/help-how-to-get-the-current-keybind-of-a-registered-keymap/1847600/7

local specialkeyCodes = {
    ['b_100'] = 'LMB', -- Left Mouse Button
    ['b_101'] = 'RMB', -- Right Mouse Button
    ['b_102'] = 'MMB', -- Middle Mouse Button
    ['b_103'] = 'Mouse.ExtraBtn1',
    ['b_104'] = 'Mouse.ExtraBtn2',
    ['b_105'] = 'Mouse.ExtraBtn3',
    ['b_106'] = 'Mouse.ExtraBtn4',
    ['b_107'] = 'Mouse.ExtraBtn5',
    ['b_108'] = 'Mouse.ExtraBtn6',
    ['b_109'] = 'Mouse.ExtraBtn7',
    ['b_110'] = 'Mouse.ExtraBtn8',
    ['b_115'] = 'MouseWheel.Up',
    ['b_116'] = 'MouseWheel.Down',
    ['b_130'] = 'NumSubstract',
    ['b_131'] = 'NumAdd',
    ['b_134'] = 'Num Multiplication',
    ['b_135'] = 'Num Enter',
    ['b_137'] = 'Num1',
    ['b_138'] = 'Num2',
    ['b_139'] = 'Num3',
    ['b_140'] = 'Num4',
    ['b_141'] = 'Num5',
    ['b_142'] = 'Num6',
    ['b_143'] = 'Num7',
    ['b_144'] = 'Num8',
    ['b_145'] = 'Num9',
    ['b_170'] = 'F1',
    ['b_171'] = 'F2',
    ['b_172'] = 'F3',
    ['b_173'] = 'F4',
    ['b_174'] = 'F5',
    ['b_175'] = 'F6',
    ['b_176'] = 'F7',
    ['b_177'] = 'F8',
    ['b_178'] = 'F9',
    ['b_179'] = 'F10',
    ['b_180'] = 'F11',
    ['b_181'] = 'F12',
    ['b_182'] = 'F13',
    ['b_183'] = 'F14',
    ['b_184'] = 'F15',
    ['b_185'] = 'F16',
    ['b_186'] = 'F17',
    ['b_187'] = 'F18',
    ['b_188'] = 'F19',
    ['b_189'] = 'F20',
    ['b_190'] = 'F21',
    ['b_191'] = 'F22',
    ['b_192'] = 'F23',
    ['b_193'] = 'F24',
    ['b_194'] = 'Arrow Up',
    ['b_195'] = 'Arrow Down',
    ['b_196'] = 'Arrow Left',
    ['b_197'] = 'Arrow Right',
    ['b_198'] = 'Delete',
    ['b_199'] = 'Escape',
    ['b_200'] = 'Insert',
    ['b_201'] = 'End',
    ['b_210'] = 'Delete',
    ['b_211'] = 'Insert',
    ['b_212'] = 'End',
    ['b_1000'] = 'Shift',
    ['b_1002'] = 'Tab',
    ['b_1003'] = 'Enter',
    ['b_1004'] = 'Backspace',
    ['b_1009'] = 'PageUp',
    ['b_1008'] = 'Home',
    ['b_1010'] = 'PageDown',
    ['b_1012'] = 'CapsLock',
    ['b_1013'] = 'Control',
    ['b_1014'] = 'Right Control',
    ['b_1015'] = 'Alt',
    ['b_1055'] = 'Home',
    ['b_1056'] = 'PageUp',
    ['b_2000'] = 'Space'
}

function common.GetKeyLabel(commandHash)
    local key = GetControlInstructionalButton(0, commandHash | 0x80000000, true)
    if string.find(key, "t_") then
        local label, _count = string.gsub(key, "t_", "")
        return label
    else
        return specialkeyCodes[key] or "unknown"
    end
end

keybinds = {}

keybinds.select = lib.addKeybind({
    name = 'spikes_select',
    description = locale('keybind_select'),
    defaultKey = 'RETURN',
    onPressed = function(self)
        ConfirmSpikePlacement()
    end
})

keybinds.cancel = lib.addKeybind({
    name = 'spikes_cancel',
    description = locale('keybind_cancel'),
    defaultKey = 'BACK',
    onPressed = function(self)
        CancelSpikePlacement()
    end
})

keybinds.increase = lib.addKeybind({
    name = 'spikes_increase',
    description = locale('keybind_increase'),
    defaultKey = 'UP',
    onPressed = function(self)
        ChangeSpikeCount(1)
    end
})

keybinds.decrease = lib.addKeybind({
    name = 'spikes_decrease',
    description = locale('keybind_decrease'),
    defaultKey = 'DOWN',
    onPressed = function(self)
        ChangeSpikeCount(-1)
    end
})

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
