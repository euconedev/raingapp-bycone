local trackRaceStatsCache = {}
local topRacerWinnersCache = {}

local function getCacheKey(datespanDays)
    return tostring(datespanDays)
end

local function getTopRacerWinnersCacheKey(days)
    return tostring(days)
end

local function invalidateTopRacerWinnersCache()
    topRacerWinnersCache = {}
end

local function invalidateTrackRaceStatsCache()
    trackRaceStatsCache = {}
end

-- Fetch track race stats for all tracks within the given datespan (in days)
local function getTrackRaceStats(datespanDays)
    local cacheKey = getCacheKey(datespanDays)
    if trackRaceStatsCache[cacheKey] then
        if UseDebug then print('Returning cache', json.encode(trackRaceStatsCache[cacheKey], {indent=true})) end
        return trackRaceStatsCache[cacheKey]
    end

    -- Fetch all tracks
    local tracks = exports.oxmysql:executeSync("SELECT raceid, name FROM race_tracks", {})

    local result = {}

    for _, track in ipairs(tracks) do
        -- Fetch all races for this track in the datespan
        local races = exports.oxmysql:executeSync(
            "SELECT * FROM race_entries WHERE trackid = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)",
            { track.raceid, datespanDays }
        )

        local stats = {
            trackId = track.raceid,
            trackName = track.name,
            totalRaces = #races,
            avgParticipants = 0,
            avgTime = 0,
            bestTime = nil,
            ghostingCount = 0,
            rankedCount = 0,
            firstPersonCount = 0,
            automatedCount = 0,
            silentCount = 0,
            mostUsedMaxClass = nil,
        }

        local totalParticipants = 0
        local totalTimes = 0
        local bestTime = nil
        local maxClassCount = {}

        for _, race in ipairs(races) do
            totalParticipants = totalParticipants + (race.amountofracers or 0)
            stats.ghostingCount = stats.ghostingCount + (race.ghosting and 1 or 0)
            stats.rankedCount = stats.rankedCount + (race.ranked and 1 or 0)
            stats.firstPersonCount = stats.firstPersonCount + (race.firstperson and 1 or 0)
            stats.automatedCount = stats.automatedCount + (race.automated and 1 or 0)
            stats.silentCount = stats.silentCount + (race.silent and 1 or 0)

            if race.maxclass and race.maxclass ~= "" then
                maxClassCount[race.maxclass] = (maxClassCount[race.maxclass] or 0) + 1
            end

            -- Parse results JSON for times
            if race.results and race.results ~= "" then
                local ok, parsed = pcall(json.decode, race.results)
                if ok and type(parsed) == "table" then
                    for _, res in ipairs(parsed) do
                        if res.TotalTime then
                            totalTimes = totalTimes + res.TotalTime
                            if not bestTime or res.TotalTime < bestTime then
                                bestTime = res.TotalTime
                            end
                        end
                    end
                end
            end
        end

        -- Fetch all track_times for this track in the datespan
        local times = exports.oxmysql:executeSync(
            "SELECT time FROM race_track_times WHERE trackid = ? AND created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)",
            { track.raceid, datespanDays }
        )

        local totalTimeSum = 0
        local bestTimeFromTimes = nil
        local timeCount = 0

        for _, t in ipairs(times) do
            if t.time then
                local timeVal = tonumber(t.time)
                totalTimeSum = totalTimeSum + timeVal
                timeCount = timeCount + 1
                if not bestTimeFromTimes or timeVal < bestTimeFromTimes then
                    bestTimeFromTimes = timeVal
                end
            end
        end

        -- Use track_times for avgTime and bestTime if available
        if timeCount > 0 then
            stats.avgTime = math.floor(totalTimeSum / timeCount)
            stats.bestTime = bestTimeFromTimes
        end

        stats.avgParticipants = stats.totalRaces > 0 and math.floor(totalParticipants / stats.totalRaces) or 0
        
        -- Only use race times if we don't have track_times data
        if timeCount == 0 and stats.totalRaces > 0 then
            stats.avgTime = math.floor(totalTimes / stats.totalRaces)
        end
        
        stats.bestTime = bestTime or bestTimeFromTimes or 0

        -- Find most used maxClass
        local maxCount, maxClass = 0, nil
        for class, count in pairs(maxClassCount) do
            if count > maxCount then
                maxCount = count
                maxClass = class
            end
        end
        stats.mostUsedMaxClass = maxClass or ""

        table.insert(result, stats)
    end

    trackRaceStatsCache[cacheKey] = result
    if UseDebug then print('Returning fresh result', json.encode(result, {indent=true})) end
    return result
end

-- Overwrite addRaceEntry to invalidate cache
local function addRaceEntry(raceData)
    invalidateTopRacerWinnersCache()
    invalidateTrackRaceStatsCache()
    
    local query = [[
        INSERT INTO race_entries (
            raceid, trackid, results, amountofracers, laps, hostname, maxclass,
            ghosting, ranked, reversed, firstperson, automated, hidden, silent, buyin
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]]
    
    local params = {
        RADB.StrictSanitize(raceData.raceId),
        RADB.StrictSanitize(raceData.trackId),
        json.encode(raceData.results or {}),
        raceData.amountOfRacers or 0,
        raceData.laps or 1,
        raceData.hostName and RADB.StrictSanitize(raceData.hostName) or nil,
        raceData.maxClass and RADB.StrictSanitize(raceData.maxClass) or nil,
        raceData.ghosting and 1 or 0,
        raceData.ranked and 1 or 0,
        raceData.reversed and 1 or 0,
        raceData.firstPerson and 1 or 0,
        raceData.automated and 1 or 0,
        raceData.hidden and 1 or 0,
        raceData.silent and 1 or 0,
        raceData.buyIn or 0
    }
    
    local result = exports.oxmysql:executeSync(query, params)
    if UseDebug then
        print('DEBUG: RESDB.addRaceEntry - Query:', query)
        print('DEBUG: RESDB.addRaceEntry - Parameters:', json.encode(params))
        print('DEBUG: RESDB.addRaceEntry - Result:', json.encode(result))
    end
    return result and result.affectedRows > 0
end

-- Function to add/update track time (returns "PB" if new personal best)
local function addTrackTime(timeData)
    if UseDebug then
        print('DEBUG: RESDB.addTrackTime - timeData:', json.encode(timeData))
    end
    -- First check if there's an existing record
    local existingQuery = [[
        SELECT time, pbhistory FROM race_track_times 
        WHERE trackid = ? AND racername = ? AND carclass = ? AND racetype = ? AND reversed = ?
    ]]
    
    local existingParams = {
        RADB.StrictSanitize(timeData.trackId),
        RADB.StrictSanitize(timeData.racerName),
        RADB.StrictSanitize(timeData.carClass),
        RADB.StrictSanitize(timeData.raceType),
        timeData.reversed and 1 or 0
    }
    
    local existingRecord = exports.oxmysql:executeSync(existingQuery, existingParams)
    if UseDebug then
        print('DEBUG: RESDB.addTrackTime - Existing record query result:', json.encode(existingRecord))
    end
    local newTime = tonumber(timeData.time)
    
    -- If no existing record or new time is better
    if not existingRecord or #existingRecord == 0 or newTime < tonumber(existingRecord[1].time) then
        local pbHistory = {}
        
        -- Get existing PB history if it exists
        if existingRecord and #existingRecord > 0 and existingRecord[1].pbhistory then
            local ok, history = pcall(json.decode, existingRecord[1].pbhistory)
            if ok and type(history) == "table" then
                pbHistory = history
            end
        end
        
        -- Add the new PB to history
        table.insert(pbHistory, newTime)
        
        -- Delete existing record if it exists
        if existingRecord and #existingRecord > 0 then
            local deleteQuery = [[
                DELETE FROM race_track_times 
                WHERE trackid = ? AND racername = ? AND carclass = ? AND racetype = ? AND reversed = ?
            ]]
            local deleteResult = exports.oxmysql:executeSync(deleteQuery, existingParams)
            if UseDebug then
                print('DEBUG: RESDB.addTrackTime - Delete existing record result:', json.encode(deleteResult))
            end
        end
        
        -- Insert new record with updated PB history
        local insertQuery = [[
            INSERT INTO race_track_times (trackid, racername, carclass, vehiclemodel, racetype, time, reversed, pbhistory)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ]]
        
        local insertParams = {
            RADB.StrictSanitize(timeData.trackId),
            RADB.StrictSanitize(timeData.racerName),
            RADB.StrictSanitize(timeData.carClass),
            timeData.vehicleModel and RADB.StrictSanitize(timeData.vehicleModel) or nil,
            RADB.StrictSanitize(timeData.raceType),
            newTime,
            timeData.reversed and 1 or 0,
            json.encode(pbHistory)
        }
        
        local result = exports.oxmysql:executeSync(insertQuery, insertParams)
        if UseDebug then
            print('DEBUG: RESDB.addTrackTime - Insert new record query:', insertQuery)
            print('DEBUG: RESDB.addTrackTime - Insert new record parameters:', json.encode(insertParams))
            print('DEBUG: RESDB.addTrackTime - Insert new record result:', json.encode(result))
        end
        return result and result.affectedRows > 0 and "PB" or nil
    end
    
    return nil -- No personal best
end

-- Function to get race results by raceId
local function getRaceResults(raceId)
    local query = "SELECT * FROM race_entries WHERE raceid = ?"
    return exports.oxmysql:executeSync(query, { RADB.StrictSanitize(raceId) })
end

-- Function to get all racing_races for a specific track
local function getRacesByTrackId(trackId)
    local query = "SELECT * FROM race_entries WHERE trackid = ? ORDER BY created_at DESC"
    return exports.oxmysql:executeSync(query, { RADB.StrictSanitize(trackId) })
end

-- Function to get best times for a track (top 10)
local function getBestTimesForTrack(trackId, raceType, carClass, reversed)
    local query = [[
        SELECT * FROM race_track_times 
        WHERE trackid = ? AND racetype = ? AND carclass = ? AND reversed = ?
        ORDER BY time ASC 
        LIMIT 10
    ]]
    
    local params = {
        RADB.RADB.StrictSanitize(trackId),
        RADB.StrictSanitize(raceType),
        RADB.StrictSanitize(carClass),
        reversed and 1 or 0
    }
    
    return exports.oxmysql:executeSync(query, params)
end

-- Function to get all best times for a track (all classes/types)
local function getAllBestTimesForTrack(trackId)
    local query = [[
        SELECT * FROM race_track_times 
        WHERE trackid = ?
        ORDER BY time ASC
    ]]
    
    local params = { RADB.StrictSanitize(trackId) }
    
    return exports.oxmysql:executeSync(query, params)
end

-- Function to get best personal time for a racer by trackId
local function getBestPersonalTime(racerName, trackId, carClass, raceType, reversed)
    local query = [[
        SELECT * FROM race_track_times 
        WHERE racername = ? AND trackid = ? AND carclass = ? AND racetype = ? AND reversed = ?
        ORDER BY time ASC 
        LIMIT 1
    ]]
    
    local params = {
        RADB.StrictSanitize(racerName),
        RADB.StrictSanitize(trackId),
        RADB.StrictSanitize(carClass),
        RADB.StrictSanitize(raceType),
        reversed and 1 or 0
    }
    
    return exports.oxmysql:executeSync(query, params)
end

-- Function to get all personal times for a racer
local function getAllPersonalTimes(racerName)
    local query = [[
        SELECT * FROM race_track_times 
        WHERE racername = ?
        ORDER BY trackid, carclass, racetype, time ASC
    ]]
    
    return exports.oxmysql:executeSync(query, { RADB.StrictSanitize(racerName) })
end

-- Function to get recent racing_races (last 50)
local function getRecentRaces(limit, identifier)
    local query = "SELECT * FROM race_entries"
    local params = {}
    local whereClauses = {}

    if identifier then
        local racerName = RADB.getRacerNameByCitizenIdOrLicense(identifier)
        if racerName then
            table.insert(whereClauses, "JSON_CONTAINS(results, JSON_OBJECT('RacerName', ?), '$')")
            table.insert(params, racerName)
        end
    end

    if #whereClauses > 0 then
        query = query .. " WHERE " .. table.concat(whereClauses, " AND ")
    end

    query = query .. " ORDER BY created_at DESC LIMIT ?"
    table.insert(params, limit or 50)

    return exports.oxmysql:executeSync(query, params)
end

-- Function to get race statistics for a track
local function getTrackStats(trackId)
    local query = [[
        SELECT 
            COUNT(*) as totalRaces,
            AVG(amountofracers) as avgRacers,
            MAX(amountofracers) as maxRacers,
            MIN(amountofracers) as minRacers
        FROM race_entries 
        WHERE trackid = ?
    ]]
    
    return exports.oxmysql:executeSync(query, { RADB.StrictSanitize(trackId) })
end

-- Function to delete old racing_races (older than specified days)
local function cleanupOldRaces(daysOld)
    local query = "DELETE FROM race_entries WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)"
    local result = exports.oxmysql:executeSync(query, { daysOld })
    return result and result.affectedRows > 0
end

-- Function to get leaderboard for a specific track/class combination
local function getTrackLeaderboard(trackId, carClass, raceType, reversed, limit)
    local query = [[
        SELECT 
            racername,
            MIN(time) as bestTime,
            vehiclemodel,
            created_at
        FROM race_track_times 
        WHERE trackid = ? AND carclass = ? AND racetype = ? AND reversed = ?
        GROUP BY racername
        ORDER BY bestTime ASC
        LIMIT ?
    ]]
    
    local params = {
        RADB.StrictSanitize(trackId),
        RADB.StrictSanitize(carClass),
        RADB.StrictSanitize(raceType),
        reversed and 1 or 0,
        limit or 10
    }
    
    return exports.oxmysql:executeSync(query, params)
end

-- Function to clear all track records for a specific track
local function clearTrackRecords(trackId)
    local query = "DELETE FROM race_track_times WHERE trackid = ?"
    local result = exports.oxmysql:executeSync(query, { RADB.StrictSanitize(trackId) })
    return result and result.affectedRows > 0
end

-- Function to remove a specific track record by database ID
local function removeTrackRecord(recordId)
    local query = "DELETE FROM race_track_times WHERE id = ?"
    local result = exports.oxmysql:executeSync(query, { recordId })
    return result and result.affectedRows > 0
end

-- Function to get racer history
local function getRacerHistory(racerName)
    local query = [[
        SELECT re.* 
        FROM race_entries re
        WHERE JSON_CONTAINS(re.results, JSON_OBJECT('RacerName', ?), '$')
        ORDER BY re.created_at DESC
    ]]
    
    return exports.oxmysql:executeSync(query, { RADB.StrictSanitize(racerName) })
end

local function getTopRacerWinnersAndWinLoss(racers, days)
    local amountOfRacers = racers or Config.Dashboard.defaultTopRacers
    local cacheKey = getTopRacerWinnersCacheKey(days)
    
    if UseDebug then
        print('Checking top racer winners cache for key:', cacheKey)
        print('Cache', json.encode(topRacerWinnersCache[cacheKey] or {}, { indent = true }))
    end
    
    if topRacerWinnersCache[cacheKey] then
        return { 
            topRacerWins = topRacerWinnersCache[cacheKey].topRacerWins, 
            topRacerWinLoss = topRacerWinnersCache[cacheKey].topRacerWinLoss 
        }
    end

    local query, params
    if Config.Dashboard.topRacersOnlyIncludeRanked then
        query = [[
            SELECT results FROM race_entries
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY) AND ranked = 1
        ]]
        params = { days }
    else
        query = [[
            SELECT results FROM race_entries
            WHERE created_at >= DATE_SUB(NOW(), INTERVAL ? DAY)
        ]]
        params = { days }
    end

    local races = exports.oxmysql:executeSync(query, params) or {}

    local winCounts = {}
    local raceCounts = {}

    for _, race in ipairs(races) do
        if race.results and race.results ~= "" then
            local ok, results = pcall(json.decode, race.results)
            if ok and type(results) == "table" and #results > 0 then
                -- Find winner (lowest TotalTime)
                local winner, bestTime
                for _, res in ipairs(results) do
                    if res.RacerName then
                        raceCounts[res.RacerName] = (raceCounts[res.RacerName] or 0) + 1
                    end
                    if res.TotalTime and (not bestTime or res.TotalTime < bestTime) then
                        bestTime = res.TotalTime
                        winner = res.RacerName
                    end
                end
                if winner then
                    winCounts[winner] = (winCounts[winner] or 0) + 1
                end
            end
        end
    end

    -- Top x by wins
    local winList = {}
    for name, count in pairs(winCounts) do
        table.insert(winList, { racerName = name, wins = count })
    end
    table.sort(winList, function(a, b) return a.wins > b.wins end)
    local topRacerWins = {}
    for i = 1, math.min(amountOfRacers, #winList) do
        table.insert(topRacerWins, winList[i])
    end

    -- Top x by win/loss ratio
    local winLossList = {}
    for name, totalRaces in pairs(raceCounts) do
        local wins = winCounts[name] or 0
        local nonWins = totalRaces - wins
        local ratio = totalRaces > 0 and (wins / totalRaces) or (wins > 0 and math.huge or 0)
        if UseDebug then 
            print("Racer:", name, "Wins:", wins, "Losses:", nonWins, "Ratio:", ratio, "totalRaces:", totalRaces) 
        end
        table.insert(winLossList, { 
            racerName = name, 
            wins = wins, 
            losses = nonWins, 
            winLoss = ratio 
        })
    end
    
    table.sort(winLossList, function(a, b) 
        return a.winLoss > b.winLoss 
    end)
    
    local topRacerWinLoss = {}
    for i = 1, math.min(amountOfRacers, #winLossList) do
        table.insert(topRacerWinLoss, winLossList[i])
    end

    topRacerWinnersCache[cacheKey] = { 
        topRacerWins = topRacerWins, 
        topRacerWinLoss = topRacerWinLoss 
    }
    
    return { 
        topRacerWins = topRacerWins, 
        topRacerWinLoss = topRacerWinLoss 
    }
end

-- Export functions
RESDB = {
    addRaceEntry = addRaceEntry,
    addTrackTime = addTrackTime,
    getRaceResults = getRaceResults,
    getRacesByTrackId = getRacesByTrackId,
    getBestTimesForTrack = getBestTimesForTrack,
    getAllBestTimesForTrack = getAllBestTimesForTrack,
    getBestPersonalTime = getBestPersonalTime,
    getAllPersonalTimes = getAllPersonalTimes,
    getRecentRaces = getRecentRaces,
    getTrackStats = getTrackStats,
    cleanupOldRaces = cleanupOldRaces,
    getTrackLeaderboard = getTrackLeaderboard,
    clearTrackRecords = clearTrackRecords,
    removeTrackRecord = removeTrackRecord,
    getRacerHistory = getRacerHistory,
    getTrackRaceStats = getTrackRaceStats,
    getTopRacerWinnersAndWinLoss = getTopRacerWinnersAndWinLoss,
}