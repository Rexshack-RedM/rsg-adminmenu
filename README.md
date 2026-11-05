# rsg-adminmenu

A full staff admin panel for **RSG Framework (RedM)**: a React NUI with tiered staff roles, player management, reports and tickets, logging, admin chat, world tools and server controls.

**Version:** 3.1.0 · **Requires:** rsg-core, rsg-inventory, oxmysql · Developer and owner reference: [DOCS.md](DOCS.md)

---

## Features

### Overview
- **Dashboard**: live server stats, a greeting for the admin (their Discord name when a bot token is set, otherwise their character name), and **Self Tools**.
- **Self Tools**: self revive, teleport to map marker, godmode, invisibility, player blips (when enabled in config) and door IDs. Every toggle is checked and logged on the server.
- **Statistics**: player counts, playtime, job distribution, economy and activity charts.

### Players
- **Player list and management modal**: cash/bank, ping, citizen ID, Steam hex and Discord ID at a glance (IP is shown to admin and above only).
  - **Actions**: revive, heal, kill, freeze, goto, bring, spectate, open inventory, give/remove items.
  - **Moderation**: warn, kick, ban/unban, set permission (role), with full punishment history.
  - **Character**: give/remove money, set job, set nickname, first name, last name, age and description, add/remove XP.
  - **Clean-up**: clear weapons, clear items.
  - **Troll**: wild animal attack, set on fire, lightning, to heaven, ragdoll, drain stamina, handcuff, drunk, jump scare, horse buck, haunted, make everyone attack.
- **Whitelist**: manage whitelisted characters (mod and above), with optional enforcement on join.
- **Reports**: players use `/report` to open bug, player or question tickets with in-ticket messaging. Staff claim, resolve and close them. Nearby players are captured automatically, and reports post to Discord with optional role mentions.
- **Finances**: give and remove any money type (admin and above).

### Team
- **Admins**: grant or change staff roles from the panel. Roles are stored in the database and re-applied as ACE on every connect, so you never need to edit `server.cfg` per staff member. Staff can't grant a role at or above their own, or change anyone at or above their own rank.
- **Logs**: searchable in-game log of every admin action with severity levels, plus Discord webhooks.
- **Admin chat**: a persistent staff-only chat.

### World (mod and above)
- **Teleports**: built-in and saved custom teleport locations, and teleport to coords (takes your horse with you).
- **Coords**: copy your current coords.
- **Blips**: create, edit and delete persistent staff map blips.
- **Spawner**: spawn peds, animals, wagons and props, and clear an area.

### Developer (Head Admin / Developer / Owner)
- **Server settings**: close/open the server, kick all players, refresh resources, send announcements, and set time, weather (with snow mode), wind and timescale. When rsg-weather is running, time/weather/wind are passed to rsg-weather so they stay in sync and don't conflict.
- **Resource lookup**: browse server resources with versions and dependencies.
- **Master actions**: edit Discord webhook URLs in game (saved to the database and written back into `server/sv_config.lua`).

---

## Requirements

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework, locales, notifications, callbacks |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Open inventory, give, remove or clear items |
| [rsg-medic](https://github.com/Rexshack-RedM/rsg-medic) | Revive and heal (`rsg-medic:client:revive` / `rsg-medic:client:heal`) |
| [rsg-lawman](https://github.com/Rexshack-RedM/rsg-lawman) | Optional: handcuff action |
| [rsg-log](https://github.com/Rexshack-RedM/rsg-log) | Optional: extra logging |

ox_lib is **not** required.

---

## Installation

1. Place the resource in your `resources` folder as `rsg-adminmenu`.
2. Add it to `server.cfg` **after** `rsg-core`, `oxmysql` and `rsg-inventory`:
   ```cfg
   ensure rsg-adminmenu
   ```
3. **Database**: all tables are created automatically on first start. To install manually instead, set `Config.AutoDatabase = false` and import `install.sql`.
4. Give yourself the top role once (every other role is managed from the **Admins** page):
   ```cfg
   add_principal identifier.license:YOUR_LICENSE group.god
   ```
5. Let the panel's **Refresh Resources** button work:
   ```cfg
   add_ace resource.rsg-adminmenu command.refresh allow
   ```
6. Put your bot token and webhooks in `server/sv_config.lua`, adjust `shared/config.lua`, and restart.

> **Upgrading from 3.0.x:** the bot token and webhook URLs moved from `shared/config.lua` (which every client downloads) to `server/sv_config.lua`. Copy them across, then **reset your Discord bot token** and **recreate your webhooks**: the old values were readable by any connected player.

The NUI ships prebuilt in `web/dist`. You only need to rebuild it if you change the React source:
```bash
cd web
npm install
npm run build
```

---

## Configuration

### `shared/config.lua`

| Option | Default | Description |
|---|---|---|
| `Config.AutoDatabase` | `true` | Create/upgrade the tables on start. Set `false` to import `install.sql` yourself |
| `Config.EnablePlayerBlips` | `true` | Allow staff to toggle player blips from Self Tools |
| `Config.Whitelist.Enforce` | `false` | Drop characters without an active whitelist entry when they load in (staff are exempt) |
| `Config.Reports.Discord.EnableRoleMention` | `true` | Ping roles on new reports |
| `Config.Reports.Discord.RolesToMention` | placeholder | Discord role IDs to ping (non-numeric entries are ignored) |
| `Config.Reports.WebhookColors` | see file | Embed colours per report type and status |
| `Config.Reports.NearbyDistance` | `50.0` | Radius used to capture players near the reporter |
| `Config.Reports.Cooldown` | `60` | Seconds between reports per player (enforced on the server) |
| `Config.DoorHashes` | see file | Door hash table used by the Door IDs self tool |

### `server/sv_config.lua` (server only)

| Option | Default | Description |
|---|---|---|
| `Config.DiscordBot.Token` | `""` | Bot token used to look up Discord names and avatars. The bot does **not** need to be in your server. Blank = character names |
| `Config.Webhooks.AdminLogs` | `""` | Admin actions (roles, settings, teleports, chat, security) |
| `Config.Webhooks.PlayerManagement` | `""` | Player-targeted actions, including give/remove money |
| `Config.Webhooks.WorldSettings` | `""` | Server actions, time/weather/wind/timescale |
| `Config.Reports.Webhooks` | `""` | `Main`, plus optional `Bug`, `Player` and `Question` (empty = use `Main`) |

---

## Usage

| Command / key | Who | Description |
|---|---|---|
| `/adminmenu` or **Page Up** | Staff | Open the admin panel (Page Up also ends spectating) |
| `/report` | Everyone | Open the report/ticket menu |

### Roles and permissions

Roles from lowest to highest (as ordered in rsg-core's `RSGConfig.Server.Permissions`):

| Role | Access |
|---|---|
| `helper` | Panel, self tools, reports, revive/heal/kill, goto/bring/freeze/spectate, inventory, give/remove item, set job/character fields, XP |
| `mod` | + kick, warn, whitelist, troll actions, world tools (teleports, coords, blips, spawner) |
| `admin` | + ban/unban, finances, clear weapons/items, see player IPs |
| `headadmin` / `developer` | + server settings, resource lookup, master actions; `headadmin` can manage roles and delete history |
| `god` | Owner: everything, and the only role that can act on staff of equal rank |

To change the role an action needs, edit the `permissions` table at the top of `server/server.lua`.

> **Security:** every action is re-checked on the server. A client that fires an admin event it has no permission for is **automatically banned** and logged at high severity. Punitive actions (kick, ban, freeze, troll, clear, set job/role, remove money, ...) can't be used on staff of the same or a higher rank.

---

## Developer examples

```lua
-- server: write an entry to the admin log (and its Discord webhook)
LogAdminAction('admin_action', 'low', source, 'Did a thing', 'details here', nil)
```

Other resources can listen for the client notifications this script sends:
```lua
RegisterNetEvent('rsg-adminmenu:client:newreportnotification', function(data)
    -- data.id, data.reporter_name, data.report_type
end)
```

---

## Locales

`locales/*.json`: en, de, el, es, fr, ja, nl, pl, pt-br, ro (complete), plus partial cs, hu and it (missing keys fall back to English). Set the language in `server.cfg`:
```cfg
setr rsg:locale "en"
```

---

Support: https://buymeacoffee.com/rexshack

## License

See [LICENSE](LICENSE).
