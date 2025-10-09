local config = require 'config.client'

local spikes = {}
local PlacingSpikes = false
local SpikeModel = 'p_ld_stinger_s'

---  ____ ____  _____    _  _____ ___ ___  _   _ 
--  / ___|  _ \| ____|  / \|_   _|_ _/ _ \| \ | |
-- | |   | |_) |  _|   / _ \ | |  | | | | |  \| |
-- | |___|  _ <| |___ / ___ \| |  | | |_| | |\  |
--  \____|_| \_\_____/_/   \_\_| |___\___/|_| \_|									 

function SpawnSpike(coords)
	lib.requestModel(SpikeModel)
	x, y, z, h = table.unpack(coords)
	local stinger = CreateObject(SpikeModel, x, y, z, 0, 0, 0)
	SetEntityAsMissionEntity(stinger, true, true)
	--SetEntityNoCollisionEntity(stinger, PlayerPedId(), 1)
	--SetEntityDynamic(stinger, false)
	--ActivatePhysics(stinger)
	SetEntityHeading(stinger, h)
	--SetEntityCollision(stinger, false, false)
	FreezeEntityPosition(stinger, true)
	PlaceObjectOnGroundProperly(stinger)
	SetModelAsNoLongerNeeded(SpikeModel)
	local pos = GetEntityCoords(stinger)
	local minOffset = GetOffsetFromEntityInWorldCoords(stinger, 0.0, -1.84, -0.1)
	local maxOffset = GetOffsetFromEntityInWorldCoords(stinger, 0.0, 1.84, 0.1)
	return {handle = stinger, truePos = vec4(pos.x, pos.y, pos.z, h), minOffset = minOffset, maxOffset = maxOffset}
	--return stinger, vec4(pos.x, pos.y, pos.z, h)
end

function PlayDeployAudio(entity)
	while not RequestScriptAudioBank("dlc_stinger/stinger", false) do
		Wait(0)
	end
	local soundId = GetSoundId()
	PlaySoundFromEntity(soundId, "deploy_stinger", entity, "stinger", false, 0)
	ReleaseSoundId(soundId)
	ReleaseNamedScriptAudioBank("stinger")
end

function DeploySpikes(x, y, z, h)
    local stinger = CreateObject(SpikeModel, x, y, z, true, true, 0)
    SetEntityAsMissionEntity(stinger, true, true)
	--SetEntityNoCollisionEntity(stinger, PlayerPedId(), 1)
	--SetEntityDynamic(stinger, false)
	--ActivatePhysics(stinger)
    SetEntityHeading(stinger, h)
	--SetEntityCollision(stinger, false, false)
    FreezeEntityPosition(stinger, true)
    PlaceObjectOnGroundProperly(stinger)
    SetEntityVisible(stinger, false)
    PlayEntityAnim(stinger, "P_Stinger_S_Deploy", 'P_ld_stinger_s', 1000.0, false, true, 0, 0.0, 0)
    while not IsEntityPlayingAnim(stinger, 'P_ld_stinger_s', "P_Stinger_S_Deploy", 3) do
        Wait(0)
    end
	SetEntityAnimSpeed(stinger, 'P_ld_stinger_s', "P_Stinger_S_Deploy", 1.75);
	PlayDeployAudio(stinger)
    SetEntityVisible(stinger, true)
    while IsEntityPlayingAnim(stinger, 'P_ld_stinger_s', "P_Stinger_S_Deploy", 3) and GetEntityAnimCurrentTime(stinger, "p_ld_stinger_s", "P_Stinger_S_Deploy") <= 0.99 do
        Wait(0)
    end
    PlayEntityAnim(stinger, "p_stinger_s_idle_deployed", 'P_ld_stinger_s', 1000.0, false, true, 0, 0.99, 0)
    return stinger
end

function GetSpikeLocations(num)
	lib.requestAnimDict('mp_weapons_deal_sting')
	TaskPlayAnim(cache.ped, 'mp_weapons_deal_sting', 'crackhead_bag_loop', 5.0, 5.0, -1, 49, 1.0, false, false, false)
	lib.requestAnimDict('P_ld_stinger_s')
	lib.requestModel(SpikeModel)
	local h = GetEntityHeading(cache.ped)
	local origin = GetEntityCoords(cache.ped)
	local positions = {}
	local tempProps = {}
	for i = 1, num do
		pos = GetOffsetFromCoordAndHeadingInWorldCoords(origin.x, origin.y, origin.z, h, 0.0, -1.5+(3.5*i), 0.15)
		positions[i] = vec4(pos.x, pos.y, pos.z, h)
		tempProps[i] = DeploySpikes(pos.x, pos.y, pos.z, h)
	end
	lib.callback.await('spikes:server:newspikes', false, positions)
	for i = 1, num do
		DeleteEntity(tempProps[i])
	end
	if IsEntityPlayingAnim(cache.ped, 'mp_weapons_deal_sting', "crackhead_bag_loop", 3) then
		StopAnimTask(cache.ped, 'mp_weapons_deal_sting', "crackhead_bag_loop", 1.0)
	end
	RemoveAnimDict('mp_weapons_deal_sting')
	RemoveAnimDict('P_ld_stinger_s')
	SetModelAsNoLongerNeeded(SpikeModel)
end

local rollProp = nil
function AttachStingerRoll()
	local rollModel = 'stinger_roll'
	lib.requestModel(rollModel)
	lib.requestAnimDict('move_weapon@jerrycan@generic')
	TaskPlayAnim(cache.ped, 'move_weapon@jerrycan@generic', 'idle', 5.0, 5.0, -1, 49, 1.0, false, false, false)
	local tempPos = GetEntityCoords(cache.ped)
	rollProp = CreateObject(rollModel, tempPos.x, tempPos.y, tempPos.z - 1.0, true, true, 0)
	AttachEntityToEntity(rollProp, cache.ped, GetPedBoneIndex(cache.ped, 28422), 0.16, 0, -0.07, -10.85, 0, 87.22, true, true, false, true, 1, true)
	SetModelAsNoLongerNeeded(rollModel)
	RemoveAnimDict('move_weapon@jerrycan@generic')
end

function DeleteStingerRoll()
	DeleteEntity(rollProp)
	if IsEntityPlayingAnim(cache.ped, 'move_weapon@jerrycan@generic', "idle", 3) then
		StopAnimTask(cache.ped, 'move_weapon@jerrycan@generic', "idle", 1.0)
	end
end

function PlaceSpikes()

	PlacingSpikes = true
	CreateThread(function()
		AttachStingerRoll()
		local spikesNum = 1
		lib.showTextUI(
					  ('Current Length: %s                            \n'):format(spikesNum) ..
		               --'-------------------------------         \n' ..
			           '[UP] - Increase Spikes Length            \n' ..
	                   '[DOWN] - Decrease Spikes Length                \n'
					  )
        while PlacingSpikes do

            DrawScaleformMovieFullscreen(form, 255, 255, 255, 255, 0)

            if IsControlJustPressed(0, 172) then	-- ARROW UP
				if spikesNum < 4 then
					spikesNum = spikesNum + 1
					lib.showTextUI(
						('Current Length: %s                            \n'):format(spikesNum) ..
						 --'-------------------------------         \n' ..
						 '[UP] - Increase Spikes Length            \n' ..
						 '[DOWN] - Decrease Spikes Length                \n'
						)
				end
            end
    
            if IsControlJustPressed(0, 173) then	-- ARROW DOWN
				if spikesNum > 1 then
					spikesNum = spikesNum - 1
					lib.showTextUI(
						('Current Length: %s                            \n'):format(spikesNum) ..
						 --'-------------------------------         \n' ..
						 '[UP] - Increase Spikes Length            \n' ..
						 '[DOWN] - Decrease Spikes Length                \n'
						)
				end
            end
            
            if IsControlJustPressed(0, 177) then		-- CANCEL
                PlacingSpikes = false
				DeleteStingerRoll()
            end

            if IsControlJustPressed(0, 38) then		-- E
                PlacingSpikes = false
				DeleteStingerRoll()
				GetSpikeLocations(spikesNum)
            end
            
            Wait(1)
        end
		lib.hideTextUI()

    end)


end

function GetMidpoint(coord1, coord2)
    if not (coord1 and coord2 and coord1.x and coord1.y and coord1.z and coord2.x and coord2.y and coord2.z) then
        print("Error: Invalid coordinates passed to GetMidpoint.")
        return nil
    end

	local midpoint = vec3(
        (coord1.x + coord2.x) / 2,
        (coord1.y + coord2.y) / 2,
        (coord1.z + coord2.z) / 2
	)

    return midpoint
end

function PickupStinger(id)
	
	if lib.progressBar({
		duration = 5000,
		label = 'Packing Stinger Spikes',
		useWhileDead = false,
		allowRagdoll = false,
		allowSwimming = false,
		allowCuffed = false,
		allowFalling = false, 
		canCancel = true,
		anim = {
			dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
			clip = 'machinic_loop_mechandplayer',
			flag = 33,
		}
	}) then
		local isOpen, text = lib.isTextUIOpen()
		if isOpen and text == '[E] Pick Up Stinger Spikes' then
			lib.hideTextUI()
		end
		TriggerServerEvent('spikes:server:pickup', id)
	else
		exports.qbx_core:Notify('Canceled')
	end

end

function CreateZone(id, data)
	
	startStinger = data[1].truePos
	endStinger = data[#data].truePos
	local highZ, lowZ = 0, 1000
	for _, stinger in pairs(data) do
		if stinger.truePos.z > highZ then highZ = stinger.truePos.z end
		if stinger.truePos.z < lowZ then lowZ = stinger.truePos.z end
	end
	local heightDiff = highZ - lowZ
	local MidPos = GetMidpoint(startStinger, endStinger)
	local length = 0
	if #data % 2 == 0 then
		length = (3.5 * #data) + 2.0
	else
		length = 3.5 + (3.5 * (#data - 1)) + 3.0
	end

	local zone = lib.zones.box({
		coords = vec3(MidPos.x, MidPos.y, MidPos.z + 1.0),
		size = vec3(2.0, length, heightDiff + 2.0),
		rotation = data[1].truePos.w,
		onEnter = function(coords)
			if not cache.vehicle then
				lib.showTextUI('[E] Pick Up Stinger Spikes')
			end
		end,
		onExit = function(coords)
			local isOpen, text = lib.isTextUIOpen()
			if isOpen and text == '[E] Pick Up Stinger Spikes' then
				lib.hideTextUI()
			end
		end,
		inside = function(coords)
			if IsControlJustReleased(0, 38) then    -- E
				PickupStinger(id)
			end
		end,
		--debug= true
	})

	spikes[id].zone = zone

end

function NewSpikes(id, coords)
	spikes[id] = {}
	local data = {}
	for i, pos in pairs(coords) do
		res = SpawnSpike(pos)
		res.coords = pos
		data[i] = res
	end
	spikes[id].data = data
	CreateZone(id, data)

end

exports('spikes', function(data, slot)
	local hasspike = lib.callback.await('spikes:server:hasspikes', false, slot.slot)
	if hasspike then
		PlaceSpikes()
	else
		exports.qbx_core:Notify('You Have No Stingers !')
	end	
end)

--  ____  ____ ___ _  _______ ____  
-- / ___||  _ \_ _| |/ / ____/ ___| 
-- \___ \| |_) | || ' /|  _| \___ \ 
--  ___) |  __/| || . \| |___ ___) |
-- |____/|_|  |___|_|\_\_____|____/ 

local nearbyCount = 0
local nearbySpikes = {}		
local stingersTick		
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
		local wheelTouching =  IsPointInAngledArea(
			boneCoords.x, boneCoords.y, boneCoords.z,
			minOffset.x, minOffset.y, minOffset.z,
			maxOffset.x, maxOffset.y, maxOffset.z,
			0.45, false, false
		)

		if wheelTouching then
			-- SetVehicleTyreBurst(vehicle, bone.index, wheelTouching, 1000.0)
			SetVehicleTyreBurst(vehicle, bone.index, false, 100.0)
		end

		::nextBone::
	end
end

function processStingers()
	local vehicle = cache.vehicle

	if not vehicle or (vehicle and config.immune[GetEntityModel(vehicle)]) then
		return
	end

	local vehicleCoords = vehicle and GetEntityCoords(vehicle)
	for id, s in pairs(nearbySpikes) do
		
		for _, data in pairs(s.data) do
			if vehicle and #(vehicleCoords - data.truePos.xyz) < 10.0 then
				if IsEntityTouchingEntity(data.handle, vehicle) then
					handleTouching(data.minOffset, data.maxOffset, vehicle)
				end

			end
		end
	end
end

CreateThread(function()
	while true do
		if nearbyCount ~= 0 then
			table.wipe(nearbySpikes)
			nearbyCount = 0
		end

		local coords = GetEntityCoords(cache.ped)

		for id, s in pairs(spikes) do
			local distance = #(coords - s.data[1].truePos.xyz)

			if distance > 100.0 then
				goto continue
			end

			nearbyCount += 1
			nearbySpikes[id] = s

			::continue::
		end

		if nearbyCount > 0 and cache.seat == -1 then
			if not stingersTick then
				stingersTick = SetInterval(processStingers)
			end
		elseif stingersTick then
			stingersTick = ClearInterval(stingersTick)
		end

		Wait(250)
	end
end)

--  _______     _______ _   _ _____ ____  
-- | ____\ \   / / ____| \ | |_   _/ ___| 
-- |  _|  \ \ / /|  _| |  \| | | | \___ \ 
-- | |___  \ V / | |___| |\  | | |  ___) |
-- |_____|  \_/  |_____|_| \_| |_| |____/ 
									
RegisterNetEvent('spikes:client:newspikes', function(id, coords)
	NewSpikes(id, coords)    
end)

RegisterNetEvent('spikes:client:delete', function(id)
	if spikes[id] then
		sdata = spikes[id]
		for _, s in pairs(sdata.data) do
			DeleteEntity(s.handle)	
		end
		sdata.zone:remove()
	end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
	Wait(2000)
    local data = lib.callback.await('spikes:server:data', false)
	if data ~= nil then
		for id, coords in pairs(data) do
			NewSpikes(id, coords)
		end
	end
end)

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() ~= resource then return end

	for _, sdata in pairs(spikes) do
		for _, s in pairs(sdata.data) do
			DeleteEntity(s.handle)	
		end
		sdata.zone:remove()
	end
	
end)