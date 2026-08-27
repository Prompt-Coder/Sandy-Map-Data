fx_version "cerulean"
games { 'gta5' }

author 'Prompt Mods'
description 'Roads+Downtown+Hospital2+Corner+Bank+Market+Motel+Gas+Mechanic+Church+Dealer+Trainstation+Marina+Sheriff+Airfield'
version '1.0.0'

this_is_a_map 'yes'

escrow_ignore {
    'stream/**'
}

-- scripts --
lua54 'yes'

data_file 'DLC_ITYP_REQUEST' 'stream/prompt_props/prompt_sandy_props.ytyp'


client_scripts {
    'client.js'
}

server_scripts{
    'sv_MapDataHandler.lua',
    'server.js'
}
