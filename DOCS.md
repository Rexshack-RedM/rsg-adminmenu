# rsg-adminmenu: developer and server owner docs

## Contents
1. [Architecture](#architecture)
2. [Data formats](#data-formats)
3. [Exports and shared server functions](#exports-and-shared-server-functions)
4. [Events and callbacks](#events-and-callbacks)
5. [Integration examples](#integration-examples)
6. [Persistence](#persistence)
7. [Security model](#security-model)
8. [Database schema](#database-schema)
9. [Server owner how-tos](#server-owner-how-tos)
10. [Troubleshooting](#troubleshooting)

---

## Architecture

| File | Purpose |
|---|---|
| `fxmanifest.lua` | Loads `@rsg-core/shared/locale.lua`, config, client/server files and the NUI |
| `shared/config.lua` | Client-safe options (downloaded by every player) |
| `server/sv_config.lua` | **Server-only** secrets: Discord bot token and webhook URLs |
| `server/server_database.lua` | Creates/upgrades every table when `Config.AutoDatabase` is on; exposes `OnDatabaseReady` |
| `server/server.lua` | `permissions` table, shared helpers, player actions, item catalog, self tools, `/adminmenu`, `/report` |
| `server/server_admins.lua` | Role labels/levels, rank hierarchy (`CanActOn`, `ChangeAdminRole`), Admins page |
| `server/server_history.lua` | Punishment history (`admin_player_history`), `GetPlayerRole`, `CanManageHistory` |
| `server/server_logs.lua` | `LogAdminAction`, Discord embeds, Logs page |
| `server/server_finances.lua` | Give/remove money, finance data |
| `server/server_reports.lua` | Report tickets, replies, staff status changes, report webhooks |
| `server/server_whitelist.lua` | Whitelist CRUD and optional enforcement |
| `server/server_stats.lua` | Playtime tracking, activity sampling, dashboard and statistics data |
| `server/server_world.lua` | Teleport locations, staff blips, spawner, clear area |
| `server/server_devtools.lua` | Close server, kick all, refresh, announcements, time/weather/wind/timescale, resource list |
| `server/server_masteradmin.lua` | Webhook settings, replay of custom items stored by older versions |
| `server/server_adminchat.lua` | Staff chat |
| `server/versionchecker.lua` | Version check against the Rexshack-RedM repo |
| `client/nui.lua` | NUI open/close, focus, notebook scenario, locale hand-off |
| `client/client.lua` | Open panel, player list/info, player action relays, self tools, spectate, Page Up keymap |
| `client/client_playeractions.lua` | Remaining action relays and the target-side effects (kill, ragdoll, drunk, ...) |
| `client/client_troll.lua` | Wild animal attack and set on fire (run on the target's client) |
| `client/client_world.lua` | Coords, teleports, blips, spawner, clear area |
| `client/client_devtools.lua` | Server settings relays and applying world settings |
| `client/client_doorid.lua` | Door ID overlay (`DoorIds` global) |
| `client/client_reports.lua`, `client_admins.lua`, `client_whitelist.lua`, `client_finances.lua` | NUI callback relays |
| `web/` | React + Vite source; `web/dist` is the built UI that ships |

---

## Data formats

**`permissions` (server/server.lua)**: action name → ACE group (string) or list of groups. `'god'` ACE always passes.

**Role levels**: taken from `RSGCore.Config.Server.Permissions`; the first entry is the highest. Non-staff are level 0.

**World settings** (sent to clients in `rsg-adminmenu:client:applyworldsettings`): only sections an admin has set are present.
```lua
{
    time = { day = 'Monday' | nil, hour, minute, second, transition, freeze },
    weather = { type = 'SUNNY', transition, freeze, snow },
    timescale = 1.0,
    wind = { direction = 0-360, speed = 0-100, freeze },
}
```

**XP** is stored in `PlayerData.metadata.xp`.

---

## Exports and shared server functions

The resource registers no `exports(...)`. These globals are shared between its own server files and can be used by anything that runs inside this resource:

| Function | Returns | Purpose |
|---|---|---|
| `HasAdminPermission(src, action)` | boolean | Checks `permissions[action]` or the `god` ACE |
| `CanActOn(src, target)` | boolean | `true` for yourself, anyone of a lower rank, or anything for the Owner |
| `ChangeAdminRole(src, citizenid, targetSrc?, role?, name?)` | ok, message | Grants (`role`) or removes (`nil`) a staff role with hierarchy checks |
| `LogAdminAction(category, severity, src?, action, details?, targetName?, targetSrc?)` | — | Writes `admin_logs` and posts the category's webhook |
| `LogPlayerHistory(citizenid, action, reason, adminName, durationSeconds?, severity?)` | — | Writes `admin_player_history` |
| `GetPlayerRole(src)` | string | Highest configured ACE group the player holds, or `'user'` |
| `LabelForRole(role)` | string | Localised role name |
| `NotifyPlayer(src, title, description, type, duration?)` | — | rsg-core notification |
| `SanitizeText(value, maxLength)` | string \| nil | Trim and cap free text, `nil` when empty |
| `OnDatabaseReady(fn)` | — | Runs `fn` once the tables exist |

Log categories: `admin_action`, `player_action`, `economy`, `security`, `server_event`, `system`. Severities: `low`, `medium`, `high`.

---

## Events and callbacks

### Client events other resources may listen to
| Event | Payload |
|---|---|
| `rsg-adminmenu:client:newreportnotification` | `{ id, reporter_name, report_type }` (`report_type = 'response'` for a reply) |
| `rsg-adminmenu:client:reportreplynotification` | `{ reportId, adminName }` |
| `rsg-adminmenu:client:applyworldsettings` | world settings table (see above) |

### Server net events (fired by the NUI, all permission-checked)
`playerrevive`, `healplayer`, `openinventory`, `kickplayer`, `banplayer`, `gotoplayer`, `bringplayer`, `freezeplayer`, `spectateplayer`, `giveitem`, `killplayer`, `ragdollplayer`, `lightningplayer`, `toheavenplayer`, `drainstaminaplayer`, `drunkplayer`, `jumpscareplayer`, `horsebuckplayer`, `hauntedplayer`, `everyoneattackplayer`, `wildattack`, `playerfire`, `handcuffplayer`, `warnplayer`, `setpermission`, `setjob`, `setcharfield`, `adjustxp`, `clearweapons`, `clearitems`, `financeadd`, `financeremove`, `createreport`, `claimreport`, `releasereport`, `resolvereport`, `deletereport`, `replyreport` (all prefixed `rsg-adminmenu:server:`).

### Callbacks (rsg-core `CreateCallback`)
All prefixed `rsg-adminmenu:server:` and permission-checked: `getplayers`, `getplayerinfo`, `getallplayersmanaged`, `unbanplayer`, `getbotlogo`, `getallitems`, `removeplayeritem`, `selftool`, `selfrevive`, `getadmins`, `getroleconfig`, `addadmin`, `changeadminrole`, `removeadmin`, `getlogs`, `sendlogtodiscord`, `getplayerhistory`, `deletehistoryentry`, `getPlayerData`, `getdashboardstats`, `getstatistics`, `getwhitelist`, `addwhitelist`, `setwhiteliststatus`, `removewhitelist`, `getmyreports`, `getallreports`, `getreportdetails`, `getteleportlocations`, `addteleportlocation`, `deleteteleportlocation`, `getblips`, `addblip`, `updateblip`, `deleteblip`, `spawnentity`, `cleararea`, `getserverstate`, `togglecloseserver`, `kickallplayers`, `refreshresources`, `sendannouncement`, `getworldsettings`, `settimesettings`, `setweathersettings`, `settimescale`, `setwindsettings`, `getresources`, `getwebhooksettings`, `savewebhooksettings`, `createadminchatmessage`, `getadminchatmessages`.

---

## Integration examples

Show a toast to staff when your own resource raises an alert, using the same notification the panel uses:
```lua
-- server, in another resource
local RSGCore = exports['rsg-core']:GetCoreObject()
for _, id in ipairs(RSGCore.Functions.GetPlayers()) do
    if RSGCore.Functions.HasPermission(id, 'helper') or IsPlayerAceAllowed(id, 'god') then
        TriggerClientEvent('RSGCore:Client:Notify', id, { title = 'Alert', description = 'Something happened', type = 'warning' })
    end
end
```

Make a ban action require Head Admin instead of Admin (`server/server.lua`):
```lua
['ban'] = 'headadmin',
```

---

## Persistence

| Data | Where |
|---|---|
| Staff roles | `admin_roles`, re-applied as ACE on connect |
| Bans | rsg-core's `bans` table (`expire = 2524608000` means permanent) |
| Kick/ban/warn history | `admin_player_history` |
| Admin action log | `admin_logs` |
| Reports, replies, nearby players | `admin_reports`, `admin_report_messages`, `admin_report_nearby_players` |
| Whitelist | `admin_whitelist` |
| Playtime / activity samples | `player_playtime` (every minute), `admin_activity_log` (every 15 minutes) |
| Teleports / blips | `adminmenu_teleports`, `adminmenu_blips` |
| Webhook overrides | `adminmenu_settings` (and written into `server/sv_config.lua`) |
| Custom items from older versions | `adminmenu_custom_items`, re-registered with rsg-core on start |
| Closed-server flag, world settings, freeze state | memory only (reset on restart) |

---

## Security model

What the script checks on the server:
- Every net event and callback checks `HasAdminPermission`. An unauthorised **net event** bans the sender; an unauthorised **callback** just returns empty data.
- Targets must be online; punitive actions also require `CanActOn` (no acting on equal/higher staff, except the Owner).
- Role changes can't grant a role at or above your own, or change someone at or above your rank (yourself included). A demoted admin's panel is force-closed.
- All client input is validated: item exists and amount 1-1000, money type and positive amount, job/grade via rsg-core `SetJob`, text length caps, numeric ids, coord ranges, weather names, time/wind/timescale ranges, webhook URLs (Discord only).
- Cash and bloodmoney items can't be given as items (use Finances so rsg-core's money stays in sync); `CanAddItem` is checked before `AddItem`, and `RemoveMoney`'s result is checked.
- Reports: server-side cooldown per license, type/severity allow-lists, length caps, exact-host image allow-list, 3 s reply cooldown, no replies to closed reports, reporter notifications only go to the same license.
- Webhook URLs and the bot token are never sent to clients; webhook changes are logged with masked URLs.

What other resources must check themselves: anything they trigger on behalf of a player. This resource exposes no exports that skip its checks.

---

## Database schema

The full schema is in `install.sql` and is identical to `server/server_database.lua`. Columns added after the first release (`admin_reports.severity`, `admin_reports.reporter_steam`, `admin_player_history.severity`, `admin_chat_messages.sender_discord_name`, `admin_chat_messages.sender_discord_avatar_url`, `admin_activity_log.total_money`) are added automatically if missing.

---

## Server owner how-tos

- **Add the first owner**: `add_principal identifier.license:YOUR_LICENSE group.god` in `server.cfg`, restart, then manage everyone else from the Admins page.
- **Enable Discord names/avatars**: put a bot token in `server/sv_config.lua` (`Config.DiscordBot.Token`).
- **Route logs to Discord**: set the webhook URLs in `server/sv_config.lua` or in game under Master Actions.
- **Enforce the whitelist**: add characters on the Whitelist page, then set `Config.Whitelist.Enforce = true`.
- **Let Refresh Resources work**: `add_ace resource.rsg-adminmenu command.refresh allow`.
- **Change the Page Up key**: edit the `RegisterRawKeymap` call at the bottom of `client/client.lua` (`0x21` is the raw key code).
- **Replace the jump scare**: drop `jumpscare.png` / `jumpscare.mp3` into `web/public` and rebuild.

---

## Troubleshooting

| Problem | Fix |
|---|---|
| Panel says "Not Allowed" | Your ACE group isn't in `RSGConfig.Server.Permissions`, or you need `add_principal ... group.god` |
| Red "database setup failed" in console | Check oxmysql's connection string; or set `Config.AutoDatabase = false` and import `install.sql` |
| Refresh Resources fails | Add `add_ace resource.rsg-adminmenu command.refresh allow` to `server.cfg` |
| "You cannot do that to staff of the same or higher rank" | Working as intended; ask someone of a higher rank or the Owner |
| No Discord names or bot logo | Bot token missing/invalid in `server/sv_config.lua` |
| Webhooks don't post | URLs must start with `https://discord.com/api/webhooks/` (or discordapp.com) |
| Give item says the inventory is full | The target lacks weight or slots; `CanAddItem` refused it |
| Time/weather keeps resetting | A frozen setting is re-applied every 5 s; untick Freeze, or let rsg-weather manage it |
| Weather set in rsg-weather not showing | Fixed: when rsg-weather is started, the panel's time/weather/wind are sent through `exports['rsg-weather']` (setWeather/setTime/setWind) and are no longer applied natively or re-forced, so the two can't fight. Timescale (game speed) is still applied by the admin menu |
| Report image rejected | Only Imgur, Discord CDN, Gyazo and prnt.sc links are accepted |

---

Support: https://buymeacoffee.com/rexshack
