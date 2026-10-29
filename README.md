# rsg-adminmenu

A full staff admin panel for **RSG Framework (RedM)**. It has a React NUI with tiered staff roles, player management, reports and tickets, logging, admin chat, world tools and server controls.

---

## Features

### Overview
- **Dashboard**: live server stats and a greeting for the admin (their Discord username when a bot token is set, otherwise their character name).
- **Statistics**: player counts, playtime and activity charts.

### Players
- **Player list and management modal**: cash/bank, ping, citizen ID, Steam hex and Discord ID at a glance.
  - **Actions**: revive, heal, kill, freeze, goto, bring, spectate, open inventory, give items.
  - **Moderation**: warn, kick, ban/unban, set permission (role).
  - **Character**: give/remove money, set job, set nickname, first name, last name, age and description, add/remove XP.
  - **Clean-up**: clear weapons, clear items.
  - **Troll**: wild animal attack, set on fire, lightning, to heaven, ragdoll, drain stamina, handcuff, drunk, jump scare, horse buck, haunted, make everyone attack.
- **Whitelist**: manage whitelisted players (mod and above).
- **Reports**: players use `/report` to open bug, player or question tickets with in-ticket messaging. Staff claim, resolve and close them. Nearby players are captured automatically, and reports post to Discord with optional role mentions.
- **Finances**: server-wide economy overview (admin and above).

### Team
- **Admins**: grant or change staff roles from the panel. Roles are stored in the database and re-applied as ACE on every connect, so you never need to edit `server.cfg` per staff member.
- **Logs**: searchable in-game log of every admin action, with severity levels, plus Discord webhooks.
- **Admin chat**: a persistent staff-only chat.

### World (mod and above)
- **Teleports**: saved teleport locations, plus teleport to your map marker.
- **Coords**: copy your current coords or teleport to coords.
- **Blips**: create, edit and delete persistent map blips.
- **Spawner**: spawn peds, entities and admin horses, and clear an area.

### Developer (Head Admin / Developer / Owner)
- **Server settings**: close/open the server, kick all players, refresh resources, send announcements, and set time, weather, wind and timescale.
- **Resource lookup**: browse server resources.
- **Master actions**: edit Discord webhook URLs in game (saved to the database and written back into `config.lua`), and add custom inventory items.

### Self tools
Self revive, invisibility, godmode, player blips, and a player ID toggle (txAdmin).

---

## Requirements

| Resource | Notes |
|---|---|
| [rsg-core](https://github.com/Rexshack-RedM/rsg-core) | Framework |
| [ox_lib](https://github.com/overextended/ox_lib) | UI helpers, locales, callbacks |
| [oxmysql](https://github.com/overextended/oxmysql) | Database |
| [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory) | Open inventory, give or clear items |
| [rsg-medic](https://github.com/Rexshack-RedM/rsg-medic) | Revive and heal (`rsg-medic:client:revive` / `rsg-medic:client:heal`) |
| [rsg-log](https://github.com/Rexshack-RedM/rsg-log) | Optional extra logging |

---

## Installation

1. Download the resource and place it in your `resources` folder as `rsg-adminmenu`.
2. **Database**: the tables are created automatically on first start. `install.sql` is provided if you prefer to set the schema up yourself. **Run it at least once** for the reports tables (`admin_reports`, `admin_report_messages`, `admin_report_nearby_players`), because those are not auto-created.
3. Add the following to your `server.cfg` **after** `rsg-core`, `ox_lib` and `oxmysql`:
   ```cfg
   ensure rsg-adminmenu
   ```
4. Give yourself the top role (only needed once; every other role is managed from the **Admins** page):
   ```cfg
   add_principal identifier.license:YOUR_LICENSE group.god
   ```
5. Fill in `shared/config.lua` (see below) and restart the server.

The NUI ships prebuilt in `web/dist`. You only need to rebuild it if you change the React source:
```bash
cd web
npm install
npm run build
```

---

## Usage

| Command | Who | Description |
|---|---|---|
| `/adminmenu` | Staff | Open the admin panel |
| `/report` | Everyone | Open the report/ticket menu |

---

## Roles and permissions

Roles, from lowest to highest:

| Role | Label | Access |
|---|---|---|
| `helper` | Helper | Panel, revive/heal/kill, goto/bring/freeze/spectate, inventory, give item, set job/character fields, XP, reports, coords |
| `mod` | Moderator | + kick, warn, whitelist, troll actions, world tools (teleports, blips, spawner) |
| `admin` | Admin | + ban, give money, finances, clear weapons/items |
| `developer` / `headadmin` | Developer / Head Admin | + server settings, resource lookup, master actions, set permission (`headadmin`) |
| `god` | Owner | Everything |

To change the role an action needs, edit the `permissions` table at the top of `server/server.lua`.

> **Security:** every action is checked on the server. A client that triggers an admin event without permission is **automatically banned** and logged at high severity.

---

## Configuration (`shared/config.lua`)

| Option | Description |
|---|---|
| `Config.EnablePlayerBlips` | Allow staff to toggle player blips on the map |
| `Config.DiscordBot.Token` | Bot token used to look up the admin's real Discord username for the dashboard greeting. The bot does **not** need to be in your server. Leave blank to use the character name |
| `Config.Webhooks.AdminLogs` | Any admin action (kick, ban, teleport, permission changes, etc.) |
| `Config.Webhooks.PlayerManagement` | Player-targeted actions, including give/remove money |
| `Config.Webhooks.WorldSettings` | Server actions, time/weather/wind/timescale and resource changes |
| `Config.Reports.Webhooks` | `Main` webhook, plus optional `Bug`, `Player` and `Question` webhooks (empty = use `Main`) |
| `Config.Reports.Discord` | `EnableRoleMention` and `RolesToMention` (Discord role IDs to ping on new reports) |
| `Config.Reports.WebhookColors` | Embed colours per report type and status |
| `Config.Reports.NearbyDistance` | Radius used to capture players near the reporter (default `50.0`) |
| `Config.Reports.Cooldown` | Seconds between reports per player (default `60`) |
| `Config.AdminHorse` | Horses available in the Spawner (`horsename`, `horsehash`) |
| `Config.DoorHashes` | Door hash lookup table used by the door ID dev tool |

Webhook URLs can also be changed in game from **Master Actions**. They are saved to the database and written back into `config.lua`.

---

## Locales

Translations are in `locales/*.json`: cs, de, el, en, es, fr, hu, it, ja, nl, pl, pt-br and ro. Set your language with ox_lib's `setr ox:locale en` in `server.cfg`.

---

## Support

- [Rexshack-RedM on GitHub](https://github.com/Rexshack-RedM)
- [Buy me a coffee](https://buymeacoffee.com/rexshack)

## License

See [LICENSE](LICENSE).
