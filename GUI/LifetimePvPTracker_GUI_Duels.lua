local UI = LifetimePvPTrackerUI
if not UI then return end

UI.duelRows = UI.duelRows or {}

function UI_RenderDuels()
    for _, r in ipairs(UI.duelRows) do r:Hide() end

    local y = 0
    local idx = 1

    for i = #LifetimePvPTrackerDB.duels, 1, -1 do
        local d = LifetimePvPTrackerDB.duels[i]
        local row = UI.duelRows[idx]

        if not row then
            row = UI.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            UI.duelRows[idx] = row
        end

        row:SetPoint("TOPLEFT", 0, -y)
        row:SetText(
            date("%b %d %Y %I:%M%p", d.time):lower() ..
            " | " .. d.zone ..
            " | " .. d.winner .. " defeated " .. d.loser
        )
        row:Show()

        y = y + 14
        idx = idx + 1
    end

    UI.content:SetHeight(y)
end
