fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

description 'Sky City RP - Spike Strip System'
author 'Colbss'
version '1.0.0'

dependencies {
    'ox_lib',
}

shared_scripts { 
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}

client_scripts { 
    'client/*.lua',
} 

server_scripts {
    'server.lua'
}

files {
    'config.lua',
    'sounds/dlc_stinger/stinger.awc',
	'sounds/data/stinger.dat54.rel',
}

data_file 'DLC_ITYP_REQUEST' 'spike_deployer.ytyp'
data_file "AUDIO_WAVEPACK" "sounds/dlc_stinger"
data_file "AUDIO_SOUNDDATA" "sounds/data/stinger.dat"
