local QBCore = exports['qb-core']:GetCoreObject()

local activeZones = {}
local nextZoneId  = 1
local RESOURCE_NAME = GetCurrentResourceName()

local function debugLog(message)
	if not Config.Debug then return end
	print(('[%s][server] %s'):format(RESOURCE_NAME, tostring(message)))
end

local function debugZone(prefix, zone)
	if not Config.Debug then return end
	if not zone then
		debugLog(prefix .. ' zone=nil')
		return
	end

	local zoneType = zone.type or 'stop'
	local speedKmh = zone.speedKmh or 'nil'
	debugLog(('%s id=%s type=%s radius=%s speedKmh=%s by=%s coords=(%.2f, %.2f, %.2f)'):format(
		prefix,
		tostring(zone.id),
		tostring(zoneType),
		tostring(zone.radius),
		tostring(speedKmh),
		tostring(zone.createdBy),
		zone.coords.x or 0.0,
		zone.coords.y or 0.0,
		zone.coords.z or 0.0
	))
end

local function wl(key, fallback)
	local webhookLocal = Config.Local and Config.Local.Webhook
	if webhookLocal and webhookLocal[key] ~= nil then
		return webhookLocal[key]
	end
	return fallback
end

local function clamp(value, minValue, maxValue)
	return math.max(minValue, math.min(maxValue, value))
end

local function getAllowedJobs()
	local jobs = {}

	if type(Config.Job) == 'string' then
		jobs[string.lower(Config.Job)] = true
		return jobs
	end

	for _, jobName in ipairs(Config.Job) do
		jobs[string.lower(jobName)] = true
	end

	return jobs
end

local allowedJobs = getAllowedJobs()

local function getPlayer(source)
	return QBCore.Functions.GetPlayer(source)
end

local function getPlayerIdentifierByPrefix(source, prefix)
	for _, identifier in ipairs(GetPlayerIdentifiers(source)) do
		if identifier:sub(1, #prefix) == prefix then
			return identifier
		end
	end
	return nil
end

local function getPlayerWebhookInfo(source, player)
	local playerData = player and player.PlayerData or {}
	local charinfo = playerData.charinfo or {}
	local job = playerData.job or {}

	local unknown = wl('Unknown', 'Unknown')
	local notAvailable = wl('NotAvailable', 'N/A')

	local firstname = charinfo.firstname or unknown
	local lastname = charinfo.lastname or unknown
	local fullName = (firstname .. ' ' .. lastname)

	return {
		source = source,
		serverName = GetPlayerName(source) or unknown,
		fullName = fullName,
		firstname = firstname,
		lastname = lastname,
		citizenid = playerData.citizenid or unknown,
		job = job.name or unknown,
		onduty = job.onduty,
		license = getPlayerIdentifierByPrefix(source, 'license:') or notAvailable,
		discord = getPlayerIdentifierByPrefix(source, 'discord:') or notAvailable
	}
end

local function sendWebhookEmbed(actionTitle, description, color, fields)
	if not Config.Webhook or not Config.Webhook.Enabled then return end
	if not Config.Webhook.Url or Config.Webhook.Url == '' then
		debugLog('Webhook enabled but Url is empty')
		return
	end

	local payload = {
		username = Config.Webhook.Username or RESOURCE_NAME,
		embeds = {
			{
				title = actionTitle,
				description = description,
				color = color or 16777215,
				fields = fields or {},
				footer = {
					text = (wl('FooterFormat', '%s • %s')):format(RESOURCE_NAME, os.date('%Y-%m-%d %H:%M:%S'))
				}
			}
		}
	}

	if Config.Webhook.AvatarUrl and Config.Webhook.AvatarUrl ~= '' then
		payload.avatar_url = Config.Webhook.AvatarUrl
	end

	PerformHttpRequest(Config.Webhook.Url, function(statusCode)
		debugLog(('Webhook sent status=%s title=%s'):format(tostring(statusCode), tostring(actionTitle)))
	end, 'POST', json.encode(payload), { ['Content-Type'] = 'application/json' })
end

local function buildZoneFields(actor, zone, includePosition)
	local zoneTypeValue = tostring(zone.type or wl('ValueZoneTypeStop', 'stop'))
	local speedValue = zone.type == 'slow'
		and (wl('ValueSpeedFormat', '%s km/h')):format(tostring(zone.speedKmh or wl('NotAvailable', 'N/A')))
		or wl('ValueSpeedStop', '0 km/h')

	local fields = {
		{ name = wl('FieldServerId', 'Server ID'), value = tostring(actor.source), inline = true },
		{ name = wl('FieldRpName', 'RP Name'), value = actor.fullName, inline = true },
		{ name = wl('FieldSessionName', 'Session Name'), value = actor.serverName, inline = true },
		{ name = wl('FieldCitizenId', 'CitizenID'), value = actor.citizenid, inline = true },
		{ name = wl('FieldJob', 'Job'), value = (wl('ValueJobFormat', '%s (onduty: %s)')):format(actor.job, tostring(actor.onduty)), inline = true },
		{ name = wl('FieldZoneType', 'Zone Type'), value = zoneTypeValue, inline = true },
		{ name = wl('FieldRadius', 'Radius'), value = (wl('ValueRadiusFormat', '%sm')):format(tostring(zone.radius or wl('NotAvailable', 'N/A'))), inline = true },
		{ name = wl('FieldSpeed', 'Speed'), value = speedValue, inline = true },
		{ name = wl('FieldZoneId', 'Zone ID'), value = tostring(zone.id or wl('NotAvailable', 'N/A')), inline = true },
		{ name = wl('FieldLicense', 'License'), value = actor.license, inline = false },
		{ name = wl('FieldDiscordId', 'Discord ID'), value = actor.discord, inline = false }
	}

	if includePosition and zone.coords then
		fields[#fields + 1] = {
			name = wl('FieldPosition', 'Position'),
			value = (wl('ValuePositionFormat', 'x: %.2f y: %.2f z: %.2f')):format(zone.coords.x or 0.0, zone.coords.y or 0.0, zone.coords.z or 0.0),
			inline = false
		}
	end

	return fields
end

local function sendZoneWebhook(action, player, zone)
	local actor = getPlayerWebhookInfo(zone.createdBy or 0, player)
	local fields = buildZoneFields(actor, zone, Config.Webhook and Config.Webhook.IncludePosition)

	if action == 'stop_create' then
		sendWebhookEmbed(
			wl('TitleStopCreated', 'Stop Traffic created'),
			(wl('DescriptionStopCreated', 'A stop traffic zone was created by %s.')):format(actor.fullName),
			Config.Webhook and Config.Webhook.Colors and Config.Webhook.Colors.StopCreated,
			fields
		)
	elseif action == 'slow_create' then
		sendWebhookEmbed(
			wl('TitleSlowCreated', 'Slow Traffic created'),
			(wl('DescriptionSlowCreated', 'A slow traffic zone was created by %s.')):format(actor.fullName),
			Config.Webhook and Config.Webhook.Colors and Config.Webhook.Colors.SlowCreated,
			fields
		)
	elseif action == 'zone_remove' then
		sendWebhookEmbed(
			wl('TitleZoneRemoved', 'Traffic zone removed'),
			(wl('DescriptionZoneRemoved', '%s removed a traffic zone.')):format(actor.fullName),
			Config.Webhook and Config.Webhook.Colors and Config.Webhook.Colors.ZoneRemoved,
			fields
		)
	end
end

local function getPlayerCoords(source)
	local ped = GetPlayerPed(source)
	if not ped or ped == 0 then
		return nil
	end

	local coords = GetEntityCoords(ped)
	return {
		x = coords.x + 0.0,
		y = coords.y + 0.0,
		z = coords.z + 0.0
	}
end

local function isAuthorized(player)
	if not player then
		debugLog('Authorization failed: player=nil')
		return false, Config.Local.NotAuthorized
	end

	local job = player.PlayerData and player.PlayerData.job
	if not job or not job.name or not allowedJobs[string.lower(job.name)] then
		debugLog(('Authorization failed: invalid job=%s'):format(job and tostring(job.name) or 'nil'))
		return false, Config.Local.NotAuthorized
	end

	if Config.RequireOnDuty and not job.onduty then
		debugLog(('Authorization failed: off duty job=%s'):format(tostring(job.name)))
		return false, Config.Local.MustBeOnDuty
	end

	debugLog(('Authorization ok: job=%s onduty=%s'):format(tostring(job.name), tostring(job.onduty)))

	return true
end

local function sendNotification(target, message, notifyType)
	TriggerClientEvent('pc-stoptraffic:client:notify', target, message, notifyType)
end

local function broadcastAddZone(zone)
	TriggerClientEvent('pc-stoptraffic:client:addZone', -1, zone)
end

local function broadcastRemoveZone(zoneId)
	TriggerClientEvent('pc-stoptraffic:client:removeZone', -1, zoneId)
end

local function isInsideZone(coords, zone)
	if not zone then return false end
	local dx = coords.x - zone.coords.x
	local dy = coords.y - zone.coords.y
	return math.sqrt(dx * dx + dy * dy) <= zone.radius
end

RegisterCommand(Config.Commands.Open, function(source)
	debugLog(('Command /%s from source=%s'):format(Config.Commands.Open, tostring(source)))
	if source == 0 then
		print(('[%s] This command cannot be used from the server console.'):format(GetCurrentResourceName()))
		return
	end

	local player = getPlayer(source)
	local authorized, reason = isAuthorized(player)
	if not authorized then
		sendNotification(source, reason, 'error')
		return
	end

	TriggerClientEvent('pc-stoptraffic:client:openMenu', source)
end, false)

RegisterCommand(Config.Commands.SlowOpen, function(source)
	debugLog(('Command /%s from source=%s'):format(Config.Commands.SlowOpen, tostring(source)))
	if source == 0 then
		print(('[%s] This command cannot be used from the server console.'):format(GetCurrentResourceName()))
		return
	end

	local player = getPlayer(source)
	local authorized, reason = isAuthorized(player)
	if not authorized then
		sendNotification(source, reason, 'error')
		return
	end

	TriggerClientEvent('pc-stoptraffic:client:openSlowMenu', source)
end, false)

RegisterCommand(Config.Commands.Remove, function(source)
	debugLog(('Command /%s from source=%s'):format(Config.Commands.Remove, tostring(source)))
	if source == 0 then
		print(('[%s] This command cannot be used from the server console.'):format(GetCurrentResourceName()))
		return
	end

	local player = getPlayer(source)
	local authorized, reason = isAuthorized(player)
	if not authorized then
		sendNotification(source, reason, 'error')
		return
	end

	TriggerClientEvent('pc-stoptraffic:client:removeZonePrompt', source)
end, false)

RegisterNetEvent('pc-stoptraffic:server:requestState', function()
	local count = 0
	for _ in pairs(activeZones) do count = count + 1 end
	debugLog(('State requested by source=%s zones=%s'):format(tostring(source), tostring(count)))
	TriggerClientEvent('pc-stoptraffic:client:syncAllZones', source, activeZones)
end)

RegisterNetEvent('pc-stoptraffic:server:createZone', function(zoneData)
	local source = source
	debugLog(('CreateZone event from source=%s'):format(tostring(source)))
	local player = getPlayer(source)
	local authorized, reason = isAuthorized(player)
	if not authorized then
		sendNotification(source, reason, 'error')
		return
	end

	if not zoneData then
		debugLog('CreateZone aborted: zoneData=nil')
		return
	end

	local coords = getPlayerCoords(source)
	if not coords then
		debugLog(('CreateZone aborted: no coords for source=%s'):format(tostring(source)))
		return
	end

	local radius = tonumber(zoneData.radius) or Config.Radius.Default
	radius = clamp(radius, Config.Radius.Min, Config.Radius.Max)

	local zoneType = zoneData.type
	local speedKmh = nil
	if zoneType == 'slow' then
		speedKmh = tonumber(zoneData.speedKmh) or Config.Slow.Speed.Default
		speedKmh = clamp(speedKmh, Config.Slow.Speed.Min, Config.Slow.Speed.Max)
	else
		zoneType = 'stop'
	end

	local zoneId = tostring(nextZoneId)
	nextZoneId = nextZoneId + 1

	local zone = {
		id = zoneId,
		coords = coords,
		radius = radius,
		type = zoneType,
		speedKmh = speedKmh,
		createdBy = source,
		createdAt = os.time()
	}

	activeZones[zoneId] = zone
	debugZone('Zone created', zone)
	broadcastAddZone(zone)
	if zoneType == 'slow' then
		sendNotification(source, Config.Local.SlowZoneCreated, 'success')
		sendZoneWebhook('slow_create', player, zone)
	else
		sendNotification(source, Config.Local.ZoneCreated, 'success')
		sendZoneWebhook('stop_create', player, zone)
	end
end)

RegisterNetEvent('pc-stoptraffic:server:removeZoneAttempt', function()
	local source = source
	debugLog(('RemoveZoneAttempt from source=%s'):format(tostring(source)))
	local player = getPlayer(source)
	local authorized, reason = isAuthorized(player)
	if not authorized then
		sendNotification(source, reason, 'error')
		return
	end

	local coords = getPlayerCoords(source)
	if not coords then return end

	local foundId = nil
	local closestDist = math.huge

	for zoneId, zone in pairs(activeZones) do
		if isInsideZone(coords, zone) then
			local dx = coords.x - zone.coords.x
			local dy = coords.y - zone.coords.y
			local dist = math.sqrt(dx * dx + dy * dy)
			if dist < closestDist then
				closestDist = dist
				foundId = zoneId
			end
		end
	end

	if not foundId then
		debugLog(('RemoveZoneAttempt failed: source=%s not inside any zone'):format(tostring(source)))
		sendNotification(source, Config.Local.NotInZone, 'error')
		return
	end

	local removedZone = activeZones[foundId]
	debugZone('Zone removed', removedZone)
	activeZones[foundId] = nil
	broadcastRemoveZone(foundId)
	sendNotification(-1, Config.Local.ZoneRemoved, 'success')
	if removedZone then
		removedZone.createdBy = source
		sendZoneWebhook('zone_remove', player, removedZone)
	end
end)

