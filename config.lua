Config = {}

-- Discord webhook logs
Config.Webhook = {
	Enabled = true,
	Url = 'YOUR_URL_HERE',
	Username = 'pc-stoptraffic',
	AvatarUrl = 'YOUR_URL_HERE',
	IncludePosition = true, -- true = include x,y,z in embeds
	Colors = {
		StopCreated = 15158332, -- red
		SlowCreated = 16766720, -- yellow/orange
		ZoneRemoved = 5793266   -- green
	}
}

-- Authorized job(s)
-- string: 'police'
-- table: { 'police', 'sheriff' }
Config.Job = { 'police', 'ambulance' }

-- If true, the player must be on duty
Config.RequireOnDuty = true

-- Customizable commands
Config.Commands = {
	Open = 'stoptraffic',       -- /stoptraffic
	SlowOpen = 'slowtraffic',   -- /slowtraffic
	Remove = 'stoptrafficoff'   -- /stoptrafficoff
}

-- Radius parameters
Config.Radius = {
	Min = 0,
	Max = 100,
	Default = 25,
	Step = 5
}

Config.Slow = {
	Speed = {
		Min = 5,
		Max = 120,
		Default = 50,
		Step = 5
	}
}

Config.PositionMenu = 'top-right' -- You can set 'top-left' or 'top-right' or 'bottom-left' or 'bottom-right'

-- Ground circle marker
Config.Marker = {
	Type = 1,
	Color = { r = 255, g = 70, b = 70, a = 110 },
	Height = 1.2,
	BobUpAndDown = false,
	FaceCamera = false,
}

-- All active zones remain visible
Config.ShowActiveZoneMarker = false

Config.Preview = {
	BlipColors = {
		stop = 1,
		slow = 5
	},
	BlipAlpha = 80
}

-- Minimap circle (visible only to authorized job members)
Config.Minimap = {
	Enabled = true,
	Colors = {
		stop = 1,         -- red
		slow = 5          -- yellow
	},
	Alpha = 110,         -- circle transparency
	ShowCenter = false,
	CenterSprite = 883,  -- center icon
	CenterScale = 0.8,
	CenterColors = {
		stop = 1,
		slow = 5
	},
	ShortRange = true,
	Names = {
		stop = 'Stop Traffic',
		slow = 'Slow Traffic'
	}
}

Config.Local = {
	NotAuthorized = 'You do not have permission to use this command.',
	MustBeOnDuty = 'You must be on duty to use this command.',
	ZoneCreated = 'Stop traffic enabled.',
	SlowZoneCreated = 'Slow traffic enabled.',
	ZoneRemoved = 'Traffic zone disabled.',
	NoZone = 'No active stop traffic zone.',
	NotInZone = 'You must be inside the zone to disable it.',
	ZoneReplaced = 'The active stop traffic zone has been moved.',
	PreviewCancelled = 'Zone creation cancelled.',
	MenuTitle = 'Stop Traffic',
	SlowMenuTitle = 'Slow Traffic',
	ConfirmOption = 'Confirm zone',
	CancelOption = 'Cancel',
	CurrentRadius = 'Current radius',
	RadiusLabel = 'Zone size',
	RadiusDescription = 'Choose a radius between 0 and 100 meters.',
	SpeedLabel = 'Speed in zone (km/h)',
	SpeedDescription = 'Choose the maximum NPC vehicle speed in the zone.',
	ConfirmTitle = 'Confirm zone',
	ConfirmDescription = 'Confirm this stop traffic zone?',
	SlowConfirmDescription = 'Confirm this slow traffic zone?',

	Webhook = {
		Unknown = 'Unknown',
		NotAvailable = 'N/A',

		TitleStopCreated = 'Stop Traffic Created',
		TitleSlowCreated = 'Slow Traffic Created',
		TitleZoneRemoved = 'Traffic Zone Removed',

		DescriptionStopCreated = 'A stop traffic zone was created by %s.',
		DescriptionSlowCreated = 'A slow traffic zone was created by %s.',
		DescriptionZoneRemoved = '%s removed a traffic zone.',

		FieldServerId = 'Server ID',
		FieldRpName = 'RP Name',
		FieldSessionName = 'Session Name',
		FieldCitizenId = 'CitizenID',
		FieldJob = 'Job',
		FieldZoneType = 'Zone Type',
		FieldRadius = 'Radius',
		FieldSpeed = 'Speed',
		FieldZoneId = 'Zone ID',
		FieldLicense = 'License',
		FieldDiscordId = 'Discord ID',
		FieldPosition = 'Position',

		ValueJobFormat = '%s (on duty: %s)',
		ValueRadiusFormat = '%sm',
		ValueSpeedFormat = '%s km/h',
		ValueSpeedStop = '0 km/h',
		ValuePositionFormat = 'x: %.2f y: %.2f z: %.2f',
		ValueZoneTypeStop = 'stop',

		FooterFormat = '%s • %s'
	}
}

--[[
	The 'Config.Sleep' variable sets the refresh rate (in milliseconds) for the while true loop.
	By default, it is set to 1500 (1.5 seconds).
]]
Config.Sleep = 1500

-- Show debug logs in console
Config.Debug = false
