fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

description 'Aether Scripts - Spike Strips'
author 'Colbss'
version '1.6.0'

dependencies {
    'ox_lib',
}

shared_scripts { 
    '@ox_lib/init.lua',
}

client_scripts { 
    'modules/bridge/client/*.lua',
    'modules/client/*.lua',
} 

server_scripts {
    'modules/bridge/server/*.lua',
    'modules/server/*.lua',
}

ui_page 'web/dist/index.html'

files {
    'config.lua',
    'shared.lua',
    'locales/*.json',
    'sounds/dlc_stinger/stinger.awc',
	'sounds/data/stinger.dat54.rel',
    'web/dist/**/*',
}

data_file 'DLC_ITYP_REQUEST' 'spike_deployer.ytyp'
data_file "AUDIO_WAVEPACK" "sounds/dlc_stinger"
data_file "AUDIO_SOUNDDATA" "sounds/data/stinger.dat"
