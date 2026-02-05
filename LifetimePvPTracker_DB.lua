LifetimePvPTrackerDB = LifetimePvPTrackerDB or {}

DB_VERSION = 1

local function NormalizeRealm(realm)
    if not realm or realm == "" then return "UnknownRealm" end
    return (realm:gsub("%s+", ""))
end

function LifetimePvPTracker_GetCharKey()
    local name = UnitName("player") or "Unknown"
    local realm = NormalizeRealm((GetRealmName and GetRealmName()) or "UnknownRealm")
    return name .. "-" .. realm
end

local function EnsureProfile(charKey)
    LifetimePvPTrackerDB.profiles = LifetimePvPTrackerDB.profiles or {}
    LifetimePvPTrackerDB.profiles[charKey] = LifetimePvPTrackerDB.profiles[charKey] or {
        nextID = 1,
        battlegrounds = {},
        arenas = {},
        worldPvP = {},
        duels = {},
        activeMatch = nil,
    }
    return LifetimePvPTrackerDB.profiles[charKey]
end

function LifetimePvPTracker_GetProfile()
    local key = LifetimePvPTracker_GetCharKey()
    return EnsureProfile(key)
end

function LifetimePvPTracker_InitDB()
    LifetimePvPTrackerDB.version = DB_VERSION

    -- global settings
    LifetimePvPTrackerDB.settings = LifetimePvPTrackerDB.settings or {}
    LifetimePvPTrackerDB.settings.uiScale = LifetimePvPTrackerDB.settings.uiScale or 1.0
    LifetimePvPTrackerDB.settings.uiAlpha = LifetimePvPTrackerDB.settings.uiAlpha or 1.0

    local profile = LifetimePvPTracker_GetProfile()

    -- migrate flat v2 → profile if profile empty
    local hasFlat =
        type(LifetimePvPTrackerDB.battlegrounds) == "table" or
        type(LifetimePvPTrackerDB.arenas) == "table" or
        type(LifetimePvPTrackerDB.worldPvP) == "table" or
        type(LifetimePvPTrackerDB.duels) == "table" or
        LifetimePvPTrackerDB.activeMatch ~= nil or
        LifetimePvPTrackerDB.nextID ~= nil

    if hasFlat then
        local profileEmpty =
            (#profile.battlegrounds == 0) and
            (#profile.arenas == 0) and
            (#profile.worldPvP == 0) and
            (#profile.duels == 0) and
            (profile.activeMatch == nil)

        if profileEmpty then
            if type(LifetimePvPTrackerDB.battlegrounds) == "table" then profile.battlegrounds = LifetimePvPTrackerDB.battlegrounds end
            if type(LifetimePvPTrackerDB.arenas) == "table" then profile.arenas = LifetimePvPTrackerDB.arenas end
            if type(LifetimePvPTrackerDB.worldPvP) == "table" then profile.worldPvP = LifetimePvPTrackerDB.worldPvP end
            if type(LifetimePvPTrackerDB.duels) == "table" then profile.duels = LifetimePvPTrackerDB.duels end
            if LifetimePvPTrackerDB.activeMatch then profile.activeMatch = LifetimePvPTrackerDB.activeMatch end
            if LifetimePvPTrackerDB.nextID then profile.nextID = LifetimePvPTrackerDB.nextID end
        end

        -- remove flat keys so we stop mixing
        LifetimePvPTrackerDB.battlegrounds = nil
        LifetimePvPTrackerDB.arenas = nil
        LifetimePvPTrackerDB.worldPvP = nil
        LifetimePvPTrackerDB.duels = nil
        LifetimePvPTrackerDB.activeMatch = nil
        LifetimePvPTrackerDB.nextID = nil
    end
end

function LifetimePvPTracker_GetNextID()
    local p = LifetimePvPTracker_GetProfile()
    local id = p.nextID or 1
    p.nextID = id + 1
    return id
end
