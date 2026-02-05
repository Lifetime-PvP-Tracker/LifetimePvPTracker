local UI = LifetimePvPTrackerUI
if not UI then return end

UI.duelRows = UI.duelRows or {}
UI.duelStatsRows = UI.duelStatsRows or {}

-- -----------------------------------------
-- Small helpers
-- -----------------------------------------
local function SafePercent(num, den)
    if not den or den <= 0 then return "0%" end
    return string.format("%d%%", math.floor((num / den) * 100 + 0.5))
end

local function FormatDuration(sec)
    sec = tonumber(sec) or 0
    if sec <= 0 then return "0s" end
    if sec < 60 then return string.format("%ds", sec) end
    local m = math.floor(sec / 60)
    local s = sec % 60
    if m < 60 then return string.format("%dm %ds", m, s) end
    local h = math.floor(m / 60)
    m = m % 60
    return string.format("%dh %dm", h, m)
end

local function EnsureStatRow(parent, index)
    UI.duelStatsRows[index] = UI.duelStatsRows[index] or {}
    local row = UI.duelStatsRows[index]

    if row.frame and row.frame:GetParent() ~= parent then
        row.frame:SetParent(parent)
    end

    if not row.frame then
        row.frame = CreateFrame("Frame", nil, parent)
        row.frame:SetHeight(16)

        row.left = row.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.left:SetPoint("LEFT", 0, 0)
        row.left:SetJustifyH("LEFT")

        row.right = row.frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.right:SetPoint("RIGHT", 0, 0)
        row.right:SetJustifyH("RIGHT")
    end

    row.frame:Show()
    return row
end

local function SetStatRow(parent, index, label, value, y)
    local row = EnsureStatRow(parent, index)
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", 0, -y)
    row.frame:SetPoint("TOPRIGHT", 0, -y)
    row.left:SetText(label or "")
    row.right:SetText(value or "")
    return row
end

local function HideExtraStatRows(fromIndex)
    for i = fromIndex, #UI.duelStatsRows do
        local row = UI.duelStatsRows[i]
        if row and row.frame then row.frame:Hide() end
    end
end

-- Creates/reuses a clickable row so we can attach tooltip scripts (FontStrings can’t OnEnter)
local function EnsureLogRow(parent, index)
    UI.duelRows[index] = UI.duelRows[index] or {}
    local row = UI.duelRows[index]

    if row.btn and row.btn:GetParent() ~= parent then
        row.btn:SetParent(parent)
        if row.text then row.text:SetParent(row.btn) end
    end

    if not row.btn then
        row.btn = CreateFrame("Button", nil, parent)
        row.btn:SetHeight(16)
        row.btn:SetPoint("LEFT", 0, 0)
        row.btn:SetPoint("RIGHT", 0, 0)

        row.text = row.btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", 0, 0)
        row.text:SetJustifyH("LEFT")

        row.btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    end

    row.btn:Show()
    return row
end

local function HideExtraLogRows(fromIndex)
    for i = fromIndex, #UI.duelRows do
        local row = UI.duelRows[i]
        if row and row.btn then row.btn:Hide() end
    end
end

-- -----------------------------------------
-- Tooltip
-- -----------------------------------------
local function ShowDuelTooltip(rowData)
    if not rowData then return end

    GameTooltip:SetOwner(UI.frame or UI.content, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()

    local opponent = rowData.opponent or "Unknown"
    local zone = rowData.zone or "Unknown"
    local when = rowData.startTime or rowData.time or time()

    local outcome
    if rowData.winner == "player" then
        outcome = "Win"
    elseif rowData.winner == "opponent" then
        outcome = "Loss"
    else
        outcome = "Duel"
    end

    GameTooltip:AddLine(opponent, 1, 1, 1)
    GameTooltip:AddLine(string.format("%s  •  %s", outcome, zone), 0.9, 0.9, 0.9)
    GameTooltip:AddLine(date("%b %d %Y %I:%M%p", when):lower(), 0.7, 0.7, 0.7)

    if rowData.opponentLevel or rowData.opponentRace or rowData.opponentClass then
        local parts = {}
        if rowData.opponentLevel then table.insert(parts, "Level " .. tostring(rowData.opponentLevel)) end
        if rowData.opponentRace then table.insert(parts, tostring(rowData.opponentRace)) end
        if rowData.opponentClass then table.insert(parts, tostring(rowData.opponentClass)) end
        if #parts > 0 then
            GameTooltip:AddLine(table.concat(parts, "  •  "), 0.9, 0.85, 0.6)
        end
    end

    if rowData.duration then
        GameTooltip:AddLine("Duration: " .. FormatDuration(rowData.duration), 0.8, 0.8, 0.8)
    end

    -- Coords intentionally NOT shown (stored for heatmap later)
    -- But show if debugging
    if LifetimePvPTrackerDB and LifetimePvPTrackerDB.settings and LifetimePvPTrackerDB.settings.debug then
        if rowData.mapID or (rowData.x and rowData.y) then
            GameTooltip:AddLine(string.format("map=%s  x=%.3f  y=%.3f",
                tostring(rowData.mapID),
                tonumber(rowData.x) or 0,
                tonumber(rowData.y) or 0
            ), 0.6, 0.6, 0.6)
        end
    end

    GameTooltip:Show()
end

-- -----------------------------------------
-- Main render
-- -----------------------------------------
function UI_RenderDuels()
    for _, r in ipairs(UI.duelRows) do
        r:Hide()
    end

    local y = 0
    local idx = 1

    -- Duels are per-profile
    local profile = LifetimePvPTracker_GetProfile and LifetimePvPTracker_GetProfile() or nil
    local duels = (profile and profile.duels) or {}

    for i = #duels, 1, -1 do
        local d = duels[i]
        local row = UI.duelRows[idx]

        if not row then
            -- IMPORTANT: store the frame itself in UI.duelRows so ClearAllTabRows can call :Hide()
            row = CreateFrame("Button", nil, UI.content)
            row:SetHeight(16)
            row:SetPoint("LEFT", 0, 0)
            row:SetPoint("RIGHT", 0, 0)
            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 0, 0)
            row.text:SetJustifyH("LEFT")

            UI.duelRows[idx] = row
        end

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", 0, -y)

        local t = d.startTime or d.time or time()
        local zone = d.zone or "Unknown"
        local opp = d.opponent or "Unknown"

        local outcome
        if d.winner == "player" then
            outcome = "You defeated " .. opp
        elseif d.winner == "opponent" then
            outcome = opp .. " defeated You"
        else
            outcome = "Duel vs " .. opp
        end

        row.text:SetText(
            date("%b %d %Y %I:%M%p", t):lower() ..
            " | " .. zone ..
            " | " .. outcome
        )

        -- Tooltip (optional but nice)
        row:SetScript("OnEnter", function()
            GameTooltip:SetOwner(row, "ANCHOR_CURSOR")
            GameTooltip:ClearLines()
            GameTooltip:AddLine(opp, 1, 1, 1)
            GameTooltip:AddLine(zone, 0.9, 0.9, 0.9)
            if d.duration then
                GameTooltip:AddLine("Duration: " .. tostring(d.duration) .. "s", 0.8, 0.8, 0.8)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)

        row:Show()

        y = y + 16
        idx = idx + 1
    end

    UI.content:SetHeight(y)
end
