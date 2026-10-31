Config = {}

Config.EnablePlayerBlips = true

-- Webhooks, the Discord bot token and other secrets live in server/sv_config.lua
-- (server-only, never sent to players).
Config.Reports = {
    NearbyDistance = 50.0, -- Distance (in units) to detect players near the reporter
    Cooldown = 60, -- Cooldown time (in seconds) before being able to create a new report
}
