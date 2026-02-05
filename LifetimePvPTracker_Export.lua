LifetimePvPTracker_Export = {}

function LifetimePvPTracker_Export:ToCSV()
    local lines = { "Type,Date,Zone,Details" }

    for _, bg in ipairs(LifetimePvPTrackerDB.battlegrounds or {}) do
        table.insert(lines,
            string.format(
                "BG,%s,%s,%ds",
                date("%Y-%m-%d %H:%M", bg.endTime or time()),
                bg.zone or "Unknown",
                bg.duration or 0
            )
        )
    end

    return table.concat(lines, "\n")
end

-- Simple placeholder (safe). If you want real JSON export, we’ll implement a serializer.
function LifetimePvPTracker_Export:ToJSON()
    return "{ \"note\": \"JSON export not implemented yet\" }"
end
