local UI = LifetimePvPTrackerUI
if not UI then return end

UI.worldRows = UI.worldRows or {}
UI.worldZoneRows = UI.worldZoneRows or {}

-- Colors (match your style)
local C_TIME   = "|cffffff00"
local C_GRAY   = "|cffb0b0b0"
local C_WHITE  = "|cffffffff"
local C_TEAL   = "|cff00d1d1"
local C_WIN    = "|cff33ff33"
local C_LOSS   = "|cffff3333"
local RESET    = "|r"

local KILL_ATLAS = "groupfinder-icon-role-large-dps"
local DEATH_ATLAS = "Interface\\Minimap\\ObjectIconsAtlas" -- reliable fallback for death

local function GetProfile()
    return LifetimePvPTracker_GetProfile and LifetimePvPTracker_GetProfile() or nil
end

local function FormatClock(ts)
    return date("%I:%M%p", ts):lower():gsub("^0", "")
end

local function FormatRelativeDay(ts)
    local now = GetServerTime and GetServerTime() or time()
    local today = date("%x", now)
    local d = date("%x", ts)
    if d == today then return "Today" end
    if d == date("%x", now - 86400) then return "Yesterday" end
    return date("%a %b %d", ts)
end

local function SplitNameRealm(full)
    if not full then return "Unknown", nil end
    local n, r = full:match("^([^%-]+)%-(.+)$")
    if n then return n, r end
    return full, nil
end

local function ClassColoredName(name, classToken)
    if _G.ClassColorText and classToken then
        return ClassColorText(name, classToken)
    end
    return name or "Unknown"
end

-- =========================
-- Tooltip helpers (match BG style)
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

local function ShowWorldTooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_CURSOR")
    GameTooltip:ClearLines()

    local whoFull = (e.result == "you_killed") and (e.victim or "Unknown") or (e.killer or "Unknown")
    local name, realm = SplitNameRealm(whoFull)

    local titleName = ClassColoredName(name, e.class)
    GameTooltip:AddLine(C_WHITE .. titleName .. RESET)

    local nTitle = GameTooltip:NumLines()
    local fsTitle = _G["GameTooltipTextLeft" .. nTitle]
    if fsTitle then
        local font, _, flags = GameFontNormalLarge:GetFont()
        fsTitle:SetFont(font, 14, flags)
    end

    if realm then
        GameTooltip:AddLine(C_GRAY .. realm .. RESET)
        SetLineFontSmall(GameTooltip:NumLines())
    end

    GameTooltip:AddLine(C_GRAY .. "[" .. FormatRelativeDay(e.time or time()) .. " " .. FormatClock(e.time or time()) .. "]" .. RESET)
    SetLineFontSmall(GameTooltip:NumLines())

    GameTooltip:AddLine(" ")

    AddHeader("Opponent")
    if e.level then AddKeyValue("Level", e.level) end
    if e.race then AddKeyValue("Race", e.race) end
    if e.class then AddKeyValue("Class", e.class) end

    GameTooltip:AddLine(" ")

    AddHeader("Event")
    AddKeyValue("Result", (e.result == "you_killed") and (C_WIN .. "Kill" .. RESET) or (C_LOSS .. "Death" .. RESET))
    AddKeyValue("Zone", e.zone or "Unknown")

    if e.result == "you_killed" and e.honor and tonumber(e.honor) and tonumber(e.honor) > 0 then
        AddKeyValue("Honor", "+" .. tostring(e.honor))
    end

    GameTooltip:Show()
end

local function HideTooltip()
    GameTooltip:Hide()
end

-- =========================
-- Layout (mirror BG tab)
-- =========================
local function EnsureWorldLayout()
    if UI.worldLeftScroll and UI.worldRightPanel then return end

    if UI.scroll then UI.scroll:Hide() end

    UI.worldLeftScroll = CreateFrame("ScrollFrame", nil, UI.frame, "UIPanelScrollFrameTemplate")
    UI.worldLeftScroll:SetPoint("TOPLEFT", 16, -82)
    UI.worldLeftScroll:SetPoint("BOTTOMLEFT", 16, 16)
    UI.worldLeftScroll:SetWidth(400)

    UI.worldLeftContent = CreateFrame("Frame", nil, UI.worldLeftScroll)
    UI.worldLeftContent:SetSize(1, 1)
    UI.worldLeftScroll:SetScrollChild(UI.worldLeftContent)

    UI.worldRightPanel = CreateFrame("Frame", nil, UI.frame, "BackdropTemplate")
    UI.worldRightPanel:SetPoint("TOPLEFT", UI.worldLeftScroll, "TOPRIGHT", 26, 0)
    UI.worldRightPanel:SetPoint("BOTTOMRIGHT", -20, 16)
    UI.worldRightPanel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    UI.worldRightPanel:SetBackdropColor(0, 0, 0, 0.15)

    UI.worldRightTitle = UI.worldRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    UI.worldRightTitle:SetPoint("TOPLEFT", 12, -10)
    UI.worldRightTitle:SetText(C_TEAL .. "World PvP Summary" .. RESET)

    UI.worldRightSub = UI.worldRightPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UI.worldRightSub:SetPoint("TOPLEFT", UI.worldRightTitle, "BOTTOMLEFT", 0, -4)

    UI.worldRightDivider = UI.worldRightPanel:CreateTexture(nil, "BACKGROUND")
    UI.worldRightDivider:SetHeight(1)
    UI.worldRightDivider:SetPoint("TOPLEFT", UI.worldRightSub, "BOTTOMLEFT", 0, -6)
    UI.worldRightDivider:SetPoint("TOPRIGHT", UI.worldRightPanel, "TOPRIGHT", -12, -54)
    UI.worldRightDivider:SetColorTexture(1, 1, 1, 0.10)
end

local function ShowWorldLayout()
    EnsureWorldLayout()
    UI.worldLeftScroll:Show()
    UI.worldRightPanel:Show()
end

-- =========================
-- Right panel KV rows (Home-style)
-- =========================
local function EnsureZoneRow(i)
    local row = UI.worldZoneRows[i]
    if row then return row end

    row = CreateFrame("Frame", nil, UI.worldRightPanel)
    row:SetHeight(16)

    row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.left:SetPoint("LEFT", 12, 0)
    row.left:SetJustifyH("LEFT")

    row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.right:SetPoint("RIGHT", -12, 0)
    row.right:SetJustifyH("RIGHT")

    UI.worldZoneRows[i] = row
    return row
end

local function SetZoneKV(i, left, right)
    local row = EnsureZoneRow(i)
    row.left:SetText(left or "")
    row.right:SetText(right or "")
    row:Show()
end

-- =========================
-- Build stats
-- =========================
local function BuildWorldStats(events)
    local kills, deaths, honor = 0, 0, 0
    local zoneKills = {}

    for _, e in ipairs(events) do
        local z = e.zone or "Unknown"
        if e.result == "you_killed" then
            kills = kills + 1
            zoneKills[z] = (zoneKills[z] or 0) + 1
            honor = honor + (tonumber(e.honor) or 0)
        elseif e.result == "killed_you" then
            deaths = deaths + 1
        end
    end

    local zones = {}
    for z, c in pairs(zoneKills) do table.insert(zones, { z = z, c = c }) end
    table.sort(zones, function(a, b) return a.c > b.c end)

    local topZone = zones[1] and zones[1].z or "-"
    local topCount = zones[1] and zones[1].c or 0
    local kd = (deaths > 0) and string.format("%.2f", kills / deaths) or tostring(kills)

    return kills, deaths, honor, kd, topZone, topCount, zones
end

-- =========================
-- Main renderer
-- =========================
function UI_RenderWorldPvP()
    ShowWorldLayout()

    local profile = GetProfile()
    local events = (profile and profile.worldPvP) or {}

    for _, r in ipairs(UI.worldRows) do r:Hide() end
    for _, r in ipairs(UI.worldZoneRows) do r:Hide() end

    -- LEFT list
    local y = 0
    local idx = 1

    for i = #events, 1, -1 do
        local e = events[i]
        local row = UI.worldRows[idx]

        if not row then
            row = CreateFrame("Button", nil, UI.worldLeftContent)
            row:SetSize(370, 16)
            row:EnableMouse(true)

            row.icon = row:CreateTexture(nil, "OVERLAY")
            row.icon:SetSize(14, 14)
            row.icon:SetPoint("LEFT", 0, 0)

            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetJustifyH("LEFT")

            row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
            UI.worldRows[idx] = row
        end

        row:SetPoint("TOPLEFT", 0, -y)

        local endTs = e.time or time()
        local day = FormatRelativeDay(endTs)
        local clock = FormatClock(endTs)

        local whoFull = (e.result == "you_killed") and (e.victim or "Unknown") or (e.killer or "Unknown")
        local whoName = (select(1, SplitNameRealm(whoFull)))
        local whoColored = ClassColoredName(whoName, e.class)

        local zone = e.zone or "Unknown"

        local resultColor = (e.result == "you_killed") and C_WIN or C_LOSS

        local lvlText = ""
        if e.level and tonumber(e.level) then
            lvlText = C_GRAY .. "[" .. tostring(e.level) .. "] " .. RESET
        end

        local honorText = ""
        if e.result == "you_killed" and e.honor and tonumber(e.honor) and tonumber(e.honor) > 0 then
            honorText = C_TEAL .. " (+" .. tostring(e.honor) .. ")" .. RESET
        end

        if e.result == "you_killed" then
            if row.icon.SetAtlas then
                row.icon:SetAtlas(KILL_ATLAS, true)
                row.icon:SetSize(12, 12)
            else
                -- Fallback if atlas API isn't available for some reason
                row.icon:SetTexture("Interface\\Minimap\\ObjectIconsAtlas")
                row.icon:SetTexCoord(1, 1, 1, 1)
            end
        else
            row.icon:SetTexture(DEATH_TEXTURE)
            row.icon:SetTexCoord(0.974609375, 0.998046875, 0.001953125, 0.033203125)
        end

        row.text:SetText(
            C_TIME .. "[" .. day .. " " .. clock .. "]" .. RESET .. " " ..
            lvlText .. whoColored .. RESET ..
            C_GRAY .. " @ " .. zone .. RESET ..
            honorText
        )

        row:SetScript("OnEnter", function(self) ShowWorldTooltip(self, e) end)
        row:SetScript("OnLeave", HideTooltip)

        row:Show()
        y = y + 16
        idx = idx + 1
    end

    UI.worldLeftContent:SetHeight(y + 10)

    -- RIGHT summary
    local kills, deaths, honor, kd, topZone, topCount, zones = BuildWorldStats(events)

    UI.worldRightSub:SetText(
        C_GRAY .. "Kills: " .. RESET .. C_WHITE .. kills .. RESET ..
        C_GRAY .. " | Deaths: " .. RESET .. C_WHITE .. deaths .. RESET ..
        C_GRAY .. " | K/D: " .. RESET .. C_WHITE .. kd .. RESET ..
        C_GRAY .. " | Honor: " .. RESET .. C_TEAL .. honor .. RESET
    )

    -- Key/Value rows (Home style)
    local baseY = -70
    local line = 1

    local function PlaceRow(i, yOff)
        local row = EnsureZoneRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", UI.worldRightPanel, "TOPLEFT", 0, yOff)
        row:SetPoint("TOPRIGHT", UI.worldRightPanel, "TOPRIGHT", 0, yOff)
        return row
    end

    PlaceRow(line, baseY); SetZoneKV(line, C_WHITE .. "Most Active Zone:" .. RESET, C_WHITE .. topZone .. RESET .. C_GRAY .. " (" .. topCount .. ")" .. RESET)
    line = line + 1

    PlaceRow(line, baseY - (line - 1) * 16); SetZoneKV(line, C_WHITE .. "Total Kills:" .. RESET, C_WHITE .. kills .. RESET); line = line + 1
    PlaceRow(line, baseY - (line - 1) * 16); SetZoneKV(line, C_WHITE .. "Total Deaths:" .. RESET, C_WHITE .. deaths .. RESET); line = line + 1
    PlaceRow(line, baseY - (line - 1) * 16); SetZoneKV(line, C_WHITE .. "K/D Ratio:" .. RESET, C_WHITE .. kd .. RESET); line = line + 1
    PlaceRow(line, baseY - (line - 1) * 16); SetZoneKV(line, C_WHITE .. "Total Honor:" .. RESET, C_TEAL .. honor .. RESET); line = line + 1

    PlaceRow(line, baseY - (line - 1) * 16)
    SetZoneKV(line, C_TEAL .. "Kills per Zone" .. RESET, "")
    line = line + 1

    for i = 1, math.min(10, #zones) do
        PlaceRow(line, baseY - (line - 1) * 16)
        SetZoneKV(line, C_GRAY .. zones[i].z .. ":" .. RESET, C_WHITE .. zones[i].c .. RESET)
        line = line + 1
    end
end
