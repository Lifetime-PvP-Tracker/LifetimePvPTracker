LifetimePvPTracker_Heatmap = {}

function LifetimePvPTracker_Heatmap:Build()
    local zones = {}

    for _, bg in ipairs(LifetimePvPTrackerDB.battlegrounds or {}) do
        local z = bg.zone or "Unknown"
        zones[z] = (zones[z] or 0) + 1
    end

    for _, e in ipairs(LifetimePvPTrackerDB.worldPvP or {}) do
        local z = e.zone or "Unknown"
        zones[z] = (zones[z] or 0) + 1
    end

    return zones
end
