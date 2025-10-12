fx_version 'cerulean'
lua54 'yes'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-adminmenu'
version '2.0.9'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/server.lua',
    'server/server_finances.lua',
    'server/versionchecker.lua',
    'server/server_reports.lua',
}

files {
    'locales/*.json',
}

dependencies {
    'rsg-core',
    'ox_lib',
}
