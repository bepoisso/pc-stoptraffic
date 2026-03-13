fx_version 'cerulean'
game 'gta5'

lua54 'yes'

name 'pc-stoptraffic'
author 'pc'
description 'Stop traffic zone (job restricted) with ox_lib UI'
version '1.0.0'

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

client_scripts {
	'client/client.lua'
}

server_scripts {
	'server/server.lua'
}

dependencies {
	'ox_lib',
	'qb-core'
}
