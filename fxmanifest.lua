fx_version 'cerulean'
game 'gta5'

lua54 'yes'

author 'Kanayu_u'
description 'Hold the enter key near a vehicle to pick a seat (based on SeatSelection by BeereMgM, MIT).'
version '1.2.0'

shared_scripts {
    'config/config.lua',
    'locales/locale.lua',
    'locales/en.lua',
    'locales/ja.lua'
}

client_scripts {
    'client/main.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}
