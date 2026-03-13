local QBCore = exports['qb-core']:GetCoreObject()

local playerJob = {}
local previewZone = nil
local previewBlip = nil
local activeZones     = {}   -- keyed by zoneId
local activeSpeedZones = {}  -- keyed by zoneId
local zoneBlips       = {}   -- keyed by zoneId, { radius=blip, center=blip }
local radiusValues = {}
local selectedRadiusIndex = 1
local slowSpeedValues = {}
local selectedSlowSpeedIndex = 1
local RESOURCE_NAME = GetCurrentResourceName()

local function debugLog(message)
	if not Config.Debug then return end
	print(('[%s][client] %s'):format(RESOURCE_NAME, tostring(message)))
end

local function debugZone(prefix, zone)
	if not Config.Debug then return end
	if not zone then
		debugLog(prefix .. ' zone=nil')
		return
	end

	local zoneType = zone.type or 'stop'
	local speedKmh = zone.speedKmh or 'nil'
	debugLog(('%s id=%s type=%s radius=%s speedKmh=%s coords=(%.2f, %.2f, %.2f)'):format(
		prefix,
		tostring(zone.id),
		tostring(zoneType),
		tostring(zone.radius),
		tostring(speedKmh),
		zone.coords.x or 0.0,
		zone.coords.y or 0.0,
		zone.coords.z or 0.0
	))
end

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function getZoneType(zone)
	local zoneType = zone and zone.type or 'stop'
	if zoneType ~= 'slow' then
		zoneType = 'stop'
	end
	return zoneType
end

local function getZoneSpeedMps(zone)
	local zoneType = getZoneType(zone)
	if zoneType == 'slow' then
		local speedKmh = tonumber(zone.speedKmh) or Config.Slow.Speed.Default
		speedKmh = clamp(speedKmh, Config.Slow.Speed.Min, Config.Slow.Speed.Max)
		return speedKmh / 3.6
	end

	return 0.0
end

local function getPreviewBlipColor(zoneType)
	if Config.Preview and Config.Preview.BlipColors then
		return Config.Preview.BlipColors[zoneType] or Config.Preview.BlipColors.stop or 1
	end

	return Config.Preview and Config.Preview.BlipColor or 1
end

local function getMinimapColor(zoneType)
	if Config.Minimap and Config.Minimap.Colors then
		return Config.Minimap.Colors[zoneType] or Config.Minimap.Colors.stop or 1
	end

	return Config.Minimap and Config.Minimap.Color or 1
end

local function getCenterColor(zoneType)
	if Config.Minimap and Config.Minimap.CenterColors then
		return Config.Minimap.CenterColors[zoneType] or Config.Minimap.CenterColors.stop or 1
	end

	return Config.Minimap and Config.Minimap.CenterColor or 1
end

local function getMinimapName(zoneType)
	if Config.Minimap and Config.Minimap.Names then
		return Config.Minimap.Names[zoneType] or Config.Minimap.Names.stop or 'Traffic Zone'
	end

	return Config.Minimap and Config.Minimap.Name or 'Traffic Zone'
end

local function notify(description, notifyType)
	lib.notify({
		description = description,
		type = notifyType or 'inform'
	})
end

local function getPed()
	return cache and cache.ped or PlayerPedId()
end

local function getCoords()
	return GetEntityCoords(getPed())
end

local function isAuthorizedJob(jobName)
	if not jobName then
		return false
	end

	if type(Config.Job) == 'string' then
		return string.lower(jobName) == string.lower(Config.Job)
	end

	for _, allowedJob in ipairs(Config.Job) do
		if string.lower(jobName) == string.lower(allowedJob) then
			return true
		end
	end

	return false
end

local function canViewZone()
	if not playerJob or not playerJob.name then
		return false
	end

	if not isAuthorizedJob(playerJob.name) then
		return false
	end

	if Config.RequireOnDuty and not playerJob.onduty then
		return false
	end

	return true
end

local function removePreviewBlip()
	if previewBlip then
		RemoveBlip(previewBlip)
		previewBlip = nil
	end
end

local function stopPreview()
	if previewZone then
		debugZone('Preview stopped for', previewZone)
	end
	previewZone = nil
	removePreviewBlip()
end

local function removeZoneBlip(zoneId)
	if not zoneBlips[zoneId] then return end
	if zoneBlips[zoneId].radius then RemoveBlip(zoneBlips[zoneId].radius) end
	if zoneBlips[zoneId].center then RemoveBlip(zoneBlips[zoneId].center) end
	zoneBlips[zoneId] = nil
end

local function removeAllBlips()
	for zoneId in pairs(zoneBlips) do
		removeZoneBlip(zoneId)
	end
end

local function addZoneBlip(zone)
	removeZoneBlip(zone.id)
	if not Config.Minimap.Enabled or not canViewZone() then return end
	local zoneType = getZoneType(zone)

	local blips = {}
	blips.radius = AddBlipForRadius(zone.coords.x, zone.coords.y, zone.coords.z, zone.radius + 0.0)
	SetBlipColour(blips.radius, getMinimapColor(zoneType))
	SetBlipAlpha(blips.radius, Config.Minimap.Alpha)

	if Config.Minimap.ShowCenter then
		blips.center = AddBlipForCoord(zone.coords.x, zone.coords.y, zone.coords.z)
		SetBlipSprite(blips.center, Config.Minimap.CenterSprite)
		SetBlipScale(blips.center, Config.Minimap.CenterScale)
		SetBlipColour(blips.center, getCenterColor(zoneType))
		SetBlipAsShortRange(blips.center, Config.Minimap.ShortRange)
		BeginTextCommandSetBlipName('STRING')
		AddTextComponentSubstringPlayerName(getMinimapName(zoneType))
		EndTextCommandSetBlipName(blips.center)
	end

	zoneBlips[zone.id] = blips
end

local function refreshAllBlips()
	removeAllBlips()
	if not Config.Minimap.Enabled or not canViewZone() then return end
	for _, zone in pairs(activeZones) do
		addZoneBlip(zone)
	end
end

local function removeActiveSpeedZone(zoneId)
	if activeSpeedZones[zoneId] then
		RemoveSpeedZone(activeSpeedZones[zoneId])
		activeSpeedZones[zoneId] = nil
	end
end

local function removeAllSpeedZones()
	for zoneId in pairs(activeSpeedZones) do
		removeActiveSpeedZone(zoneId)
	end
end

local function addActiveZone(zone)
	zone.type = getZoneType(zone)
	activeZones[zone.id] = zone
	removeActiveSpeedZone(zone.id)
	activeSpeedZones[zone.id] = AddSpeedZoneForCoord(
		zone.coords.x, zone.coords.y, zone.coords.z,
		zone.radius + 0.0, getZoneSpeedMps(zone) + 0.0, false
	)
	addZoneBlip(zone)
	debugZone('Active zone added', zone)
end

local function removeActiveZone(zoneId)
	if activeZones[zoneId] then
		debugZone('Active zone removed', activeZones[zoneId])
	else
		debugLog(('Active zone remove requested but not found id=%s'):format(tostring(zoneId)))
	end
	activeZones[zoneId] = nil
	removeActiveSpeedZone(zoneId)
	removeZoneBlip(zoneId)
end

local function clearAllZones()
	local count = 0
	for _ in pairs(activeZones) do count = count + 1 end
	debugLog(('Clearing all zones count=%s'):format(count))
	removeAllSpeedZones()
	removeAllBlips()
	activeZones = {}
end

local function getMarkerColor(zoneType)
	if zoneType == 'slow' then
		return { r = 255, g = 200, b = 0, a = 110 } -- jaune
	else
		return Config.Marker.Color or { r = 255, g = 70, b = 70, a = 110 } -- rouge par défaut
	end
end

local function drawZoneMarker(zone, color, forceType)
	local zoneType = forceType or (zone and zone.type) or 'stop'
	local markerColor = color or getMarkerColor(zoneType)
	DrawMarker(
		Config.Marker.Type,
		zone.coords.x,
		zone.coords.y,
		zone.coords.z - 1.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		0.0,
		zone.radius * 2.0,
		zone.radius * 2.0,
		Config.Marker.Height,
		markerColor.r,
		markerColor.g,
		markerColor.b,
		markerColor.a,
		Config.Marker.BobUpAndDown,
		Config.Marker.FaceCamera,
		2,
		false,
		nil,
		nil,
		false
	)
end

CreateThread(function()
	while true do
		local sleep = Config.Sleep

		if previewZone then
			sleep = 0
			drawZoneMarker(previewZone, nil, previewZone.type)
		end

		if Config.ShowActiveZoneMarker and next(activeZones) then
			sleep = 0
			for _, zone in pairs(activeZones) do
				drawZoneMarker(zone, nil, zone.type)
			end
		end

		Wait(sleep)
	end
end)

local function startPreview(radius, zoneType)
	stopPreview()

	local coords = getCoords()
	zoneType = zoneType == 'slow' and 'slow' or 'stop'
	previewZone = {
		coords = vec3(coords.x, coords.y, coords.z),
		radius = radius,
		type = zoneType
	}

	previewBlip = AddBlipForRadius(previewZone.coords.x, previewZone.coords.y, previewZone.coords.z, radius + 0.0)
	SetBlipColour(previewBlip, getPreviewBlipColor(zoneType))
	SetBlipAlpha(previewBlip, Config.Preview.BlipAlpha)
	debugZone('Preview started', previewZone)
end

local function buildRadiusValues()
	radiusValues = {}

	local step = math.max(1, tonumber(Config.Radius.Step) or 1)
	for radius = Config.Radius.Min, Config.Radius.Max, step do
		radiusValues[#radiusValues + 1] = tostring(radius)
	end

	if tonumber(radiusValues[#radiusValues]) ~= Config.Radius.Max then
		radiusValues[#radiusValues + 1] = tostring(Config.Radius.Max)
	end

	selectedRadiusIndex = 1
	for index, value in ipairs(radiusValues) do
		if tonumber(value) == Config.Radius.Default then
			selectedRadiusIndex = index
			break
		end
	end
end

local function getSelectedRadius(scrollIndex)
	local value = radiusValues[scrollIndex or selectedRadiusIndex]
	return tonumber(value) or Config.Radius.Default
end

local function updatePreviewFromIndex(scrollIndex)
	selectedRadiusIndex = scrollIndex or selectedRadiusIndex
	startPreview(getSelectedRadius(selectedRadiusIndex), 'stop')
end

local function buildSlowSpeedValues()
	slowSpeedValues = {}

	local minSpeed = tonumber(Config.Slow.Speed.Min) or 5
	local maxSpeed = tonumber(Config.Slow.Speed.Max) or 120
	local step = math.max(1, tonumber(Config.Slow.Speed.Step) or 5)

	for speed = minSpeed, maxSpeed, step do
		slowSpeedValues[#slowSpeedValues + 1] = tostring(speed)
	end

	if tonumber(slowSpeedValues[#slowSpeedValues]) ~= maxSpeed then
		slowSpeedValues[#slowSpeedValues + 1] = tostring(maxSpeed)
	end

	selectedSlowSpeedIndex = 1
	for index, value in ipairs(slowSpeedValues) do
		if tonumber(value) == tonumber(Config.Slow.Speed.Default) then
			selectedSlowSpeedIndex = index
			break
		end
	end
end

local function getSelectedSlowSpeed(scrollIndex)
	local value = slowSpeedValues[scrollIndex or selectedSlowSpeedIndex]
	return tonumber(value) or Config.Slow.Speed.Default
end

local function updateSlowPreviewFromIndex(scrollIndex)
	selectedRadiusIndex = scrollIndex or selectedRadiusIndex
	startPreview(getSelectedRadius(selectedRadiusIndex), 'slow')
end

local function registerStopTrafficMenu()
	debugLog('Opening stoptraffic menu')
	lib.registerMenu({
		id = 'pc_stoptraffic_menu',
		title = Config.Local.MenuTitle,
		position = Config.PositionMenu,
		onClose = function()
			stopPreview()
		end,
		onSideScroll = function(selected, scrollIndex)
			if selected == 1 then
				updatePreviewFromIndex(scrollIndex)
			end
		end,
		options = {
			{
				label = Config.Local.RadiusLabel,
				description = Config.Local.RadiusDescription,
				values = radiusValues,
				defaultIndex = selectedRadiusIndex,
				icon = 'ruler-combined'
			}
		}
	}, function(selected, secondary)
		if selected == 1 then
			if secondary then
				updatePreviewFromIndex(secondary)
			end

			if previewZone then
				debugZone('Submitting stop zone', previewZone)
				lib.hideMenu(true)
				TriggerServerEvent('pc-stoptraffic:server:createZone', {
					radius = previewZone.radius,
					type = 'stop'
				})
				stopPreview()
			end
		end
	end)
end

local function registerSlowTrafficMenu()
	local function submitSlowZone()
		local radius = getSelectedRadius(selectedRadiusIndex)
		local speedKmh = getSelectedSlowSpeed(selectedSlowSpeedIndex)
		debugLog(('Submitting slow zone radius=%s speedKmh=%s'):format(tostring(radius), tostring(speedKmh)))

		lib.hideMenu(true)
		TriggerServerEvent('pc-stoptraffic:server:createZone', {
			radius = radius,
			type = 'slow',
			speedKmh = speedKmh
		})
		stopPreview()
	end

	debugLog('Opening slowtraffic menu')
	lib.registerMenu({
		id = 'pc_slowtraffic_menu',
		title = Config.Local.SlowMenuTitle,
		position = Config.PositionMenu,
		onClose = function()
			stopPreview()
		end,
		onSideScroll = function(selected, scrollIndex)
			if selected == 1 then
				updateSlowPreviewFromIndex(scrollIndex)
			elseif selected == 2 then
				selectedSlowSpeedIndex = scrollIndex or selectedSlowSpeedIndex
			end
		end,
		options = {
			{
				label = Config.Local.RadiusLabel,
				description = Config.Local.RadiusDescription,
				values = radiusValues,
				defaultIndex = selectedRadiusIndex,
				icon = 'ruler-combined'
			},
			{
				label = Config.Local.SpeedLabel,
				description = Config.Local.SpeedDescription,
				values = slowSpeedValues,
				defaultIndex = selectedSlowSpeedIndex,
				icon = 'gauge-high'
			}
		}
	}, function(selected, secondary)
		if selected == 1 then
			if secondary then
				updateSlowPreviewFromIndex(secondary)
			end
			submitSlowZone()
		elseif selected == 2 then
			if secondary then
				selectedSlowSpeedIndex = secondary
			end
			submitSlowZone()
		end
	end)
end

local function setPlayerJob(job)
	playerJob = job or {}
	debugLog(('Player job updated name=%s onduty=%s'):format(
		tostring(playerJob.name),
		tostring(playerJob.onduty)
	))
	refreshAllBlips()
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
	local playerData = QBCore.Functions.GetPlayerData()
	setPlayerJob(playerData.job)
	TriggerServerEvent('pc-stoptraffic:server:requestState')
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
	setPlayerJob({})
	clearAllZones()
	stopPreview()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
	setPlayerJob(job)
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(onDuty)
	if playerJob then
		playerJob.onduty = onDuty
	end
	refreshAllBlips()
end)

RegisterNetEvent('pc-stoptraffic:client:syncAllZones', function(zones)
	clearAllZones()
	if not zones then return end
	local count = 0
	for _, zone in pairs(zones) do
		count = count + 1
		zone.coords = vec3(zone.coords.x, zone.coords.y, zone.coords.z)
		addActiveZone(zone)
	end
	debugLog(('Sync received zones=%s'):format(count))
end)

RegisterNetEvent('pc-stoptraffic:client:addZone', function(zone)
	zone.coords = vec3(zone.coords.x, zone.coords.y, zone.coords.z)
	addActiveZone(zone)
end)

RegisterNetEvent('pc-stoptraffic:client:removeZone', function(zoneId)
	debugLog(('Server requested zone removal id=%s'):format(tostring(zoneId)))
	removeActiveZone(zoneId)
end)

RegisterNetEvent('pc-stoptraffic:client:openMenu', function()
	debugLog('Event open stoptraffic menu')
	buildRadiusValues()
	registerStopTrafficMenu()
	updatePreviewFromIndex(selectedRadiusIndex)
	lib.showMenu('pc_stoptraffic_menu', selectedRadiusIndex)
end)

RegisterNetEvent('pc-stoptraffic:client:openSlowMenu', function()
	debugLog('Event open slowtraffic menu')
	buildRadiusValues()
	buildSlowSpeedValues()
	registerSlowTrafficMenu()
	updateSlowPreviewFromIndex(selectedRadiusIndex)
	lib.showMenu('pc_slowtraffic_menu', selectedRadiusIndex)
end)

RegisterNetEvent('pc-stoptraffic:client:removeZonePrompt', function()
	debugLog('Remove zone prompt triggered by command')
	TriggerServerEvent('pc-stoptraffic:server:removeZoneAttempt')
end)

RegisterNetEvent('pc-stoptraffic:client:notify', function(message, notifyType)
	debugLog(('Notify type=%s message=%s'):format(tostring(notifyType), tostring(message)))
	notify(message, notifyType)
end)

AddEventHandler('onClientResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	debugLog('Resource started, requesting state from server')

	local playerData = QBCore.Functions.GetPlayerData()
	setPlayerJob(playerData.job)
	TriggerServerEvent('pc-stoptraffic:server:requestState')
end)

AddEventHandler('onClientResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then
		return
	end

	debugLog('Resource stopping, clearing client state')

	stopPreview()
	removeAllBlips()
	removeAllSpeedZones()
end)
