RADB = {}

function RADB.StrictSanitize(input)
    if type(input) ~= "string" then
        return input
    end

    -- Remove leading/trailing spaces and collapse multiple spaces into single spaces
    input = input:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ")

    -- Keep only allowed characters
    input = input:gsub("[^%w%s%-_]", "")

    return input
end
function RADB.getAllRaceTracks()
    return exports.oxmysql:executeSync('SELECT * FROM race_tracks')
end

function RADB.setTrackCheckpoints(checkpoints, raceid)
    local result = exports.oxmysql:executeSync('UPDATE race_tracks SET checkpoints = ? WHERE raceid = ?', { json.encode(checkpoints), raceid })
    return result and result.affectedRows > 0
end

function RADB.createTrack(raceData, checkpoints, citizenId, raceId)
    local result = exports.oxmysql:executeSync(
        'INSERT INTO race_tracks (name, checkpoints, creatorid, creatorname, distance, raceid, curated, access) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { RADB.StrictSanitize(raceData.RaceName), json.encode(checkpoints), citizenId, RADB.StrictSanitize(raceData.RacerName),
            raceData.RaceDistance, raceId, 0, '{}' }
    )
    return result and result.affectedRows > 0
end

function RADB.getSizeOfRacerNameTable()
    local result = exports.oxmysql:executeSync('SELECT COUNT(*) as count FROM race_users', {})
    return result and result[1] and result[1].count or 0
end

function RADB.clearLeaderboardForTrack(raceId)
    local result = exports.oxmysql:executeSync('DELETE FROM race_track_times WHERE trackid = ?', { raceId })
    return result and result.affectedRows > 0
end

function RADB.deleteTrack(raceId)
    local result = exports.oxmysql:executeSync('DELETE FROM race_tracks WHERE raceid = ?', { raceId })
    return result and result.affectedRows > 0
end

function RADB.updateTrackMetadata(raceId, metadata)
    local result = exports.oxmysql:executeSync('UPDATE race_tracks SET metadata = ? WHERE raceid = ?', { json.encode(metadata), raceId })
    return result and result.affectedRows > 0
end

function RADB.getAllRacerNames()
    local query = 'SELECT * FROM race_users'
    if Config.DontShowRankingsUnderZero then
        query = query .. ' WHERE ranking > 0'
    end
    if Config.LimitTopListTo then
        query = query .. ' ORDER BY ranking DESC LIMIT ?'
        return exports.oxmysql:executeSync(query, { Config.LimitTopListTo })
    end
    return exports.oxmysql:executeSync(query) or {}
end

function RADB.setAccessForTrack(raceId, access)
    local result = exports.oxmysql:executeSync('UPDATE race_tracks SET access = ? WHERE raceid = ?', { json.encode(access), raceId })
    return result and result.affectedRows > 0
end

function RADB.getTrackById(raceId)
    local result = exports.oxmysql:executeSync('SELECT * FROM race_tracks WHERE raceid = ?', { raceId })
    if result and result[1] then
        return result[1]
    end
    return nil
end

function RADB.changeRaceUser(citizenId, racerName)
    -- Primeiro desativa todos os nomes do usuário
    local deactivateResult = exports.oxmysql:executeSync('UPDATE race_users SET active = 0 WHERE citizenid = ?', { citizenId })
    if deactivateResult and deactivateResult.affectedRows >= 0 then
        -- Depois ativa o nome específico
        local activateResult = exports.oxmysql:executeSync('UPDATE race_users SET active = 1 WHERE racername = ? AND citizenid = ?', { racerName, citizenId })
        return activateResult and activateResult.affectedRows > 0
    end
    return false
end

function RADB.getActiveRacerName(citizenId)
    local result = exports.oxmysql:executeSync('SELECT * FROM race_users WHERE citizenid = ? AND active = 1', { citizenId })
    return result and result[1] or nil
end

function RADB.getActiveRacerCrew(racerName)
    local result = exports.oxmysql:executeSync('SELECT crew FROM race_users WHERE racername = ?', { RADB.StrictSanitize(racerName) })
    if result and result[1] then
        return result[1].crew
    end
    return nil
end

function RADB.setActiveRacerCrew(racerName, crewName)
    local result = exports.oxmysql:executeSync('UPDATE race_users SET crew = ? WHERE racername = ?', { crewName, racerName })
    return result and result.affectedRows > 0
end

function RADB.getUserAuth(racerName)
    local result = exports.oxmysql:executeSync('SELECT auth FROM race_users WHERE racername = ?', { RADB.StrictSanitize(racerName) })
    if result and result[1] then
        return result[1].auth
    end
    return "racer" -- Default
end

function RADB.getRaceUserByName(racerName)
    local result = exports.oxmysql:executeSync('SELECT * FROM race_users WHERE racername = ?', { racerName })
    if result and result[1] then
        return result[1]
    end
    return nil
end

function RADB.createRaceUser(citizenId, racerName, auth, creatorCitizenId)
    if UseDebug then
        print('DEBUG: RADB.createRaceUser - Parâmetros recebidos:')
        print('citizenId:', citizenId)
        print('racerName:', racerName)
        print('auth:', auth)
        print('creatorCitizenId:', creatorCitizenId)
    end
    
    local query = "INSERT INTO race_users (citizenid, racername, auth, creator_citizenid, active) VALUES (?, ?, ?, ?, 1)"
    local parameters = { citizenId, racerName, auth, creatorCitizenId }
    
    if UseDebug then
        print('DEBUG: Query:', query)
        print('DEBUG: Parameters:', json.encode(parameters))
    end
    
    local result = exports.oxmysql:executeSync(query, parameters)
    
    if UseDebug then
        print('DEBUG: RADB.createRaceUser - Resultado do insert:', json.encode(result))
        -- print('DEBUG: Tipo do resultado:', type(result))
    end
    
    return result ~= nil
end

function RADB.getRaceUserRankingByName(racerName)
    local result = exports.oxmysql:executeSync('SELECT ranking FROM race_users WHERE racername = ?', { RADB.StrictSanitize(racerName) })
    if result and result[1] then
        return result[1].ranking or 1000
    end
    return 1000 -- Default ranking
end

function RADB.increaseRaceCount(racerName, position)
    local query = 'UPDATE race_users SET races = races + 1'
    if position == 1 then
        query = query .. ', wins = wins + 1'
    end
    query = query .. ' WHERE racername = ?'
    local result = exports.oxmysql:executeSync(query, { RADB.StrictSanitize(racerName) })
    return result and result.affectedRows > 0
end

function RADB.updateRacerElo(racerName, eloChange)
    local result = exports.oxmysql:executeSync('UPDATE race_users SET ranking = ranking + ? WHERE racername = ?', { eloChange, RADB.StrictSanitize(racerName) })
    return result and result.affectedRows > 0
end

local function mapTable(tbl, func)
    local t = {}
    for i, v in ipairs(tbl) do
        t[i] = func(v, i)
    end
    return t
end

function RADB.updateEloForRaceResult(results)
    if not results or #results == 0 then return end
    
    local params = {}
    local sql = "UPDATE race_users SET ranking = ranking + (CASE racername "
    
    for _, racer in ipairs(results) do
        sql = sql .. "WHEN ? THEN ? "
        table.insert(params, racer.RacerName)
        table.insert(params, racer.TotalChange or 0)
    end
    
    sql = sql .. "END) WHERE racername IN (" .. table.concat(mapTable(results, function() return "?" end), ", ") .. ")"
    
    -- Add all RacerName values to the params again for the WHERE clause
    for _, racer in ipairs(results) do
        table.insert(params, racer.RacerName)
    end
    
    local result = exports.oxmysql:executeSync(sql, params)
    return result and result.affectedRows > 0
end

function RADB.getTracksByCitizenId(citizenId)
    local result = exports.oxmysql:executeSync('SELECT name FROM race_tracks WHERE creatorid = ?', { citizenId })
    return result or {}
end

function RADB.getRaceUsersCreatedByCitizenId(citizenId)
    local result = exports.oxmysql:executeSync('SELECT * FROM race_users WHERE creator_citizenid = ?', { citizenId })
    return result or {}
end

function RADB.getRaceUsersBelongingToCitizenId(citizenId)
    if UseDebug then
        -- print('DEBUG: RADB.getRaceUsersBelongingToCitizenId - citizenId:', citizenId)
    end
    
    local query = "SELECT * FROM race_users WHERE citizenid = ?"
    local result = exports.oxmysql:executeSync(query, { citizenId })
    
    if UseDebug then
        -- print('DEBUG: RADB.getRaceUsersBelongingToCitizenId - Resultado bruto:', json.encode(result))
        -- print('DEBUG: Tipo do resultado:', type(result))
        if result then
            -- print('DEBUG: Número de registros:', #result)
        end
    end
    
    return result or {}
end

function RADB.setCurationForTrack(curated, trackId)
    local result = exports.oxmysql:executeSync('UPDATE race_tracks SET curated = ? WHERE raceid = ?', { curated, trackId })
    return result and result.affectedRows > 0
end

function RADB.getAllRaceUsers()
    local result = exports.oxmysql:executeSync('SELECT * FROM race_users')
    return result or {}
end

function RADB.removeRaceUserByName(racerName)
    local result = exports.oxmysql:executeSync('DELETE FROM race_users WHERE racername = ?', { RADB.StrictSanitize(racerName) })
    return result and result.affectedRows > 0
end

function RADB.setRaceUserRevoked(racerName, revoked)
    local result = exports.oxmysql:executeSync('UPDATE race_users SET revoked = ? WHERE racername = ?', { tonumber(revoked), RADB.StrictSanitize(racerName) })
    return result and result.affectedRows > 0
end

function RADB.setRaceUserAuth(racerName, auth)
    local result = exports.oxmysql:executeSync('UPDATE race_users SET auth = ? WHERE racername = ?', { auth, RADB.StrictSanitize(racerName) })
    return result and result.affectedRows > 0
end

function RADB.wipeTracksTable()
    local result = exports.oxmysql:executeSync('DELETE FROM race_tracks')
    return result and result.affectedRows > 0
end

function RADB.joinRacingCrew(citizenId, memberName, crewName)
    -- Primeiro verifica se a crew existe
    local crewResult = exports.oxmysql:executeSync('SELECT members FROM racing_crews WHERE crew_name = ?', { RADB.StrictSanitize(crewName) })
    if not crewResult or not crewResult[1] then
        return false
    end
    
    local members = json.decode(crewResult[1].members or '[]')
    
    -- Verifica se o membro já está na crew
    for _, member in ipairs(members) do
        if member.citizenID == citizenId then
            return false -- Já está na crew
        end
    end
    
    -- Adiciona o novo membro
    table.insert(members, {
        citizenID = citizenId,
        racername = memberName,
        rank = 0
    })
    
    local result = exports.oxmysql:executeSync('UPDATE racing_crews SET members = ? WHERE crew_name = ?', { json.encode(members), RADB.StrictSanitize(crewName) })
    return result and result.affectedRows > 0
end

function RADB.createRacingCrew(crewName, founderName, citizenId)
    local members = json.encode({
        {
            citizenID = citizenId,
            racername = founderName,
            rank = 1 -- Founder rank
        }
    })
    
    local result = exports.oxmysql:executeSync(
        'INSERT INTO racing_crews (crew_name, founder_name, founder_citizenid, members, wins, races, rank) VALUES (?, ?, ?, ?, 0, 0, 1000)',
        { RADB.StrictSanitize(crewName), RADB.StrictSanitize(founderName), citizenId, members }
    )
    return result and result.affectedRows > 0
end

function RADB.leaveRacingCrew(citizenId, crewName)
    local crewResult = exports.oxmysql:executeSync('SELECT members FROM racing_crews WHERE crew_name = ?', { RADB.StrictSanitize(crewName) })
    
    if not crewResult or not crewResult[1] then 
        return false 
    end

    local members = json.decode(crewResult[1].members or '[]')
    local newMembers = {}
    local found = false

    for _, member in ipairs(members) do
        if member.citizenID ~= citizenId then
            table.insert(newMembers, member)
        else
            found = true
        end
    end

    if not found then
        return false
    end

    local result = exports.oxmysql:executeSync('UPDATE racing_crews SET members = ? WHERE crew_name = ?', { json.encode(newMembers), RADB.StrictSanitize(crewName) })
    return result and result.affectedRows > 0
end

function RADB.increaseCrewWins(crewName)
    local result = exports.oxmysql:executeSync('UPDATE racing_crews SET wins = wins + 1, races = races + 1 WHERE crew_name = ?', { RADB.StrictSanitize(crewName) })
    return result and result.affectedRows > 0
end

function RADB.increaseCrewRaces(crewName)
    local result = exports.oxmysql:executeSync('UPDATE racing_crews SET races = races + 1 WHERE crew_name = ?', { RADB.StrictSanitize(crewName) })
    return result and result.affectedRows > 0
end

function RADB.changeCrewRank(crewName, amount)
    local result = exports.oxmysql:executeSync('UPDATE racing_crews SET ranking = ranking + ? WHERE crew_name = ?', { amount, RADB.StrictSanitize(crewName) })
    return result and result.affectedRows > 0
end

function RADB.disbandCrew(crewName)
    local result = exports.oxmysql:executeSync('DELETE FROM racing_crews WHERE crew_name = ?', { RADB.StrictSanitize(crewName) })
    return result and result.affectedRows > 0
end

function RADB.getAllCrews()
    local result = exports.oxmysql:executeSync('SELECT * FROM racing_crews')
    return result or {}
end

-- Fetch crypto balance for a specific racer
function RADB.getCryptoForRacer(racerName)
    local result = exports.oxmysql:executeSync('SELECT crypto FROM race_users WHERE racername = ?', { RADB.StrictSanitize(racerName) })
    if result and result[1] then
        return result[1].crypto or 0
    end
    return 0
end

-- Add crypto to a racer's balance
function RADB.addCryptoToRacer(racerName, amount)
    local result = exports.oxmysql:executeSync('UPDATE race_users SET crypto = crypto + ? WHERE racername = ?', { amount, RADB.StrictSanitize(racerName) })
    return result and result.affectedRows > 0
end

-- Remove crypto from a racer's balance
function RADB.removeCryptoFromRacer(racerName, amount)
    local result = exports.oxmysql:executeSync('UPDATE race_users SET crypto = crypto - ? WHERE racername = ?', { amount, RADB.StrictSanitize(racerName) })
    return result and result.affectedRows > 0
end

-- Set crypto for a racer's balance
function RADB.setCryptoForRacer(racerName, amount)
    local result = exports.oxmysql:executeSync('UPDATE race_users SET crypto = ? WHERE racername = ?', { amount, RADB.StrictSanitize(racerName) })
    return result and result.affectedRows > 0
end

-- Get racing users belonging to a specific citizenid
function RADB.getRacingUsersByCitizenId(citizenId)
    local result = exports.oxmysql:executeSync('SELECT * FROM race_users WHERE citizenid = ?', { citizenId })
    return result or {}
end

-- Fetch crypto balance for a specific crew
function RADB.getCrewCrypto(crewId)
    local result = exports.oxmysql:executeSync('SELECT crypto FROM racing_crews WHERE id = ?', { crewId })
    if result and result[1] then
        return result[1].crypto or 0
    end
    return 0
end

function RADB.addCryptoToCrew(crewId, amount)
    local result = exports.oxmysql:executeSync('UPDATE racing_crews SET crypto = crypto + ? WHERE id = ?', { amount, crewId })
    return result and result.affectedRows > 0
end

function RADB.removeCryptoFromCrew(crewId, amount)
    local result = exports.oxmysql:executeSync('UPDATE racing_crews SET crypto = crypto - ? WHERE id = ?', { amount, crewId })
    return result and result.affectedRows > 0
end

function RADB.setCryptoForCrew(crewId, amount)
    local result = exports.oxmysql:executeSync('UPDATE racing_crews SET crypto = ? WHERE id = ?', { amount, crewId })
    return result and result.affectedRows > 0
end