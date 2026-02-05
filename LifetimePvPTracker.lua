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

local function DBG(fmt, ...)
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
            activeMatch = nil,
        }
    end
end

function LifetimePvPTracker_GetProfile()
    LifetimePvPTracker_InitDB()
    return LifetimePvPTrackerDB.profiles[LifetimePvPTracker_GetCharKey()]
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
    -- In TBC clients, outdoor world is often "none".
    -- If your anniversary client returns "world", allow that too.
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

-- Cache player info when we CAN see it (target/mouseover). World kills often don't let you query level/class later.
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

    -- Key by base name and by full name (if we have realm).
    seenPlayers[name] = info
    seenPlayers[full] = info
end

local function GetPlayerCoords()
    -- Preferred modern API.
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

    -- Fallback (older API).
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

        -- If we learned a realm'd name later, keep the nicer full string for display.
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
        honor = 0, -- filled by chat association
        -- level/class/race filled from cache if possible
    }

    AttachCachedInfo(e, victimName)

    -- Sometimes the honor message lands right before/after the kill event; attach if extremely recent.
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
        -- level/class/race filled from cache if possible
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

    -- You killed a player in the world.
    if srcGUID == meGUID and IsPlayerFlag(dstFlags) then
        LogWorldPvPKill(dstName, dstGUID)
        return
    end

    -- A player killed you in the world.
    if dstGUID == meGUID and IsPlayerFlag(srcFlags) then
        LogWorldPvPDeath(srcName, srcGUID)
        return
    end
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
f:RegisterEvent("WHO_LIST_UPDATE")

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

        -- BG honor fallback
        local p = LifetimePvPTracker_GetProfile()
        if p and p.activeMatch and IsInBattleground() then
            p.activeMatch.honorFromChat = (p.activeMatch.honorFromChat or 0) + amt
        end

        -- World PvP honor association:
        -- Attach honor to the most recent world kill if it happened very recently.
        if IsWorldContext() and not IsInBattleground() and not IsInArena() and pendingWorldKillIndex and pendingWorldKillTime then
            -- Expire stale pending kill.
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
