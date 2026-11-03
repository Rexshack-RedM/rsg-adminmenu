-- Server-only settings. Anything in shared/config.lua is downloaded by every
-- client, so the bot token and webhook URLs live here instead.

-- Used to resolve an admin's real Discord username for the "Hey, {name}" dashboard greeting.
-- Create an application + bot at https://discord.com/developers/applications, copy its token
-- here. The bot does NOT need to be invited to your Discord server for this lookup to work.
-- Leave blank to fall back to the in-game character name instead.
Config.DiscordBot = {
    Token = "",
}

-- Webhook URLs can also be changed in game from Master Actions (saved to the
-- database and written back into this file).
Config.Webhooks = {
    AdminLogs = "",        -- any admin action (kick, ban, teleport, permission changes, etc.)
    PlayerManagement = "", -- player-targeted actions, including finances (give/remove money)
    WorldSettings = "",    -- server actions (kick-all, close server, announcements) + time/weather/wind/timescale/resource changes
}

Config.Reports.Webhooks = {
    Main = "",
    Bug = "",      -- Leave empty to use Main
    Player = "",   -- Leave empty to use Main
    Question = "", -- Leave empty to use Main
}
