# rsg-adminmenu

A staff admin panel for **RSG Framework (RedM)**. React NUI with tiered staff roles, player management, reports/tickets, logging, admin chat, world tools and server controls.

---

## Features

### Overview
- **Dashboard**: live server stats and a greeting (Discord name when a bot token is set, otherwise the character name).
- **Statistics**: player counts, playtime, activity and economy charts.

### Players
- **Player list and manage modal**: money, ping, citizen ID, Steam hex, Discord ID, inventory.
  - **Actions**: revive, heal, kill, freeze, goto, bring, spectate, open inventory, give/remove items.
  - **Moderation**: warn, kick, ban/unban, set permission (role).
  - **Character**: give/remove money, set job, nickname, first/last name, age, description, add/remove XP.
  - **Clean-up**: clear weapons, clear items.
  - **Troll**: wild animal attack, set on fire, lightning, to heaven, ragdoll, drain stamina, handcuff, drunk, jump scare, horse buck, haunted, make everyone attack.
- **Whitelist**: manage whitelisted players (mod and above).
- **Reports**: players use `/report` to open bug, player or question tickets with in-ticket messaging. Staff claim, resolve and close them. Nearby players are captured automatically, and reports post to Discord with optional role mentions.
- **Finances**: give or remove cash, bank or bloodmoney (admin and above).

### Team
- **Admins**: grant, change or remove staff roles. Roles are stored in the database and re-applied as ACE on every connect, so you never edit `server.cfg` per staff member. Staff can only manage roles **below their own**.
- **Logs**: searchable in-game log of every admin action, with severity levels and Discord webhooks.
- **Admin chat**: persistent staff-only chat.

### Self Tools (all staff)
God mode, invisible, player blips (when `Config.EnablePlayerBlips` is on), player ID tags (txAdmin), revive yourself, and teleport to your map marker.

### World (mod and above)
- **Teleports**: saved teleport locations.
- **Coords**: copy your current coords or teleport to coords.
- **Blips**: create, edit and delete persistent map blips (shown to staff).
- **Spawner**: spawn peds, animals, wagons and props, and clear an area.

### Developer (Head Admin / Developer / Owner)
- **Server settings**: close/open the server, kick all players, refresh resources, send announcements, and override time, weather, wind and timescale.
- **Resource lookup**: browse server resources.
- **Master actions**: edit Discord webhook URLs in game (saved to the database and written back into `server/sv_config.lua`).

---

## Requirements

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework, notifications, callbacks, locales, multi-job |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Open inventory, give or clear items |
| [rsg-medic](https://github.com/Rexshack-RedM/rsg-medic) | Revive and heal |
| [rsg-lawman](https://github.com/Rexshack-RedM/rsg-lawman) | Optional: handcuff action |
| [rsg-log](https://github.com/Rexshack-RedM/rsg-log) | Optional: extra logging |

ox_lib is **not** required.

---

## Installation

1. Place the resource in your `resources` folder as `rsg-adminmenu`.
2. Add to `server.cfg` **after** `rsg-core`, `oxmysql` and `rsg-inventory`:
   ```cfg
   ensure rsg-adminmenu
   add_ace resource.rsg-adminmenu command.refresh allow
   ```
   The `add_ace` line is only needed for the **Refresh Resources** button.
3. Give yourself the top role once (every other role is managed from the **Admins** page):
   ```cfg
   add_principal identifier.license:YOUR_LICENSE group.god
   ```
4. Fill in `server/sv_config.lua` (bot token, webhooks) and restart.

All database tables are created automatically on first start. `install.sql` is provided if you prefer to create them yourself.

The NUI ships prebuilt in `web/dist`. Rebuild only if you change the React source:
```bash
cd web
npm install
npm run build
```

---

## Usage

| Command / key | Who | Description |
|---|---|---|
| `/adminmenu` or **Page Up** | Staff | Open the admin panel |
| `/report` | Everyone | Open the report/ticket menu |

---

## Roles and permissions

From lowest to highest (as in rsg-core's `RSGConfig.Server.Permissions`):

| Role | Label | Access |
|---|---|---|
| `helper` | Helper | Panel, revive/heal/kill, goto/bring/freeze/spectate, inventory, give item, set job/character fields, XP, coords |
| `mod` | Moderator | + kick, warn, whitelist, troll actions, world tools |
| `admin` | Admin | + ban/unban, money, clear weapons/items, reports |
| `headadmin` / `developer` | Head Admin / Developer | + server settings, resource lookup, master actions, manage roles |
| `god` | Owner | Everything |

To change what an action needs, edit the `permissions` table at the top of `server/server.lua`.

> **Security:** every action is re-checked on the server and every client value is validated. A client that fires a staff event without the role is banned through rsg-core's `ExploitBan` and logged at high severity.

---

## Configuration

### `shared/config.lua` (sent to players, no secrets here)
| Option | Description |
|---|---|
| `Config.EnablePlayerBlips` | Allow staff to toggle player blips |
| `Config.Reports.NearbyDistance` | Radius used to capture players near the reporter (default `50.0`) |
| `Config.Reports.Cooldown` | Seconds between reports per player (default `60`, enforced on the server) |

### `server/sv_config.lua` (server only)
| Option | Description |
|---|---|
| `Config.DiscordBot.Token` | Bot token used to show staff Discord names/avatars. The bot does **not** need to be in your server. Leave blank to use character names |
| `Config.Webhooks.AdminLogs` | Any admin action |
| `Config.Webhooks.PlayerManagement` | Player-targeted actions, including money |
| `Config.Webhooks.WorldSettings` | Server actions and time/weather/wind/timescale changes |
| `Config.Reports.Webhooks` | `Main`, plus optional `Bug`, `Player` and `Question` (empty = use `Main`) |
| `Config.Reports.Discord` | `EnableRoleMention` and `RolesToMention` (role IDs pinged on new reports) |
| `Config.Reports.WebhookColors` | Embed colours per report type and status |
| `Config.Reports.ReplyCooldown` | Seconds between report replies per player (default `3`) |

### Time and weather
rsg-weather stays in charge by default. The panel only overrides time, weather, wind or timescale after a developer changes them in **Server settings**, and only the settings that were changed.

---

## Locales

`locales/*.json`, complete in: en, de, el, es, fr, ja, nl, pl, pt-br, ro (partial: cs, hu, it). Set the language in `server.cfg`:
```cfg
setr rsg:locale "en"
```

---

## Support

- [Rexshack-RedM on GitHub](https://github.com/Rexshack-RedM)
- Support: https://buymeacoffee.com/rexshack

## License

See [LICENSE](LICENSE).
