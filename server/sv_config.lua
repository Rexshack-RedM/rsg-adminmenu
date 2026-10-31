-----------------------------------------------------------------------
-- SERVER-ONLY CONFIG
-- Everything in here stays on the server. Never move these values into
-- shared/config.lua: shared files are downloaded by every player, which
-- would leak your bot token and webhook URLs.
-----------------------------------------------------------------------

-- Used to resolve an admin's real Discord username/avatar for the dashboard.
-- Create an application + bot at https://discord.com/developers/applications
-- and paste its token here. The bot does NOT need to be in your Discord server.
-- Leave blank to fall back to the in-game character name.
Config.DiscordBot = {
    Token = "",
}

-- Webhook URLs can also be edited in game (Developer > Master Actions).
-- Those edits are saved to the database and written back into this file.
Config.Webhooks = {
    AdminLogs = "",        -- any admin action (kick, ban, teleport, permission changes, etc.)
    PlayerManagement = "", -- player-targeted actions, including finances (give/remove money)
    WorldSettings = "",    -- server actions (kick-all, close server, announcements) + time/weather/wind/timescale
}

Config.Reports.Webhooks = {
    Main = "",
    Bug = "",      -- leave empty to use Main
    Player = "",   -- leave empty to use Main
    Question = "", -- leave empty to use Main
}

Config.Reports.Discord = {
    EnableRoleMention = true, -- ping the roles below on new reports
    RolesToMention = {
        -- "123456789012345678", -- Discord role ID
    },
}

Config.Reports.WebhookColors = {
    bug = 16711680,      -- red
    player = 16776960,   -- yellow
    question = 65280,    -- green
    open = 3447003,      -- blue
    claimed = 16776960,  -- yellow
    resolved = 65280,    -- green
    closed = 10197915,   -- grey
}

-- Server-side cooldown (seconds) between report replies from the same player
Config.Reports.ReplyCooldown = 3
