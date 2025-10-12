<img width="2948" height="497" alt="rsg_framework" src="https://github.com/user-attachments/assets/638791d8-296d-4817-a596-785325c1b83a" />

# 🎯 rsg-adminmenu
**Admin & developer toolkit for RedM servers using RSG Core.**

![Platform](https://img.shields.io/badge/platform-RedM-darkred)
![License](https://img.shields.io/badge/license-GPL--3.0-green)

> ox_lib–based admin menu with player moderation, finances, server controls, a SQL‑backed reports system (with Discord webhooks), and developer utilities.

---

## 🛠️ Dependencies
- [**rsg-core**](https://github.com/Rexshack-RedM/rsg-core) 🤠
- [**ox_lib**](https://github.com/Rexshack-RedM/ox_lib) ⚙️
- [**oxmysql**](https://github.com/overextended/oxmysql) 🗄️ *(required for the report system)*

**Keybind:** **PGUP** opens the menu (client checks `RSGCore.Shared.Keybinds['PGUP']`) and runs the **`adminmenu`** command.  
**Locales:** `locales/en.json, fr.json, es.json, it.json, el.json, pt-br.json` (loaded via `lib.locale()`).

---

## ✨ Features (detailed)
### 🧭 Admin Menu
- **Self**
  - Teleport to Marker
  - Self Revive
  - Go Invisible (toggle)
  - God Mode (on/off)
  - NoClip (toggle) — uses `txAdmin:menu:noClipToggle`
  - Toggle Player IDs — uses `txAdmin:menu:togglePlayerIDs`
  - **Toggle Player Blips** — see all players on the map (admin-only, real-time updates)
- **Player actions**
  - View Inventory, Player Info
  - Kick, Ban (permanent / temporary)
  - GoTo (teleport to), Bring (teleport here)
  - Freeze / Unfreeze
  - Spectate
  - Give Item
- **Reports System**
  - **Player**
    - Open the report form from the **Admin Menu** or use `/report` if enabled.
    - Choose a **category**: *Bug*, *Player*, or *Question*.
    - Enter a **title** and a **message**, then submit.
    - The report is saved to the database and optionally sent to a Discord webhook.
    - A **cooldown** (default `60s`) prevents spam.
    - The system automatically captures all **nearby players** within the configured radius (`Config.Reports.NearbyDistance`).
  - **Staff**
    - Access the **Reports section** in the Admin Menu.
    - View all reports, **filter by status** (*open*, *claimed*, *resolved*, *closed*).
    - **Claim** or **unclaim** a report to assign yourself or release it.
    - **Add staff notes** directly inside the report.
    - Update report **status**: `open → claimed → resolved / closed`.
    - All reports and notes are stored in SQL tables and synced in real time.

### 💰 Finances
- Add / Remove money on a target player.  

### 🛠️ Developer Tools
- Coordinates helper (copy coordinates in common formats)
- Entity hash viewer
- Door IDs overlay toggle
- Ped / Animal spawner
- Admin Horse quick spawns (list configurable)
- Animations helper (dict/clip runner)

### 🌦️ Server Controls
- Weather presets (commonly used types exposed in the menu)

### 🤪 Troll (permission-gated)
- Wild Attack
- Set On Fire

---

## 📸 Preview
<img width="332" height="595" alt="image" src="https://github.com/user-attachments/assets/e7159b15-b953-421f-86cd-be1d476d9d0a" />

---

## 📜 Example Config

### Reports
```lua
Config = {}

Config.Reports = {
    Webhooks = {
        Main = "YOUR_WEBHOOK_URL_HERE",
        Bug = "",      -- Leave empty to use Main
        Player = "",   -- Leave empty to use Main
        Question = "", -- Leave empty to use Main
    },
    Discord = {
        EnableRoleMention = true, -- Enable/disable Discord role mentions
        -- List of Discord role IDs to mention (add as many as you want)
        RolesToMention = {
            "YOUR_DISCORD_ROLE_ID_HERE", -- Admin role ID
            -- "9876543210987654321", -- Moderator role ID
            -- "1111111111111111111", -- Support role ID
        },
    },
    WebhookColors = {  -- Renamed "Colors" to "WebhookColors"
        bug = 16711680,      -- Red
        player = 16776960,   -- Yellow
        question = 65280,    -- Green
        open = 3447003,      -- Blue
        claimed = 16776960,  -- Yellow
        resolved = 65280,    -- Green
        closed = 10197915,   -- Gray
    },
    NearbyDistance = 50.0, -- Distance (in units) to detect players near the reporter
    Cooldown = 60, -- Cooldown time (in seconds) before being able to create a new report
}
```

### AdminHorse
```lua
Config.AdminHorse = {
    {
         horsename = 'Arabian White',
         horsehash = `a_c_horse_arabian_white`,
    },
    {
         horsename = 'Missouri Foxtrotter',
         horsehash = `a_c_horse_missourifoxtrotter_sablechampagne`,
    },
    {
         horsename = 'Nokota Whiteroan',
         horsehash = `a_c_horse_nokota_whiteroan`,
    },
    {
         horsename = 'Turkoman Gold',
         horsehash = `a_c_horse_turkoman_gold`,
    },
    {
         horsename = 'Thoroughbred',
         horsehash = `a_c_horse_thoroughbred_reversedappleblack`,
    },
}
```

### DoorHashes
```lua
-- Reference list: https://raw.githubusercontent.com/femga/rdr3_discoveries/master/doorHashes/doorhashes.lua
Config.DoorHashes = {
    [123675751] = {123675751,603318791,"p_door_photo02x",2735.5290527344,-1115.708984375,48.100471496582},
    -- ... (long list included in the file)
}
```

---

## 📂 Installation
1. Place `rsg-adminmenu` inside your `resources` (or `resources/[rsg]`) folder.
2. Ensure `rsg-core` and `ox_lib` are installed and started.
3. **Database (Reports):** import `reports.sql`.
4. Edit `config.lua` (webhooks, role mentions, colors, distance, cooldown, admin horses).
5. Add to your `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure rsg-core
   ensure rsg-adminmenu
   ```

---

## 🔐 Permissions (where to configure)
- **Admin actions:** `permissions` table in `server/server.lua` (e.g., `'ban' = 'admin'`, `'goto' = 'admin'`, etc.).
- **Reports (staff):** `reportPermissions` table in `server/server_reports.lua`.
- **ACE **: adjust into your `server.cfg`

---

## 🗄️ SQL (Reports)
`reports.sql` creates the tables:
- `admin_reports` (report metadata and status)
- `admin_report_notes` (staff notes, timestamps, author)
- `admin_report_nearby_players` (snapshot of nearby players)

---

## 🌍 Locales
Provided in `locales/`: `en`, `fr`, `es`, `it`, `el`, `pt-br`.  
Loaded via `lib.locale()` on both client and server.

---

## 💎 Credits
- RSG / Rexshack-RedM and contributors
- Community testers and translators
