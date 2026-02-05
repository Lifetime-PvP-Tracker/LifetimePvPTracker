local UI = LifetimePvPTrackerUI
if not UI then return end

UI.bgRows = UI.bgRows or {}
UI.bgSummaryRows = UI.bgSummaryRows or {}

-- Colors
local C_TIME   = "|cffffff00"
local C_HONOR  = "|cff00d1d1"
local C_WIN    = "|cff33ff33"
local C_LOSS   = "|cffff3333"
local C_GRAY   = "|cffb0b0b0"
local C_WHITE  = "|cffffffff"
local C_TEAL   = "|cff00d1d1"
local C_ALLI   = "|cff4fa3ff"
local C_HORDE  = "|cffff4f4f"
local RESET    = "|r"

local ALLI_ICON  = "|TInterface\\WorldStateFrame\\AllianceIcon:14:14:0:0|t"
local HORDE_ICON = "|TInterface\\WorldStateFrame\\HordeIcon:14:14:0:0|t"
local DESERTER_ICON = "|TInterface\\Icons\\Ability_Druid_Cower:16:16:0:0|t"

-- ✅ BG icons (from you)
local AB_ICON   = "|TInterface\\Icons\\Inv_Jewelry_Amulet_07:16:16:0:0|t"
local AV_ICON   = "|TInterface\\Icons\\Inv_Jewelry_Necklace_21:16:16:0:0|t"
local EOTS_ICON = "|TInterface\\Icons\\Spell_Nature_Eyeofthestorm:16:16:0:0|t"
local WSG_ICON  = "|TInterface\\Icons\\Inv_Misc_Rune_07:16:16:0:0|t"

local function GetBGIcon(zone)
    if zone == "Arathi Basin" then return AB_ICON end
    if zone == "Alterac Valley" then return AV_ICON end
    if zone == "Eye of the Storm" then return EOTS_ICON end
    if zone == "Warsong Gulch" then return WSG_ICON end
    return ""
end

local CLASS_COLORS = RAID_CLASS_COLORS

local function GetProfile()
    return LifetimePvPTracker_GetProfile()
end

local function MyFactionToken()
    return (UnitFactionGroup("player") == "Alliance") and 1 or 0
end

-- =========================
-- Shared helpers
-- =========================
local function ClassColorText(text, classToken)
    text = tostring(text or "")
    local c = (classToken and CLASS_COLORS[classToken]) or { r = 1, g = 1, b = 1 }
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, text)
end

local function FormatClock(ts)
    return date("%I:%M%p", ts):lower():gsub("^0", "")
end

local function FormatRelativeDay(ts)
    local today = date("%x", GetServerTime())
    local d = date("%x", ts)
    if d == today then return "Today" end
    if d == date("%x", GetServerTime() - 86400) then return "Yesterday" end
    return date("%a %b %d", ts)
end

local function FormatDuration(seconds)
    seconds = tonumber(seconds) or 0
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%dm %02ds", m, s)
end

-- ✅ Updated to support numeric winner (0/1) AND legacy string winner
local function IsWin(bg)
    if bg.winner == nil then return false end
    if type(bg.winner) == "number" then
        return bg.winner == MyFactionToken()
    elseif type(bg.winner) == "string" then
        return bg.winner == UnitFactionGroup("player")
    end
    return false
end

local function GetMyBGStats(bg)
    local me = UnitName("player")
    if not me then return nil end
    for _, p in ipairs(bg.players or {}) do
        if p.name and string.sub(p.name, 1, #me) == me then
            return p
        end
    end
    if bg.players and bg.players[1] then return bg.players[1] end
    return nil
end

-- =========================
-- Tooltip helpers (YOUR ORIGINAL LOGIC, preserved)
-- =========================
local function SetLineFontSmall(lineIndex)
    local lfs = _G["GameTooltipTextLeft" .. lineIndex]
    local rfs = _G["GameTooltipTextRight" .. lineIndex]
    local font, _, flags = GameFontHighlightSmall:GetFont()
    if lfs then lfs:SetFont(font, 11, flags) end
    if rfs then rfs:SetFont(font, 11, flags) end
end

local function AddKeyValue(left, right)
    GameTooltip:AddDoubleLine(C_WHITE .. left .. RESET, C_WHITE .. tostring(right or "-") .. RESET, 1, 1, 1, 1, 1, 1)
    SetLineFontSmall(GameTooltip:NumLines())
end

local function AddHeader(text)
    GameTooltip:AddLine(C_TEAL .. text .. RESET)
    local n = GameTooltip:NumLines()
    local fs = _G["GameTooltipTextLeft" .. n]
    if fs then
        local font, _, flags = GameFontNormalLarge:GetFont()
        fs:SetFont(font, 14, flags)
    end
end

local function ShouldShowObjective(v)
    if v == nil then return false end
    local n = tonumber(v)
    if n ~= nil then return n ~= 0 end
    if type(v) == "string" then return v ~= "" and v ~= "0" end
    return true
end

local function ShowBGTooltip(owner, bg)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()

    local endTs = bg.endTime or bg.startTime or time()
    local startTs = bg.startTime or endTs

    -- optional: include icon in tooltip title (nice touch)
    local icon = GetBGIcon(bg.zone)
    GameTooltip:AddLine(C_WHITE .. (icon ~= "" and (icon .. " ") or "") .. (bg.zone or "Battleground") .. RESET)

    local nTitle = GameTooltip:NumLines()
    local fsTitle = _G["GameTooltipTextLeft" .. nTitle]
    if fsTitle then
        local font, _, flags = GameFontNormalLarge:GetFont()
        fsTitle:SetFont(font, 14, flags)
    end

    GameTooltip:AddLine(C_GRAY .. "[" .. FormatRelativeDay(endTs) .. " " .. FormatClock(endTs) .. "]" .. RESET)
    SetLineFontSmall(GameTooltip:NumLines())
    GameTooltip:AddLine(" ")

    AddHeader("Match Details")

    if bg.abandoned then
        AddKeyValue("Result", C_LOSS .. DESERTER_ICON .. RESET)
        AddKeyValue("Reason", bg.abandonReason or "unknown")
    else
        local resultText = IsWin(bg) and (C_WIN .. "Win" .. RESET) or (C_LOSS .. "Loss" .. RESET)
        AddKeyValue("Result", resultText)
    end

    AddKeyValue("Entered", FormatRelativeDay(startTs) .. " " .. FormatClock(startTs))
    AddKeyValue("Left", FormatRelativeDay(endTs) .. " " .. FormatClock(endTs))

    local dur = bg.duration
    if not dur and bg.startTime and bg.endTime then dur = bg.endTime - bg.startTime end
    AddKeyValue("Duration", dur and FormatDuration(dur) or "-")

    if bg.scoreAlliance ~= nil and bg.scoreHorde ~= nil then
        AddKeyValue("Final Score", ALLI_ICON .. " " .. tostring(bg.scoreAlliance) .. "  -  " .. HORDE_ICON .. " " .. tostring(bg.scoreHorde))
    elseif bg.scoreText then
        AddKeyValue("Final Score", bg.scoreText)
    end

    local my = GetMyBGStats(bg)
    if my then
        local honorTotal = tonumber(bg.honorTotal)
        if honorTotal then
            AddKeyValue("Honor Gained", honorTotal)
        else
            AddKeyValue("Honor Gained", tonumber(my.honor) or 0)
        end
    end

    if my then
        GameTooltip:AddLine(" ")
        AddHeader("Your Scoreboard")

        AddKeyValue("Killing Blows", tonumber(my.killingBlows) or 0)
        AddKeyValue("Honorable Kills", tonumber(my.honorableKills) or 0)
        AddKeyValue("Deaths", tonumber(my.deaths) or 0)

        if my.damage ~= nil then AddKeyValue("Damage Done", tonumber(my.damage) or 0) end
        if my.healing ~= nil then AddKeyValue("Healing Done", tonumber(my.healing) or 0) end

        if bg.statColumns and my.bgStats then
            for _, colName in ipairs(bg.statColumns) do
                local v = my.bgStats[colName]
                if ShouldShowObjective(v) then
                    AddKeyValue(colName, v)
                end
            end
        end
    end

    if bg.players and #bg.players > 0 then
        local alliance, horde = {}, {}
        for _, p in ipairs(bg.players) do
            if p.faction == 1 then table.insert(alliance, p)
            elseif p.faction == 0 then table.insert(horde, p)
            else table.insert(alliance, p) end
        end

        table.sort(alliance, function(a, b) return (a.name or "") < (b.name or "") end)
        table.sort(horde, function(a, b) return (a.name or "") < (b.name or "") end)

        GameTooltip:AddLine(" ")
        AddHeader("Players")

        GameTooltip:AddDoubleLine(C_ALLI .. ALLI_ICON .. " Alliance" .. RESET, C_HORDE .. HORDE_ICON .. " Horde" .. RESET)
        SetLineFontSmall(GameTooltip:NumLines())

        local maxRows = math.max(#alliance, #horde)
        for i = 1, maxRows do
            local left, right = "", ""
            if alliance[i] then
                local p = alliance[i]
                left = ClassColorText(p.name or "Unknown", p.class)
            end
            if horde[i] then
                local p = horde[i]
                right = ClassColorText(p.name or "Unknown", p.class)
            end
            GameTooltip:AddDoubleLine(left, right)
            SetLineFontSmall(GameTooltip:NumLines())
        end
    end

    GameTooltip:Show()
end

local function HideBGTooltip()
    GameTooltip:Hide()
end

-- =========================
-- Layout
-- =========================
local function EnsureBGLayout()
    if UI.bgLeftScroll and UI.bgRightPanel then return end

    if UI.scroll then UI.scroll:Hide() end

    UI.bgLeftScroll = CreateFrame("ScrollFrame", nil, UI.frame, "UIPanelScrollFrameTemplate")
    UI.bgLeftScroll:SetPoint("TOPLEFT", 16, -82)
    UI.bgLeftScroll:SetPoint("BOTTOMLEFT", 16, 16)
    UI.bgLeftScroll:SetWidth(400)

    UI.bgLeftContent = CreateFrame("Frame", nil, UI.bgLeftScroll)
    UI.bgLeftContent:SetSize(1, 1)
    UI.bgLeftScroll:SetScrollChild(UI.bgLeftContent)

    UI.bgRightPanel = CreateFrame("Frame", nil, UI.frame, "BackdropTemplate")
    UI.bgRightPanel:SetPoint("TOPLEFT", UI.bgLeftScroll, "TOPRIGHT", 26, 0)
    UI.bgRightPanel:SetPoint("BOTTOMRIGHT", -20, 16)
    UI.bgRightPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    UI.bgRightPanel:SetBackdropColor(0, 0, 0, 0.15)

    UI.bgRightTitle = UI.bgRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    UI.bgRightTitle:SetPoint("TOPLEFT", 12, -10)
    UI.bgRightTitle:SetText(C_TEAL .. "Battleground Summary" .. RESET)

    UI.bgRightSub = UI.bgRightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UI.bgRightSub:SetPoint("TOPLEFT", UI.bgRightTitle, "BOTTOMLEFT", 0, -4)

    UI.bgRightDivider = UI.bgRightPanel:CreateTexture(nil, "BACKGROUND")
    UI.bgRightDivider:SetHeight(1)
    UI.bgRightDivider:SetPoint("TOPLEFT", UI.bgRightSub, "BOTTOMLEFT", 0, -6)
    UI.bgRightDivider:SetPoint("TOPRIGHT", UI.bgRightPanel, "TOPRIGHT", -12, -54)
    UI.bgRightDivider:SetColorTexture(1, 1, 1, 0.10)
end

local function ShowBGLayout()
    EnsureBGLayout()
    UI.bgLeftScroll:Show()
    UI.bgRightPanel:Show()
end

-- =========================
-- Summary (profiles)
-- =========================
local function BuildSummary()
    local profile = GetProfile()
    local out = {}
    local totalWins, totalLosses, totalAbandons = 0, 0, 0

    for _, bg in ipairs(profile.battlegrounds or {}) do
        local zone = bg.zone or "Unknown"
        out[zone] = out[zone] or { zone = zone, wins = 0, losses = 0, abandons = 0, total = 0 }
        out[zone].total = out[zone].total + 1

        if bg.abandoned then
            out[zone].abandons = out[zone].abandons + 1
            out[zone].losses = out[zone].losses + 1
            totalAbandons = totalAbandons + 1
            totalLosses = totalLosses + 1
        else
            if IsWin(bg) then
                out[zone].wins = out[zone].wins + 1
                totalWins = totalWins + 1
            else
                out[zone].losses = out[zone].losses + 1
                totalLosses = totalLosses + 1
            end
        end
    end

    return out, totalWins, totalLosses, totalAbandons
end

local function EnsureSummaryRow(i)
    local row = UI.bgSummaryRows[i]
    if row then return row end

    row = CreateFrame("Frame", nil, UI.bgRightPanel)
    row:SetHeight(44)

    row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.title:SetPoint("TOPLEFT", 8, -2)

    row.stats = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.stats:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)

    row.line = row:CreateTexture(nil, "BACKGROUND")
    row.line:SetHeight(1)
    row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 0)
    row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 0)
    row.line:SetColorTexture(1, 1, 1, 0.08)

    UI.bgSummaryRows[i] = row
    return row
end

local function RenderSummaryPanel()
    local summary, totalWins, totalLosses, totalAbandons = BuildSummary()

    local denom = (totalWins + totalLosses)
    local winPct = (denom > 0) and math.floor((totalWins / denom) * 100 + 0.5) or 0
    local winColor = (winPct >= 50) and C_WIN or C_LOSS

    UI.bgRightSub:SetText(
        C_GRAY .. "Overall W/L: " .. RESET .. C_WIN .. totalWins .. RESET .. C_GRAY .. "/" .. RESET .. C_LOSS .. totalLosses .. RESET ..
        C_GRAY .. " | Win%: " .. RESET .. winColor .. winPct .. "%" .. RESET ..
        C_GRAY .. " | Total: " .. RESET .. C_WHITE .. denom .. RESET ..
        C_GRAY .. " | " .. RESET .. DESERTER_ICON .. " " .. C_WHITE .. totalAbandons .. RESET
    )

    local list = {}
    for _, v in pairs(summary) do table.insert(list, v) end
    table.sort(list, function(a, b) return (a.zone or "") < (b.zone or "") end)

    for _, r in ipairs(UI.bgSummaryRows) do r:Hide() end

    local y = -78
    local idx = 1
    for _, s in ipairs(list) do
        local row = EnsureSummaryRow(idx)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", UI.bgRightPanel, "TOPLEFT", 12, y)
        row:SetPoint("TOPRIGHT", UI.bgRightPanel, "TOPRIGHT", -12, y)
        row:Show()

        local d = (s.wins + s.losses)
        local pct = (d > 0) and math.floor((s.wins / d) * 100 + 0.5) or 0
        local pctColor = (pct >= 50) and C_WIN or C_LOSS

        local icon = GetBGIcon(s.zone)
        row.title:SetText(C_WHITE .. icon .. " " .. s.zone .. RESET)

        local abIconPart = (s.abandons > 0) and (C_GRAY .. " | " .. RESET .. DESERTER_ICON .. " " .. C_WHITE .. s.abandons .. RESET) or ""

        row.stats:SetText(
            C_GRAY .. "W/L: " .. RESET .. C_WIN .. s.wins .. RESET .. C_GRAY .. "/" .. RESET .. C_LOSS .. s.losses .. RESET ..
            C_GRAY .. " | Win%: " .. RESET .. pctColor .. pct .. "%" .. RESET ..
            C_GRAY .. " | Total: " .. RESET .. C_WHITE .. s.total .. RESET ..
            abIconPart
        )

        -- ✅ Ensure divider is visible for each row
        if row.line then row.line:Show() end

        y = y - 48
        idx = idx + 1
    end
end

-- =========================
-- BG tab renderer (profiles)
-- =========================
function UI_RenderBattlegrounds()
    ShowBGLayout()

    local profile = GetProfile()

    for _, r in ipairs(UI.bgRows) do r:Hide() end

    local y = 0
    local idx = 1

    for i = #profile.battlegrounds, 1, -1 do
        local bg = profile.battlegrounds[i]

        local row = UI.bgRows[idx]
        if not row then
            row = CreateFrame("Button", nil, UI.bgLeftContent)
            row:SetSize(370, 16)
            row:EnableMouse(true)

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", 0, 0)
            row.text:SetJustifyH("LEFT")

            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            UI.bgRows[idx] = row
        end

        row:SetPoint("TOPLEFT", 0, -y)

        local endTs = bg.endTime or bg.startTime or time()
        local day = FormatRelativeDay(endTs)
        local clock = FormatClock(endTs)

        local my = GetMyBGStats(bg)
        local honor = my and tonumber(my.honor) or 0

        local icon = GetBGIcon(bg.zone)

        local resultText, resultColor
        if bg.abandoned then
            resultText = DESERTER_ICON
            resultColor = C_LOSS
        else
            resultText = IsWin(bg) and "Win" or "Loss"
            resultColor = IsWin(bg) and C_WIN or C_LOSS
        end

        row.text:SetText(
            C_TIME .. "[" .. day .. " " .. clock .. "]" .. RESET .. " " ..
            icon .. " " .. (bg.zone or "Battleground") .. " " ..
            C_HONOR .. "(+" .. honor .. " Honor)" .. RESET .. " " ..
            resultColor .. (bg.abandoned and DESERTER_ICON or resultText) .. RESET
        )

        row:SetScript("OnEnter", function(self) ShowBGTooltip(self, bg) end)
        row:SetScript("OnLeave", HideBGTooltip)

        row:Show()
        y = y + 16
        idx = idx + 1
    end

    UI.bgLeftContent:SetHeight(y + 10)
    RenderSummaryPanel()
end
