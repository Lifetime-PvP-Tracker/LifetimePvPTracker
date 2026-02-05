local UI = LifetimePvPTrackerUI
if not UI then return end

UI.activityRows = UI.activityRows or {}

function UI_RenderActivity()
    if UI.scroll then UI.scroll:Show() end

    for _, r in ipairs(UI.activityRows) do r:Hide() end

    local y = 0
    local idx = 1

    local stats = LifetimePvPTracker_Stats and LifetimePvPTracker_Stats.Build and LifetimePvPTracker_Stats:Build()
    local activity = stats and stats.activity or {}

    local days = {}
    for dayKey, _ in pairs(activity) do table.insert(days, dayKey) end
    table.sort(days, function(a, b) return a > b end)

    local function line(text)
        local row = UI.activityRows[idx]
        if not row then
            row = UI.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            UI.activityRows[idx] = row
        end
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetText(text)
        row:Show()
        y = y + 14
        idx = idx + 1
    end

    line("|cff00d1d1Daily Activity (placeholder)|r")
    y = y + 6

    for _, dayKey in ipairs(days) do
        local dayEntry = activity[dayKey]
        local zones = dayEntry.zones or {}
        local kills, deaths, honor = 0, 0, 0

        for _, z in pairs(zones) do
            kills = kills + (z.kills or 0)
            deaths = deaths + (z.deaths or 0)
            honor = honor + (z.honor or 0)
        end

        line(dayKey .. "  |  K: " .. kills .. "  D: " .. deaths .. "  H: " .. honor)
    end

    UI.content:SetHeight(y + 10)
end
