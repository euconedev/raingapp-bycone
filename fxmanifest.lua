-- Resource Metadata
fx_version 'bodacious'
games { 'gta5' }

dependencies {
    'vrp',
    'oxmysql',
    'ox_lib',
    --'mysql-async'
}

author 'Coffeelot & Wuggie'
description 'CW Racing App'
version '5.0.6'

ui_page {
    "web/dist/index.html"
}

shared_scripts {

    'locales/pt.lua',
    'shared/config.lua',
    'shared/elo.lua',
    'shared/head2head.lua',
}

client_scripts {
    '@ox_lib/init.lua',
    'bridge/client/standalone.lua',
    'bridge/client/creative.lua',
    'bridge/client_bridge.lua',

    'client/classes.lua',
    'client/globals.lua',
    'client/functions.lua',
    'client/main.lua',
    'client/gui.lua',
    'client/head2head.lua',
}

server_scripts {
    '@vrp/lib/utils.lua',

    'server/debug.lua',
    'server/database.lua',
    'server/databaseTimes.lua',

    'bridge/server/creative.lua',
    'bridge/server/standalone.lua',
    'bridge/server_bridge.lua',
    'bridge/vrp_bridge.lua',

    'server/functions.lua',
    'server/crews.lua',
    'server/elo.lua',
    'server/bounties.lua',
    'server/main.lua',
    'server/head2head.lua'
}

files {
    "web/dist/index.html",
    "web/dist/assets/*.*",
}

lua54 'yes'