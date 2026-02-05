LifetimePvPTracker_Stats = {}

local function DateKey(ts)
    return date("%Y-%m-%d", ts or time())
end

local function Ensure(tbl, key, default)
    if not tbl[key] then tbl[key] = default end
    return tbl[key]
end

local function Num(v)
    local n = tonumber(v)
    return n or 0
end

local function IsProbablyCorruptScoreRow(p)
    if type(p.killingBlows) == "string" then return true end
    if type(p.honorableKills) == "string" then return true end
    if type(p.deaths) == "number" and p.deaths > 500 then return true end
    return false
end

local function IsLocalPlayerScoreboardName(scoreboardName, me)
    if not scoreboardName or not me then return false end
    if scoreboardName == me then return true end
    return string.sub(scoreboardName, 1, #me) == me
end

function LifetimePvPTracker_Stats:Build()
    local me = UnitName("player") or "Unknown"
    local myFaction = UnitFactionGroup("player")
    local profile = LifetimePvPTracker_GetProfile()

    local stats = {
        player = {
            name = me,
            totals = {
                pvpKills = 0,
                pvpDeaths = 0,
                lifetimeHonorGained = 0,
                battlegrounds = { games = 0, wins = 0, losses = 0, duration = 0 },
                arenas = { wins = 0, losses = 0, highestRating = 0 },
                duels = { wins = 0, losses = 0 },
            },
        },
        activity = {},
        opponents = {},
    }

    -- Battlegrounds (you-only)
    for _, bg in ipairs(profile.battlegrounds or {}) do
        stats.player.totals.battlegrounds.games = stats.player.totals.battlegrounds.games + 1
        stats.player.totals.battlegrounds.duration = stats.player.totals.battlegrounds.duration + Num(bg.duration)

        if bg.abandoned then
            stats.player.totals.battlegrounds.losses = stats.player.totals.battlegrounds.losses + 1
        else
            if bg.winner == myFaction or bg.winner == ((myFaction == "Alliance") and 1 or 0) then
                stats.player.totals.battlegrounds.wins = stats.player.totals.battlegrounds.wins + 1
            else
                stats.player.totals.battlegrounds.losses = stats.player.totals.battlegrounds.losses + 1
            end
        end

        for _, p in ipairs(bg.players or {}) do
            if p.name and IsLocalPlayerScoreboardName(p.name, me) then
                if not IsProbablyCorruptScoreRow(p) then
                    stats.player.totals.pvpKills = stats.player.totals.pvpKills + Num(p.killingBlows)
                    stats.player.totals.pvpDeaths = stats.player.totals.pvpDeaths + Num(p.deaths)
                    stats.player.totals.lifetimeHonorGained = stats.player.totals.lifetimeHonorGained + Num(p.honor)
                end
            end
        end
    end

    -- World PvP
    for _, e in ipairs(profile.worldPvP or {}) do
        local day = DateKey(e.time)
        local zone = e.zone or "Unknown"

        local dayEntry = Ensure(stats.activity, day, { zones = {} })
        local zoneEntry = Ensure(dayEntry.zones, zone, { kills = 0, deaths = 0, honor = 0 })

        local honor = Num(e.honor)

        if e.result == "you_killed" then
            stats.player.totals.pvpKills = stats.player.totals.pvpKills + 1
            zoneEntry.kills = zoneEntry.kills + 1
            zoneEntry.honor = zoneEntry.honor + honor
            stats.player.totals.lifetimeHonorGained = stats.player.totals.lifetimeHonorGained + honor
        elseif e.result == "killed_you" then
            stats.player.totals.pvpDeaths = stats.player.totals.pvpDeaths + 1
            zoneEntry.deaths = zoneEntry.deaths + 1
        end
    end

    -- Arenas
    for _, a in ipairs(profile.arenas or {}) do
        local result = a.result
        if type(result) == "string" then result = string.lower(result) end
        if result == "win" or a.win == true then
            stats.player.totals.arenas.wins = stats.player.totals.arenas.wins + 1
        elseif result == "loss" or a.win == false then
            stats.player.totals.arenas.losses = stats.player.totals.arenas.losses + 1
        end

        local r = Num(a.highestRating)
        if r == 0 then r = Num(a.ratingAfter) end
        if r > stats.player.totals.arenas.highestRating then
            stats.player.totals.arenas.highestRating = r
        end
    end

    -- Duels
    for _, d in ipairs(profile.duels or {}) do
        if d.winner == me then
            stats.player.totals.duels.wins = stats.player.totals.duels.wins + 1
        elseif d.loser == me then
            stats.player.totals.duels.losses = stats.player.totals.duels.losses + 1
        end
    end

    return stats
end
