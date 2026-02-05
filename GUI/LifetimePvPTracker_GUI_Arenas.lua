local UI = LifetimePvPTrackerUI
if not UI then return end

UI.arenaRows = UI.arenaRows or {}

function UI_RenderArenas()
    for _, r in ipairs(UI.arenaRows) do r:Hide() end

    local row = UI.arenaRows[1]
    if not row then
        row = UI.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        UI.arenaRows[1] = row
    end

    row:SetPoint("TOPLEFT", 0, 0)
    row:SetText("Arena tracking is enabled in the database; UI display is placeholder for now.")
    row:Show()
    UI.content:SetHeight(20)
end
