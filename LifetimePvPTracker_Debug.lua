-- LifetimePvPTracker_Debug.lua
-- Seeds realistic randomized data into profiles-only DB (version 3)
-- Includes full BG rosters so tooltip player list is populated.

local function GetCharKey()
    return LifetimePvPTracker_GetCharKey()
end

local function EnsureProfilesOnlyDB()
    local settings = (LifetimePvPTrackerDB and LifetimePvPTrackerDB.settings) or nil

    LifetimePvPTrackerDB = {
        version = 1,
        settings = settings or { uiScale = 1.0, uiAlpha = 1.0, debug = true },
        profiles = {},
    }

    LifetimePvPTrackerDB.profiles[GetCharKey()] = {
        nextID = 1,
        battlegrounds = {},
        arenas = {},
        worldPvP = {},
        duels = {},
        activeMatch = nil,
    }
end

local function GetProfile()
    return LifetimePvPTracker_GetProfile()
end

local function ResetProfile(p)
    p.nextID = 1
    p.battlegrounds = {}
    p.arenas = {}
    p.worldPvP = {}
    p.duels = {}
    p.activeMatch = nil
end

local function NextID(p)
    local id = p.nextID or 1
    p.nextID = id + 1
    return id
end

local function ScoreText(a, h)
    if a == nil or h == nil then return nil end
    return string.format("Alliance %d - Horde %d", a, h)
end

-- Internal PRNG
local RNG = { state = 1 }
local function SeedRNG()
    local t = time() or 1
    local gt = (GetTime and GetTime()) or 0
    local mix = t + math.floor(gt * 1000)
    if mix == 0 then mix = 1 end
    RNG.state = mix
end
local function RandU32()
    RNG.state = (1103515245 * RNG.state + 12345) % 2147483647
    return RNG.state
end
local function RandFloat() return RandU32() / 2147483647 end
local function RandInt(a, b)
    if a > b then a, b = b, a end
    return a + math.floor(RandFloat() * (b - a + 1))
end
local function Pick(t) return t[RandInt(1, #t)] end
local function Clamp(n, lo, hi) if n < lo then return lo elseif n > hi then return hi else return n end end

local function MyFactionToken()
    return (UnitFactionGroup("player") == "Alliance") and 1 or 0
end
local function OppFactionToken(myTok) return (myTok == 1) and 0 or 1 end

local ALLY_CLASSES = { "WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID" }
local HORDE_CLASSES = { "WARRIOR","SHAMAN","HUNTER","ROGUE","PRIEST","MAGE","WARLOCK","DRUID" }
local ALLY_RACES = { "HUMAN","DWARF","NIGHTELF","GNOME","DRAENEI" }
local HORDE_RACES = { "ORC","TAUREN","TROLL","UNDEAD","BLOODELF" }

local WPVP_ZONES = {
    { zone="Hillsbrad Foothills", map="Hillsbrad Foothills" },
    { zone="Nagrand", map="Nagrand" },
    { zone="Hellfire Peninsula", map="Hellfire Peninsula" },
    { zone="Terokkar Forest", map="Terokkar Forest" },
    { zone="Zangarmarsh", map="Zangarmarsh" },
    { zone="Netherstorm", map="Netherstorm" },
    { zone="Shadowmoon Valley", map="Shadowmoon Valley" },
}

local ARENA_MAPS = { "Nagrand Arena", "Blade's Edge Arena", "Ruins of Lordaeron" }
local DUEL_ZONES = { "Shattrath City", "Orgrimmar", "Stormwind City", "Nagrand", "Terokkar Forest" }

local function makeEnemyName(prefix, i)
    return prefix .. i .. "-Server"
end

local function makeRandomPlayer(factionTok, i)
    local cls = (factionTok == 1) and Pick(ALLY_CLASSES) or Pick(HORDE_CLASSES)
    local race = (factionTok == 1) and Pick(ALLY_RACES) or Pick(HORDE_RACES)
    local lvl = RandInt(60, 70)
    return {
        name = makeEnemyName((factionTok == 1) and "Ally" or "Horde", 1000 + i),
        class = cls,
        race = race,
        faction = factionTok,
        level = lvl,
        killingBlows = RandInt(0, 12),
        honorableKills = RandInt(0, 25),
        deaths = RandInt(0, 15),
        honor = RandInt(0, 250),
        damage = RandInt(10000, 250000),
        healing = RandInt(0, 180000),
        bgStats = {},
    }
end

local BG_TEMPLATES = {
    { zone="Warsong Gulch", rosterPerSide=10, cols={"Flags Captured","Flags Returned"},
      score=function() local a=RandInt(0,3); local h=RandInt(0,3); while a==h do h=RandInt(0,3) end; return a,h end,
      duration=function() return RandInt(6*60, 25*60) end,
      myObjectives=function() return {["Flags Captured"]=RandInt(0,2),["Flags Returned"]=RandInt(0,6)} end
    },
    { zone="Arathi Basin", rosterPerSide=15, cols={"Bases Assaulted","Bases Defended"},
      score=function() local a=RandInt(800,2000); local h=RandInt(800,2000); while math.abs(a-h)<100 do h=RandInt(800,2000) end; return a,h end,
      duration=function() return RandInt(8*60, 20*60) end,
      myObjectives=function() return {["Bases Assaulted"]=RandInt(0,5),["Bases Defended"]=RandInt(0,8)} end
    },
    { zone="Eye of the Storm", rosterPerSide=15, cols={"Flags Captured","Bases Assaulted","Bases Defended"},
      score=function() local a=RandInt(800,2000); local h=RandInt(800,2000); while math.abs(a-h)<100 do h=RandInt(800,2000) end; return a,h end,
      duration=function() return RandInt(8*60, 22*60) end,
      myObjectives=function() return {["Flags Captured"]=RandInt(0,3),["Bases Assaulted"]=RandInt(0,4),["Bases Defended"]=RandInt(0,6)} end
    },
    { zone="Alterac Valley", rosterPerSide=40, cols={"Graveyards Assaulted","Graveyards Defended","Towers Assaulted","Towers Defended","Mines Captured"},
      score=function() local a=RandInt(0,450); local h=RandInt(0,450); while a==h do h=RandInt(0,450) end; return a,h end,
      duration=function() return RandInt(12*60, 45*60) end,
      myObjectives=function() return {["Graveyards Assaulted"]=RandInt(0,4),["Graveyards Defended"]=RandInt(0,4),["Towers Assaulted"]=RandInt(0,6),["Towers Defended"]=RandInt(0,6),["Mines Captured"]=RandInt(0,2)} end
    },
}

local function SeedDummyData()
    SeedRNG()

    EnsureProfilesOnlyDB()
    LifetimePvPTracker_InitDB()

    local p = GetProfile()
    ResetProfile(p)

    local me = UnitName("player") or "Player"
    local myClass = select(2, UnitClass("player")) or "ROGUE"
    local myRace = select(2, UnitRace("player")) or "NIGHTELF"
    local myTok = MyFactionToken()
    local enemyTok = OppFactionToken(myTok)

    local now = time()
    local span = 14 * 86400

    local function timeWithinSpan(i, n)
        local frac = (n <= 1) and 0 or ((i - 1) / (n - 1))
        return now - span + math.floor(frac * span) + RandInt(-1800, 1800)
    end

    local nBG = RandInt(10, 15)
    local nArena = RandInt(10, 15)
    local nDuel = RandInt(10, 15)
    local nWPVP = RandInt(10, 15)

    -- Battlegrounds (full rosters)
    for i = 1, nBG do
        local tmpl = Pick(BG_TEMPLATES)
        local startTs = timeWithinSpan(i, nBG)
        local dur = tmpl.duration()
        local endTs = startTs + dur
        local scoreA, scoreH = tmpl.score()

        local myScore = (myTok == 1) and scoreA or scoreH
        local oppScore = (myTok == 1) and scoreH or scoreA

        local abandoned = (RandInt(1, 12) == 1)
        local winner = nil
        if not abandoned then
            winner = (myScore > oppScore) and myTok or enemyTok
        end

        local myObj = tmpl.myObjectives()
        for k, _ in pairs(myObj) do if RandInt(1, 4) == 1 then myObj[k] = 0 end end
        local anyNZ = false
        for _, v in pairs(myObj) do if (tonumber(v) or 0) > 0 then anyNZ = true break end end
        if not anyNZ then myObj[tmpl.cols[1]] = RandInt(1, 3) end

        local myEntry = {
            name = me,
            class = myClass,
            race = myRace,
            faction = myTok,
            level = UnitLevel("player") or 60,
            killingBlows = RandInt(0, 12),
            honorableKills = RandInt(0, 25),
            deaths = RandInt(0, 15),
            honor = abandoned and RandInt(0, 60) or RandInt(50, 350),
            damage = RandInt(20000, 250000),
            healing = RandInt(0, 180000),
            bgStats = {},
        }
        for _, col in ipairs(tmpl.cols) do
            myEntry.bgStats[col] = myObj[col] or 0
        end

        local players = {}
        table.insert(players, myEntry)

        -- Fill my side to rosterPerSide (include me already)
        for j = 1, (tmpl.rosterPerSide - 1) do
            local pl = makeRandomPlayer(myTok, i * 100 + j)
            for _, col in ipairs(tmpl.cols) do
                pl.bgStats[col] = RandInt(0, 5)
            end
            table.insert(players, pl)
        end

        -- Fill enemy side
        for j = 1, tmpl.rosterPerSide do
            local pl = makeRandomPlayer(enemyTok, i * 200 + j)
            for _, col in ipairs(tmpl.cols) do
                pl.bgStats[col] = RandInt(0, 5)
            end
            table.insert(players, pl)
        end

        table.insert(p.battlegrounds, {
            id = NextID(p),
            zone = tmpl.zone,
            startTime = startTs,
            endTime = endTs,
            duration = dur,
            abandoned = abandoned,
            abandonReason = abandoned and Pick({ "left", "logout" }) or nil,
            winner = winner,
            scoreAlliance = scoreA,
            scoreHorde = scoreH,
            scoreText = ScoreText(scoreA, scoreH),
            statColumns = tmpl.cols,
            players = players,
        })
    end

    -- Arenas
    local rating = RandInt(1200, 1650)
    local highest = rating
    for i = 1, nArena do
        local ts = timeWithinSpan(i, nArena)
        local bracket = Pick({ "2v2", "3v3", "5v5" })
        local map = Pick(ARENA_MAPS)
        local win = (RandInt(1, 100) <= 52)
        local delta = win and RandInt(8, 16) or -RandInt(8, 18)
        rating = Clamp(rating + delta, 0, 3000)
        if rating > highest then highest = rating end

        table.insert(p.arenas, {
            id = NextID(p),
            time = ts,
            bracket = bracket,
            zone = map,
            result = win and "win" or "loss",
            ratingAfter = rating,
            highestRating = highest,
        })
    end

    -- Duels
    for i = 1, nDuel do
        local ts = timeWithinSpan(i, nDuel)
        local zone = Pick(DUEL_ZONES)
        local opp = makeRandomPlayer(enemyTok, 500 + i)
        local youWin = (RandInt(1, 100) <= 55)

        table.insert(p.duels, {
            id = NextID(p),
            time = ts,
            zone = zone,
            winner = youWin and me or opp.name,
            loser = youWin and opp.name or me,
        })
    end

    -- World PvP (coords)
    for i = 1, nWPVP do
        local ts = timeWithinSpan(i, nWPVP)
        local z = Pick(WPVP_ZONES)
        local opp = makeRandomPlayer(enemyTok, 800 + i)
        local youKilled = (RandInt(1, 100) <= 58)

        local x = math.floor(RandFloat() * 1000) / 1000
        local y = math.floor(RandFloat() * 1000) / 1000
        local honor = youKilled and RandInt(0, 150) or 0

        table.insert(p.worldPvP, {
            id = NextID(p),
            time = ts,
            zone = z.zone,
            map = z.map,
            x = x,
            y = y,
            result = youKilled and "you_killed" or "killed_you",
            honor = honor,
            killer = youKilled and me or opp.name,
            killerClass = youKilled and myClass or opp.class,
            killerRace = youKilled and myRace or opp.race,
            killerFaction = youKilled and myTok or opp.faction,
            victim = youKilled and opp.name or me,
            victimClass = youKilled and opp.class or myClass,
            victimRace = youKilled and opp.race or myRace,
            victimFaction = youKilled and opp.faction or myTok,
        })
    end

    print(string.format(
        "|cff33ff99LPvP Debug: seeded %s with BG:%d Arena:%d Duel:%d WorldPvP:%d. /reload then /lpvp.|r",
        GetCharKey(), nBG, nArena, nDuel, nWPVP
    ))
end

local function WipeProfilesOnly()
    EnsureProfilesOnlyDB()
    LifetimePvPTracker_InitDB()
    print("|cff33ff99LPvP Debug: wiped DB to profiles-only schema (v3). /reload|r")
end

SLASH_LPVPTDEBUG1 = "/lpvpdebug"
SlashCmdList.LPVPTDEBUG = function(msg)
    msg = (msg and string.lower(msg)) or ""
    if msg == "seed" then
        SeedDummyData()
    elseif msg == "wipe" then
        WipeProfilesOnly()
    else
        print("|cff33ff99LPvP Debug commands:|r /lpvpdebug seed  |  /lpvpdebug wipe")
    end
end
