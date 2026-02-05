-- LifetimePvPTracker.lua
-- Core tracking / DB / events

local ADDON_NAME = ...
LifetimePvPTrackerDB = LifetimePvPTrackerDB or {}

-- =========================================================
-- Debug
-- =========================================================
local function _Settings()
    LifetimePvPTrackerDB.settings = LifetimePvPTrackerDB.settings or { uiScale = 1.0, uiAlpha = 1.0, debug = false }
    return LifetimePvPTrackerDB.settings
end

function DBG(fmt, ...)
    if not (_Settings().debug) then return end
    local msg = string.format(fmt, ...)
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99LPvP|r " .. msg)
end

-- =========================================================
-- Honor currency helper
-- =========================================================
local function GetHonorCurrency()
    if C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
        local info = C_CurrencyInfo.GetCurrencyInfo(1901)
        if info and info.quantity then return tonumber(info.quantity) or 0 end
    end
    if GetCurrencyInfo then
        local _, amount = GetCurrencyInfo(1901)
        if amount then return tonumber(amount) or 0 end
    end
    return 0
end

local function IsMyName(scoreName)
    if not scoreName then return false end
    local myName, myRealm = UnitName("player")
    if not myName then return false end

    local base = scoreName:match("^([^%-]+)")
    if base == myName then return true end
    if myRealm and myRealm ~= "" then
        return scoreName == (myName .. "-" .. myRealm)
    end
    return false
end

local function StripRealm(n)
    if not n then return nil end
    return n:match("^([^%-]+)") or n
end

-- =========================================================
-- Profile / DB helpers
-- =========================================================
function LifetimePvPTracker_GetCharKey()
    local name, realm = UnitName("player")
    realm = realm or GetRealmName() or "Unknown"
    name = name or "Unknown"
    return name .. "-" .. realm
end

-- Ensure fields exist even for older SavedVariables
local function EnsureProfileDefaults(p)
    if not p then return end
    p.nextID = p.nextID or 1
    p.battlegrounds = p.battlegrounds or {}
    p.arenas = p.arenas or {}
    p.worldPvP = p.worldPvP or {}
    p.duels = p.duels or {}
    p.opponents = p.opponents or {} -- for nemesis/rival later
    if p.activeMatch == nil then p.activeMatch = nil end
end

function LifetimePvPTracker_InitDB()
    LifetimePvPTrackerDB.version = DB_VERSION
    LifetimePvPTrackerDB.settings = LifetimePvPTrackerDB.settings or { uiScale = 1.0, uiAlpha = 1.0, debug = false }
    LifetimePvPTrackerDB.profiles = LifetimePvPTrackerDB.profiles or {}

    local key = LifetimePvPTracker_GetCharKey()
    if not LifetimePvPTrackerDB.profiles[key] then
        LifetimePvPTrackerDB.profiles[key] = {
            nextID = 1,
            battlegrounds = {},
            arenas = {},
            worldPvP = {},
            duels = {},
            opponents = {},
            activeMatch = nil,
        }
    end

    -- IMPORTANT: also backfill defaults for existing profiles
    EnsureProfileDefaults(LifetimePvPTrackerDB.profiles[key])
end

function LifetimePvPTracker_GetProfile()
    LifetimePvPTracker_InitDB()
    local p = LifetimePvPTrackerDB.profiles[LifetimePvPTracker_GetCharKey()]
    -- Extra safety (in case callers access before init on some clients)
    EnsureProfileDefaults(p)
    return p
end

local function NextID(p)
    local id = p.nextID or 1
    p.nextID = id + 1
    return id
end

-- =========================================================
-- Instance helpers
-- =========================================================
local function IsInBattleground()
    local _, t = IsInInstance()
    return t == "pvp"
end

local function GetZoneNameSafe()
    local z = GetRealZoneText()
    if z and z ~= "" then return z end
    return GetZoneText() or "Unknown"
end

local function GetBGZoneName()
    local name, instanceType = GetInstanceInfo()
    if instanceType == "pvp" and name and name ~= "" then
        return name
    end
    return nil
end

local function IsInArena()
    local _, t = IsInInstance()
    return t == "arena"
end

local function IsWorldContext()
    local _, t = IsInInstance()
    return (t == "none" or t == "world")
end

-- =========================================================
-- Class normalization
-- =========================================================
local CLASS_NAME_TO_TOKEN = {}
do
    local t = LOCALIZED_CLASS_NAMES_MALE or LOCALIZED_CLASS_NAMES_FEMALE
    if t then
        for token, loc in pairs(t) do
            CLASS_NAME_TO_TOKEN[loc] = token
        end
    end
end

local function NormalizeClassToken(classToken, className)
    if classToken and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classToken] then
        return classToken
    end
    if className and CLASS_NAME_TO_TOKEN[className] then
        return CLASS_NAME_TO_TOKEN[className]
    end
    if type(className) == "string" then
        local up = className:upper()
        if RAID_CLASS_COLORS and RAID_CLASS_COLORS[up] then return up end
    end
    return classToken or className
end

-- =========================================================
-- Honor parsing
-- =========================================================
local function ParseHonorFromMsg(msg)
    local n = msg and msg:match("(%d+)")
    return n and tonumber(n) or nil
end

-- =========================================================
-- Scoreboard snapshot
-- =========================================================
local function GetScoreFactionWinner()
    if GetBattlefieldWinner then
        return GetBattlefieldWinner()
    end
    return nil
end

local function CaptureScoreboardPlayers(m)
    if not m then return end

    local num = GetNumBattlefieldScores and GetNumBattlefieldScores() or 0
    if num <= 0 then return end

    local prevByName = {}
    if m.players then
        for _, pl in ipairs(m.players) do
            if pl and pl.name then
                prevByName[pl.name] = pl
            end
        end
    end

    m.players = {}
    local statColumns = {}

    if GetNumBattlefieldStats and GetBattlefieldStatInfo then
        local nStats = GetNumBattlefieldStats()
        if nStats and nStats > 0 then
            for i = 1, nStats do
                local col = GetBattlefieldStatInfo(i)
                if col and col ~= "" then
                    table.insert(statColumns, col)
                end
            end
        end
    end

    if #statColumns == 0 and m.statColumns then
        statColumns = m.statColumns
    end

    for i = 1, num do
        local s = { GetBattlefieldScore(i) }

        local name        = s[1]
        local kb          = s[2]
        local hk          = s[3]
        local deaths      = s[4]
        local honor       = s[5]
        local faction     = s[6]
        local rank        = s[7]
        local race        = s[8]
        local className   = s[9]
        local classToken  = s[10]
        local damageDone  = s[11]
        local healingDone = s[12]

        local dmg = tonumber(damageDone) or 0
        local heal = tonumber(healingDone) or 0
        if dmg == 0 and heal > 0 then dmg, heal = heal, dmg end

        local p = {
            name = name,
            killingBlows = tonumber(kb) or 0,
            honorableKills = tonumber(hk) or 0,
            deaths = tonumber(deaths) or 0,
            honor = tonumber(honor) or 0,
            faction = faction,
            rank = rank,
            race = race,
            class = NormalizeClassToken(classToken, className),
            damage = dmg,
            healing = heal,
            bgStats = {},
        }

        if #statColumns > 0 and GetBattlefieldStatData then
            for sidx = 1, #statColumns do
                local v = GetBattlefieldStatData(i, sidx)
                p.bgStats[statColumns[sidx]] = tonumber(v) or 0
            end
        elseif prevByName[name] then
            p.bgStats = prevByName[name].bgStats or {}
        end

        table.insert(m.players, p)
    end

    if #statColumns > 0 then
        m.statColumns = statColumns
    end
end

local function CaptureSnapshot(tag)
    local p = LifetimePvPTracker_GetProfile()
    if not p or not p.activeMatch then return end
    local m = p.activeMatch

    if IsInBattleground() and not m.zoneLocked then
        local z = GetBGZoneName()
        if z then
            m.zone = z
            m.zoneLocked = true
        end
    end

    local w = GetScoreFactionWinner()
    if w ~= nil then m.winner = w end

    CaptureScoreboardPlayers(m)
end

-- =========================================================
-- Commit match
-- =========================================================
local function CommitMatch(m, reason)
    if not m or m._committed then return end

    local p = LifetimePvPTracker_GetProfile()
    m._committed = true
    m.endTime = m.endTime or time()
    m.duration = m.duration or (m.endTime - (m.startTime or m.endTime))

    m.postHonor = m.postHonor or GetHonorCurrency()
    if m.preHonor and m.postHonor then
        m.honorTotal = math.max(0, m.postHonor - m.preHonor)
    else
        m.honorTotal = m.honorFromChat or 0
    end

    if m.honorTotal and m.players then
        for _, pl in ipairs(m.players) do
            if IsMyName(pl.name) then
                pl.honor = m.honorTotal
                break
            end
        end
    end

    table.insert(p.battlegrounds, m)
    p.activeMatch = nil
end

-- =========================================================
-- Match lifecycle
-- =========================================================
local function StartBGMatch(zone)
    local p = LifetimePvPTracker_GetProfile()
    p.activeMatch = {
        id = NextID(p),
        zone = zone,
        zoneLocked = false,
        startTime = time(),
        players = {},
        statColumns = {},
        preHonor = GetHonorCurrency(),
        honorFromChat = 0,
    }
end

local function EnsureActiveBGMatch()
    local p = LifetimePvPTracker_GetProfile()
    if p.activeMatch then return end
    StartBGMatch(GetBGZoneName() or GetZoneNameSafe())
end

local function FinalizeIfLeftBG()
    local p = LifetimePvPTracker_GetProfile()
    local m = p.activeMatch
    if not m or IsInBattleground() then return end

    m.endTime = m.endTime or time()
    m.postHonor = m.postHonor or GetHonorCurrency()
    m.abandoned = (m.winner == nil) or nil
    CommitMatch(m, "left-bg")
end

-- =========================================================
-- Zone checking
-- =========================================================
local function CheckZone()
    local _, t = IsInInstance()
    if t == "pvp" then
        EnsureActiveBGMatch()
    else
        FinalizeIfLeftBG()
    end
end

-- =========================================================
-- World PvP tracking
-- =========================================================
local band = (bit and bit.band) or (bit32 and bit32.band)

local function IsPlayerFlag(flags)
    if not band then return false end
    if not flags then return false end
    if not COMBATLOG_OBJECT_TYPE_PLAYER then return false end
    return band(flags, COMBATLOG_OBJECT_TYPE_PLAYER) > 0
end

-- Cache player info when we CAN see it (target/mouseover).
local seenPlayers = {}

local function CacheUnit(unit)
    if not UnitExists or not UnitExists(unit) then return end
    if not UnitIsPlayer or not UnitIsPlayer(unit) then return end

    local name, realm = UnitName(unit)
    if not name or name == "" then return end
    local full = name
    if realm and realm ~= "" then
        full = name .. "-" .. realm
    end

    local _, classToken = UnitClass(unit)
    local race = UnitRace(unit)
    local lvl = UnitLevel(unit)
    if type(lvl) ~= "number" or lvl <= 0 then lvl = nil end

    local info = {
        full = full,
        class = classToken,
        race = race,
        level = lvl,
        ts = time(),
    }

    seenPlayers[name] = info
    seenPlayers[full] = info
end

local function GetPlayerCoords()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                local x, y = pos:GetXY()
                if x and y then
                    return mapID, x, y
                end
            end
        end
    end

    if SetMapToCurrentZone and GetPlayerMapPosition then
        SetMapToCurrentZone()
        local x, y = GetPlayerMapPosition("player")
        if x and y then
            return nil, x, y
        end
    end

    return nil, nil, nil
end

local pendingWorldKillIndex = nil
local pendingWorldKillTime = nil

local lastHonorAmount = nil
local lastHonorTime = nil

local function AttachCachedInfo(e, playerName)
    if not e or not playerName then return end
    local base = StripRealm(playerName)
    local info = seenPlayers[playerName] or (base and seenPlayers[base]) or nil
    if info then
        e.level = e.level or info.level
        e.class = e.class or info.class
        e.race  = e.race  or info.race

        if info.full and info.full ~= "" then
            if e.victim and e.result == "you_killed" then e.victim = info.full end
            if e.killer and e.result == "killed_you" then e.killer = info.full end
        end
    end
end

local function LogWorldPvPKill(victimName, victimGUID)
    local profile = LifetimePvPTracker_GetProfile()
    if not profile then return end
    profile.worldPvP = profile.worldPvP or {}

    local mapID, x, y = GetPlayerCoords()

    local e = {
        time = time(),
        zone = GetZoneNameSafe(),
        mapID = mapID,
        x = x,
        y = y,
        result = "you_killed",
        victim = victimName or "Unknown",
        victimGUID = victimGUID,
        honor = 0,
    }

    AttachCachedInfo(e, victimName)

    if lastHonorAmount and lastHonorTime and (time() - lastHonorTime) <= 2 then
        e.honor = (e.honor or 0) + (tonumber(lastHonorAmount) or 0)
    end

    table.insert(profile.worldPvP, e)
    pendingWorldKillIndex = #profile.worldPvP
    pendingWorldKillTime = e.time
end

local function LogWorldPvPDeath(killerName, killerGUID)
    local profile = LifetimePvPTracker_GetProfile()
    if not profile then return end
    profile.worldPvP = profile.worldPvP or {}

    local mapID, x, y = GetPlayerCoords()

    local e = {
        time = time(),
        zone = GetZoneNameSafe(),
        mapID = mapID,
        x = x,
        y = y,
        result = "killed_you",
        killer = killerName or "Unknown",
        killerGUID = killerGUID,
    }

    AttachCachedInfo(e, killerName)
    table.insert(profile.worldPvP, e)
end

local function HandleCombatLog()
    if not IsWorldContext() then return end
    if IsInBattleground() or IsInArena() then return end

    local timestamp, subevent, hideCaster,
        srcGUID, srcName, srcFlags, srcRaidFlags,
        dstGUID, dstName, dstFlags, dstRaidFlags

    if CombatLogGetCurrentEventInfo then
        timestamp, subevent, hideCaster,
            srcGUID, srcName, srcFlags, srcRaidFlags,
            dstGUID, dstName, dstFlags, dstRaidFlags = CombatLogGetCurrentEventInfo()
    else
        timestamp = arg1
        subevent  = arg2
        srcGUID   = arg4
        srcName   = arg5
        srcFlags  = arg6
        dstGUID   = arg8
        dstName   = arg9
        dstFlags  = arg10
    end

    if subevent ~= "PARTY_KILL" then return end

    local meGUID = UnitGUID("player")

    if srcGUID == meGUID and IsPlayerFlag(dstFlags) then
        LogWorldPvPKill(dstName, dstGUID)
        return
    end

    if dstGUID == meGUID and IsPlayerFlag(srcFlags) then
        LogWorldPvPDeath(srcName, srcGUID)
        return
    end
end

-- =========================================================
-- Duel Tracking (SAFE: only logs YOUR duels)
-- =========================================================

local function _EscapePattern(s)
    return (s:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

local function _BuildDuelPattern(globalString)
    if not globalString or globalString == "" then return nil end
    local p = _EscapePattern(globalString)
    p = p:gsub("%%s", "(.+)")
    return "^" .. p .. "$"
end

-- Build a small list of acceptable duel winner patterns (varies by client / punctuation / localization)
local _DUEL_PATTERNS = {}

do
    local p1 = _BuildDuelPattern(_G.DUEL_WINNER_KNOCKOUT)
    if p1 then table.insert(_DUEL_PATTERNS, p1) end

    local p2 = _BuildDuelPattern(_G.DUEL_WINNER) -- some clients use DUEL_WINNER
    if p2 then table.insert(_DUEL_PATTERNS, p2) end

    -- Safe English fallback with OPTIONAL period at end
    table.insert(_DUEL_PATTERNS, "^(.+) has defeated (.+) in a duel%.?$")
end

local function _StripColorCodes(s)
    if not s then return s end
    -- Remove WoW color codes and reset codes
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return s
end

local function _MatchAnyDuelPattern(msg)
    if not msg then return nil end
    msg = _StripColorCodes(msg)

    for _, pat in ipairs(_DUEL_PATTERNS) do
        local w, l = msg:match(pat)
        if w and l then return w, l end
    end
    return nil, nil
end

local function _BaseName(full)
    if not full then return nil end
    return full:match("^([^%-]+)") or full
end

local function _FullNameFromUnit(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return nil end
    local n, r = UnitName(unit)
    if not n or n == "" then return nil end
    if r and r ~= "" then return n .. "-" .. r end
    return n
end

local function _GetPlayerCoords()
    if C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition then
        local mapID = C_Map.GetBestMapForUnit("player")
        if mapID then
            local pos = C_Map.GetPlayerMapPosition(mapID, "player")
            if pos then
                local x, y = pos:GetXY()
                return mapID, x, y
            end
        end
    end
    if SetMapToCurrentZone and GetPlayerMapPosition then
        SetMapToCurrentZone()
        local x, y = GetPlayerMapPosition("player")
        return nil, x, y
    end
    return nil, nil, nil
end

local function _EnsureOpponentRecord(profile, oppName)
    profile.opponents = profile.opponents or {}
    local rec = profile.opponents[oppName]
    if not rec then
        rec = { name = oppName, wins = 0, losses = 0, total = 0 }
        profile.opponents[oppName] = rec
    end
    return rec
end

local function _AttachDuelCachedInfo(d, opponentName)
    if not d or not opponentName then return end
    local base = StripRealm(opponentName)
    local info = seenPlayers[opponentName] or (base and seenPlayers[base]) or nil
    if info then
        d.opponentLevel = d.opponentLevel or info.level
        d.opponentRace  = d.opponentRace  or info.race
        d.opponentClass = d.opponentClass or info.class
        if info.full and info.full ~= "" then
            d.opponent = info.full
        end
    end
end

local function _StartDuel(profile)
    local mapID, x, y = _GetPlayerCoords()
    local oppGuess = _FullNameFromUnit("target") or _FullNameFromUnit("mouseover") or "Unknown"

    profile._activeDuel = {
        startTime = time(),
        zone = GetRealZoneText() or GetZoneText() or "Unknown",
        mapID = mapID,
        x = x, y = y,
        opponent = oppGuess,
        winner = nil,
        confirmed = false,
        opponentLevel = nil,
        opponentRace = nil,
        opponentClass = nil,
    }

    DBG("Duel Started - ", oppGuess)

    if oppGuess and oppGuess ~= "Unknown" then
        _AttachDuelCachedInfo(profile._activeDuel, oppGuess)
    end
end

local function _CommitDuel(profile)
    local d = profile._activeDuel
    if not d or not d.confirmed then
        profile._activeDuel = nil
        return
    end

    d.endTime = time()
    d.duration = (d.endTime - (d.startTime or d.endTime))

    profile.duels = profile.duels or {}
    table.insert(profile.duels, d)

    local opp = d.opponent or "Unknown"
    local rec = _EnsureOpponentRecord(profile, opp)

    rec.total = (rec.total or 0) + 1
    rec.lastTime = d.endTime
    rec.lastZone = d.zone
    rec.lastMapID = d.mapID
    rec.lastX = d.x
    rec.lastY = d.y

    if d.winner == "player" then
        rec.wins = (rec.wins or 0) + 1
    else
        rec.losses = (rec.losses or 0) + 1
    end

    if d.opponentLevel then rec.level = d.opponentLevel end
    if d.opponentRace then rec.race = d.opponentRace end
    if d.opponentClass then rec.class = d.opponentClass end

    DBG("Duel Committed - ", opp)

    profile._activeDuel = nil
end

-- =========================================================
-- Events
-- =========================================================
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_LEAVING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("UPDATE_BATTLEFIELD_SCORE")
f:RegisterEvent("CHAT_MSG_COMBAT_HONOR_GAIN")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
f:RegisterEvent("DUEL_REQUESTED")
f:RegisterEvent("DUEL_FINISHED")
f:RegisterEvent("CHAT_MSG_SYSTEM")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN" then
        LifetimePvPTracker_InitDB()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        CheckZone()
        return
    end

    if event == "PLAYER_LEAVING_WORLD" then
        CaptureSnapshot("leaving_world")
        return
    end

    if event == "UPDATE_BATTLEFIELD_SCORE" then
        if RequestBattlefieldScoreData then
            RequestBattlefieldScoreData()
        end
        CaptureSnapshot("score_event")
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLog()
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        CacheUnit("target")
        return
    end

    if event == "UPDATE_MOUSEOVER_UNIT" then
        CacheUnit("mouseover")
        return
    end

    if event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        local amt = ParseHonorFromMsg(arg1)
        if not amt or amt <= 0 then return end

        lastHonorAmount = amt
        lastHonorTime = time()

        local p = LifetimePvPTracker_GetProfile()
        if p and p.activeMatch and IsInBattleground() then
            p.activeMatch.honorFromChat = (p.activeMatch.honorFromChat or 0) + amt
        end

        if IsWorldContext() and not IsInBattleground() and not IsInArena() and pendingWorldKillIndex and pendingWorldKillTime then
            if (time() - pendingWorldKillTime) > 25 then
                pendingWorldKillIndex = nil
                pendingWorldKillTime = nil
            else
                if p and p.worldPvP and p.worldPvP[pendingWorldKillIndex] then
                    local e = p.worldPvP[pendingWorldKillIndex]
                    if e and e.result == "you_killed" and (time() - pendingWorldKillTime) <= 20 then
                        e.honor = (e.honor or 0) + amt
                    end
                end
            end
        end

        return
    end

    -- =========================
    -- Duel events
    -- =========================
    if event == "DUEL_REQUESTED" then
        DBG("Duel Requested")
        local p = LifetimePvPTracker_GetProfile and LifetimePvPTracker_GetProfile() or nil
        if p then
            _StartDuel(p)
        end
        return
    end

    if event == "DUEL_FINISHED" then
        DBG("Duel Finished 1")
        local p = LifetimePvPTracker_GetProfile and LifetimePvPTracker_GetProfile() or nil
        if p and p._activeDuel and not p._activeDuel.confirmed then
            p._activeDuel = nil
        end
        return
    end

    if event == "CHAT_MSG_SYSTEM" then
        DBG("Duel Finished 2")
        local msg = arg1
        DBG("ARG", arg1)
        if msg then
        DBG("Duel Finished 3")
            local winnerName, loserName = _MatchAnyDuelPattern(msg)
            if winnerName and loserName then
                local me = UnitName("player")
                local wBase = _BaseName(winnerName)
                local lBase = _BaseName(loserName)

                if me and (wBase == me or lBase == me) then
                    local p = LifetimePvPTracker_GetProfile and LifetimePvPTracker_GetProfile() or nil
                    if p then
                        if not p._activeDuel then
                            _StartDuel(p)
                        end

                        local d = p._activeDuel
                        d.confirmed = true

                        if wBase == me then
                            d.winner = me
                            d.opponent = loserName
                        else
                            d.winner = loserName
                            d.opponent = winnerName
                        end

                        _AttachDuelCachedInfo(d, d.opponent)
                        _CommitDuel(p)
                    end
                    return
                end
            end
        end
    end
end)

-- =========================================================
-- Public helpers
-- =========================================================
function LifetimePvPTracker_GetBattlegrounds()
    local p = LifetimePvPTracker_GetProfile()
    return p and p.battlegrounds or {}
end

function LifetimePvPTracker_GetActiveMatch()
    local p = LifetimePvPTracker_GetProfile()
    return p and p.activeMatch or nil
end
