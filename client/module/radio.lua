local DrawablesListMale = { -- male drawable numbers that have Mic Shoulder
    ["Kevlar"] = {  --VEST
        [5] = true, 
        [7] = true,
		[25] = true, 
        [26] = true,
		[28] = true, 
        [39] = true,
		[49] = true, 
    },
    ["Undershirt"] = {
        [73] = true,
		[168] = true,
        [73] = true,
    },
    ["Parachute"] = { --Bags
        [31] = true,
    },
}

local DrawablesListFemale = {  -- female drawable numbers that have Mic Shoulder
    ["Kevlar"] = { --VEST
        [1] = true,
        [2] = true,
        [30] = true,
        [42] = true,
        [43] = true,
    },
    ["Undershirt"] = {
        [147] = true,
        [301] = true,
    },
}

local RadioModel = `prop_cs_hand_radio`
local RadioProp = 0
local function deleteRadio()
    if RadioProp ~= 0 then
        Citizen.InvokeNative(0xAE3CBE5BF394C9C9 , Citizen.PointerValueIntInitialized(RadioProp))
        RadioProp = 0
    end
end

local function newRadio()
    deleteRadio()
    RequestModel(RadioModel)
    while not HasModelLoaded(RadioModel) do
        Citizen.Wait(1)
    end
    RadioProp = CreateObject(RadioModel, 1.0, 1.0, 1.0, 1, 1, 0)

    local bone = GetPedBoneIndex(PlayerPedId(), 60309)
    AttachEntityToEntity(RadioProp, PlayerPedId(), bone, 0.0750, 0.0470, 0.0110, -97.9442, 3.7058, -23.2367, 1, 0, 0, 0, 2, 1)
end


local radioChannel = 0
local radioNames = {}
local disableRadioAnim = false

--- event syncRadioData
--- syncs the current players on the radio to the client
---@param radioTable table the table of the current players on the radio
---@param localPlyRadioName string the local players name
function syncRadioData(radioTable, localPlyRadioName)
	radioData = radioTable
	logger.info('[radio] Syncing radio table.')
	if GetConvarInt('voice_debugMode', 0) >= 4 then
		print('-------- RADIO TABLE --------')
		tPrint(radioData)
		print('-----------------------------')
	end
	for tgt, enabled in pairs(radioTable) do
		if tgt ~= playerServerId then
			toggleVoice(tgt, enabled, 'radio')
		end
	end
	sendUIMessage({
		radioChannel = radioChannel,
		radioEnabled = radioEnabled
	})
	if GetConvarInt("voice_syncPlayerNames", 0) == 1 then
		radioNames[playerServerId] = localPlyRadioName
	end
end
RegisterNetEvent('A7-voice:syncRadioData', syncRadioData)

--- event setTalkingOnRadio
--- sets the players talking status, triggered when a player starts/stops talking.
---@param plySource number the players server id.
---@param enabled boolean whether the player is talking or not.
function setTalkingOnRadio(plySource, enabled)
	toggleVoice(plySource, enabled, 'radio')
	radioData[plySource] = enabled
	playMicClicks(enabled)
end
RegisterNetEvent('A7-voice:setTalkingOnRadio', setTalkingOnRadio)

--- event addPlayerToRadio
--- adds a player onto the radio.
---@param plySource number the players server id to add to the radio.
function addPlayerToRadio(plySource, plyRadioName)
	radioData[plySource] = false
	if GetConvarInt("voice_syncPlayerNames", 0) == 1 then
		radioNames[plySource] = plyRadioName
	end
	if radioPressed then
		logger.info('[radio] %s joined radio %s while we were talking, adding them to targets', plySource, radioChannel)
		playerTargets(radioData, MumbleIsPlayerTalking(PlayerId()) and callData or {})
	else
		logger.info('[radio] %s joined radio %s', plySource, radioChannel)
	end
end
RegisterNetEvent('A7-voice:addPlayerToRadio', addPlayerToRadio)

--- event removePlayerFromRadio
--- removes the player (or self) from the radio
---@param plySource number the players server id to remove from the radio.
function removePlayerFromRadio(plySource)
	if plySource == playerServerId then
		logger.info('[radio] Left radio %s, cleaning up.', radioChannel)
		for tgt, _ in pairs(radioData) do
			if tgt ~= playerServerId then
				toggleVoice(tgt, false, 'radio')
			end
		end
		sendUIMessage({
			radioChannel = 0,
			radioEnabled = radioEnabled
		})
		radioNames = {}
		radioData = {}
		playerTargets(MumbleIsPlayerTalking(PlayerId()) and callData or {})
	else
		toggleVoice(plySource, false)
		if radioPressed then
			logger.info('[radio] %s left radio %s while we were talking, updating targets.', plySource, radioChannel)
			playerTargets(radioData, MumbleIsPlayerTalking(PlayerId()) and callData or {})
		else
			logger.info('[radio] %s has left radio %s', plySource, radioChannel)
		end
		radioData[plySource] = nil
		if GetConvarInt("voice_syncPlayerNames", 0) == 1 then
			radioNames[plySource] = nil
		end
	end
end
RegisterNetEvent('A7-voice:removePlayerFromRadio', removePlayerFromRadio)

--- function setRadioChannel
--- sets the local players current radio channel and updates the server
---@param channel number the channel to set the player to, or 0 to remove them.
function setRadioChannel(channel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	type_check({channel, "number"})
	TriggerServerEvent('A7-voice:setPlayerRadio', channel)
	radioChannel = channel
end

--- exports setRadioChannel
--- sets the local players current radio channel and updates the server
---@param channel number the channel to set the player to, or 0 to remove them.
exports('setRadioChannel', setRadioChannel)
-- mumble-voip compatability
exports('SetRadioChannel', setRadioChannel)

--- exports removePlayerFromRadio
--- sets the local players current radio channel and updates the server
exports('removePlayerFromRadio', function()
	setRadioChannel(0)
end)

--- exports addPlayerToRadio
--- sets the local players current radio channel and updates the server
---@param _radio number the channel to set the player to, or 0 to remove them.
exports('addPlayerToRadio', function(_radio)
	local radio = tonumber(_radio)
	if radio then
		setRadioChannel(radio)
	end
end)

--- exports toggleRadioAnim
--- toggles whether the client should play radio anim or not, if the animation should be played or notvaliddance
exports('toggleRadioAnim', function()
	disableRadioAnim = not disableRadioAnim
	TriggerEvent('A7-voice:toggleRadioAnim', disableRadioAnim)
end)

-- exports disableRadioAnim
--- returns whether the client is undercover or not
exports('getRadioAnimState', function()
	return disableRadioAnim
end)

--- check if the player is dead
--- seperating this so if people use different methods they can customize
--- it to their need as this will likely never be changed
--- but you can integrate the below state bag to your death resources.
--- LocalPlayer.state:set('isDead', true or false, false)
function isDead()
	if LocalPlayer.state.isDead then
		return true
	elseif IsPlayerDead(PlayerId()) then
		return true
	end
end
RegisterCommand('+radiotalk', function()
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	if isDead() or LocalPlayer.state.disableRadio then return end

	if not radioPressed and radioEnabled then
		if radioChannel > 0 then
			logger.info('[radio] Start broadcasting, update targets and notify server.')
			playerTargets(radioData, MumbleIsPlayerTalking(PlayerId()) and callData or {})
			TriggerServerEvent('A7-voice:setTalkingOnRadio', true)
			radioPressed = true
			playMicClicks(true)
			if GetConvarInt('voice_enableRadioAnim', 0) == 1 and not (GetConvarInt('voice_disableVehicleRadioAnim', 0) == 1 and IsPedInAnyVehicle(PlayerPedId(), false)) and not disableRadioAnim then
                local model = GetEntityModel(PlayerPedId())
				if model == `mp_f_freemode_01` then
					local FemaleHasRadio = false
					if DrawablesListFemale["Undershirt"][GetPedDrawableVariation(PlayerPedId(), 8)] or DrawablesListFemale["Kevlar"][GetPedDrawableVariation(PlayerPedId(), 9)] then
						FemaleHasRadio = true
					end
					if FemaleHasRadio then 
						RequestAnimDict('random@arrests')
						while not HasAnimDictLoaded('random@arrests') do
							Citizen.Wait(10)
						end
						TaskPlayAnim(PlayerPedId(), "random@arrests", "generic_radio_enter", 8.0, 2.0, -1, 50, 2.0, 0, 0, 0)
					else
						RequestAnimDict('anim@radio_pose_3')
						while not HasAnimDictLoaded('anim@radio_pose_3') do
							Citizen.Wait(10)
						end
						newRadio()
						TaskPlayAnim(PlayerPedId(), 'anim@radio_pose_3', 'radio_holding_gun', 8.0, 2.0, -1, 50, 2.0, 0, 0, 0)
					end
				elseif model == `mp_m_freemode_01` then
					local MaleHasRadio = false
					if DrawablesListMale["Undershirt"][GetPedDrawableVariation(PlayerPedId(), 8)] or DrawablesListMale["Kevlar"][GetPedDrawableVariation(PlayerPedId(), 9)] or DrawablesListMale["Parachute"][GetPedDrawableVariation(PlayerPedId(), 5)] then
						MaleHasRadio = true
					end
					if MaleHasRadio then 
						RequestAnimDict('random@arrests')
						while not HasAnimDictLoaded('random@arrests') do
							Citizen.Wait(10)
						end
						TaskPlayAnim(PlayerPedId(), "random@arrests", "generic_radio_enter", 8.0, 2.0, -1, 50, 2.0, 0, 0, 0)
					else
						RequestAnimDict('anim@radio_pose_3')
						while not HasAnimDictLoaded('anim@radio_pose_3') do
							Citizen.Wait(10)
						end
						newRadio()
						TaskPlayAnim(PlayerPedId(), 'anim@radio_pose_3', 'radio_holding_gun', 8.0, 2.0, -1, 50, 2.0, 0, 0, 0)
					end
				else
					RequestAnimDict('anim@radio_pose_3')
					while not HasAnimDictLoaded('anim@radio_pose_3') do
						Citizen.Wait(10)
					end
					newRadio()
					TaskPlayAnim(PlayerPedId(), 'anim@radio_pose_3', 'radio_holding_gun', 8.0, 2.0, -1, 50, 2.0, 0, 0, 0)
				end
			end
			CreateThread(function()
				TriggerEvent("A7-voice:radioActive", true)
				while radioPressed and not LocalPlayer.state.disableRadio do
					Wait(0)
					SetControlNormal(0, 249, 1.0)
					SetControlNormal(1, 249, 1.0)
					SetControlNormal(2, 249, 1.0)
				end
			end)
		end
	end
end, false)

RegisterCommand('-radiotalk', function()
	if (radioChannel > 0 or radioEnabled) and radioPressed then
		radioPressed = false
		MumbleClearVoiceTargetPlayers(voiceTarget)
		playerTargets(MumbleIsPlayerTalking(PlayerId()) and callData or {})
		TriggerEvent("A7-voice:radioActive", false)
		playMicClicks(false)
		if GetConvarInt('voice_enableRadioAnim', 0) == 1 then
			local model = GetEntityModel(PlayerPedId())
			if model == `mp_f_freemode_01` then
				local FemaleHasRadio = false
				if DrawablesListFemale["Undershirt"][GetPedDrawableVariation(PlayerPedId(), 8)] or DrawablesListFemale["Kevlar"][GetPedDrawableVariation(PlayerPedId(), 9)] then
					FemaleHasRadio = true
				end
				if FemaleHasRadio then 
					StopAnimTask(PlayerPedId(), "random@arrests", "generic_radio_enter", -4.0)
				else
					deleteRadio()
					StopAnimTask(PlayerPedId(), 'anim@radio_pose_3', 'radio_holding_gun', -4.0)
				end
			elseif model == `mp_m_freemode_01` then
				local MaleHasRadio = false
				if DrawablesListMale["Undershirt"][GetPedDrawableVariation(PlayerPedId(), 8)] or DrawablesListMale["Kevlar"][GetPedDrawableVariation(PlayerPedId(), 9)] or DrawablesListMale["Parachute"][GetPedDrawableVariation(PlayerPedId(), 5)] then
					MaleHasRadio = true
				end
				if MaleHasRadio then 
					StopAnimTask(PlayerPedId(), "random@arrests", "generic_radio_enter", -4.0)
				else
					deleteRadio()
					StopAnimTask(PlayerPedId(), 'anim@radio_pose_3', 'radio_holding_gun', -4.0)
				end
			else
				deleteRadio()
				StopAnimTask(PlayerPedId(), 'anim@radio_pose_3', 'radio_holding_gun', -4.0)
			end
		end
		TriggerServerEvent('A7-voice:setTalkingOnRadio', false)
	end
end, false)
if gameVersion == 'fivem' then
	RegisterKeyMapping('+radiotalk', 'Talk over Radio', 'keyboard', GetConvar('voice_defaultRadio', 'LMENU'))
end


--- event syncRadio
--- syncs the players radio, only happens if the radio was set server side.
---@param _radioChannel number the radio channel to set the player to.
function syncRadio(_radioChannel)
	if GetConvarInt('voice_enableRadios', 1) ~= 1 then return end
	logger.info('[radio] radio set serverside update to radio %s', radioChannel)
	radioChannel = _radioChannel
end
RegisterNetEvent('A7-voice:clSetPlayerRadio', syncRadio)
