fx_version 'cerulean'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-adminmenu'
version '3.0.0'

ui_page 'web/dist/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/server_finances.lua',
    'server/server_stats.lua',
    'server/server_whitelist.lua',
    'server/server_history.lua',
    'server/versionchecker.lua',
    'server/server_reports.lua',
    'server/server_logs.lua',
    'server/server_admins.lua',
    'server/server_adminchat.lua',
    'server/server_world.lua',
    'server/server_devtools.lua',
    'server/server_masteradmin.lua',
}

files {
    'locales/*.json',
    'web/dist/index.html',
    'web/dist/**/*',
}

dependencies {
    'rsg-core',
    'ox_lib',
}
