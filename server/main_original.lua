-----------------------
----   Variables   ----
-----------------------
Tracks = {}
Races = {}
UseDebug = Config.Debug
local AvailableRaces = {}
local NotFinished = {}
local Timers = {}
local IsFirstUser = false

-- Sistema de carregamento de personagem
local PlayerCharacterLoaded = {}
local CharacterLoadCallbacks = {}
local PendingRacerRequests = {}
local RacerNamesCache = {}
local CacheTimeout = 30000 -- 30 segundos de cache

local HostingIsAllowed = true
local AutoHostIsAllowed = false

Racing = Racing or {}
Racing.Functions = Racing.Functions or {}

local vRP = nil
local vRPclient = nil

CreateThread(function()
    while not global_vRP do
        Wait(100)
    end
    vRP = global_vRP
    vRPclient = global_vRPclient
    print("^2[Creative] Interface vRP carregada com sucesso em main.lua^0")
end)

CreateThread(function()
    while not exports['cw-racingapp'] or not exports['cw-racingapp']:getBountyHandler() do
        Wait(100)
    end
    BountyHandler = exports['cw-racingapp']:getBountyHandler()
    print("^2[Creative] BountyHandler carregado com sucesso em main.lua^0")
end)

-- Função para registrar callbacks quando o personagem carregar
local function registerCharacterLoadCallback(source, callback)
    if not CharacterLoadCallbacks[source] then
        CharacterLoadCallbacks[source] = {}
    end
    table.insert(CharacterLoadCallbacks[source], callback)
end

-- Função para executar callbacks quando o personagem carregar
local function executeCharacterLoadCallbacks(source)
    if CharacterLoadCallbacks[source] then
        for _, callback in ipairs(CharacterLoadCallbacks[source]) do
            callback(source)
        end
        CharacterLoadCallbacks[source] = nil
    end
end

-- Função para aguardar o carregamento do personagem de forma assíncrona
local function waitForCharacterLoaded(source)
    if PlayerCharacterLoaded[source] then
        return true
    end
    
    local maxAttempts = 30  -- 15 segundos no total
    local attempts = 0
    
    while attempts < maxAttempts do
        if PlayerCharacterLoaded[source] then
            return true
        end
        attempts = attempts + 1
        Wait(500)
    end
    
    return false
end

-- Função separada para processar a requisição de nomes de corredores
local function processRacerNamesRequest(playerSource)
    local citizenId = Racing.Functions.GetCitizenId(playerSource)
    
    if UseDebug then print('Racer citizenid:', citizenId) end

    if not citizenId then
        if UseDebug then
            print('^1ERRO: Não foi possível obter citizenId após personagem carregado^0')
        end
        return {}
    end

    local result = RADB.getRaceUsersBelongingToCitizenId(citizenId)
    
    if UseDebug then
        print('^2Racer Names found:', json.encode(result), '^0')
    end

    local activeRacer = getActiveRacerName(result, playerSource)
    
    -- Se não há corredor ativo, não faz nada - o jogador precisa criar um no tablet
    if not activeRacer then
        if UseDebug then
            print('^3Nenhum corredor ativo encontrado. Jogador precisa criar um nome no tablet.^0')
        end
    end

    return result
end

-- Versão melhorada com cache e prevenção de duplicatas
RegisterServerCallback('cw-racingapp:server:getRacerNamesByPlayer', function(source, serverId)
    if UseDebug then print('getRacerNamesByPlayer called with source:', source, 'serverId:', serverId) end
    local playerSource = serverId or source
    if UseDebug then print('playerSource:', playerSource) end

    -- Verifica se já há uma requisição pendente para este jogador
    if PendingRacerRequests[playerSource] then
        if UseDebug then print('^3Requisição duplicada detectada para source:', playerSource, 'retornando cache ou aguardando...^0') end
        -- Se já há uma requisição pendente, espera ela completar
        local maxWait = 10000 -- 10 segundos
        local waited = 0
        while PendingRacerRequests[playerSource] and waited < maxWait do
            Wait(100)
            waited = waited + 100
        end
        
        -- Se temos cache, retorna o cache
        if RacerNamesCache[playerSource] and os.time() - RacerNamesCache[playerSource].timestamp < CacheTimeout then
            if UseDebug then print('^2Retornando dados do cache para source:', playerSource, '^0') end
            return RacerNamesCache[playerSource].data
        end
    end

    -- Marca que há uma requisição pendente
    PendingRacerRequests[playerSource] = true

    local function cleanup()
        PendingRacerRequests[playerSource] = nil
    end

    -- Se o personagem já está carregado, processa imediatamente
    if PlayerCharacterLoaded[playerSource] then
        if UseDebug then print('^2Personagem já carregado, processando imediatamente^0') end
        local result = processRacerNamesRequest(playerSource)
        cleanup()
        
        -- Atualiza o cache
        RacerNamesCache[playerSource] = {
            data = result,
            timestamp = os.time()
        }
        
        return result
    end

    -- Se não está carregado, usa o sistema de callback
    if UseDebug then print('^3Personagem não carregado, aguardando callback...^0') end
    
    local callbackExecuted = false
    local result = nil

    registerCharacterLoadCallback(playerSource, function(src)
        if not callbackExecuted then
            callbackExecuted = true
            if UseDebug then print('^2Callback executado para source:', src, '^0') end
            result = processRacerNamesRequest(src)
            cleanup()
            
            -- Atualiza o cache
            RacerNamesCache[src] = {
                data = result,
                timestamp = os.time()
            }
        end
    end)

    -- Espera o callback ser executado ou timeout
    local maxWait = 15000 -- 15 segundos
    local waited = 0
    while not callbackExecuted and waited < maxWait do
        Wait(100)
        waited = waited + 100
    end

    if not callbackExecuted then
        if UseDebug then
            print('^1ERRO: Timeout aguardando carregamento do personagem para source:', playerSource, '^0')
        end
        cleanup()
        return {}
    end

    return result or {}
end)

-- Modifique o evento de personagem escolhido
RegisterNetEvent('cw-racingapp:playerCharacterChosen', function(source, passport)
    local src = source
    local user_id = passport

    if UseDebug then
        print('^2[Creative] Personagem escolhido - Source:', src, 'Passport:', user_id, '^0')
    end

    -- Marca o jogador como tendo o personagem carregado
    PlayerCharacterLoaded[src] = true
    
    -- Executa todos os callbacks pendentes
    executeCharacterLoadCallbacks(src)

    -- Aguarda um pouco para garantir que tudo está carregado
    Wait(1000)

    -- Busca os dados do corredor usando o user_id (passport)
    local racerData = getActiveRacerName(nil, src)

    if racerData then
        -- Aguarda mais um pouco para garantir que o client está pronto
        Wait(500)
        TriggerClientEvent('cw-racingapp:client:updateTabletData', src, racerData)
        if UseDebug then
            print('[Creative] Dados do corredor enviados ao tablet após escolha de personagem:', json.encode(racerData))
        end
    else
        if UseDebug then
            print('[Creative] Nenhum dado de corredor encontrado para o jogador:', src, 'após escolha de personagem.')
        end
        -- Envia dados vazios para o tablet forçar a criação de nome
        TriggerClientEvent('cw-racingapp:client:updateTabletData', src, nil)
    end
end)

-- Adicione também uma verificação quando o jogador desconectar
AddEventHandler('playerDropped', function(reason)
    local src = source
    PlayerCharacterLoaded[src] = nil
    CharacterLoadCallbacks[src] = nil
    PendingRacerRequests[src] = nil
    RacerNamesCache[src] = nil
end)

function notifyPlayer(source, message, type)
    local color = "~y~" -- padrão amarelo
    if type == 'success' then color = "~g~"
    elseif type == 'error' then color = "~r~"
    elseif type == 'info' then color = "~b~" end
    
    if vRPclient and vRPclient.notify then
        vRPclient.notify(source, {color .. message})
    else
        -- Fallback para o sistema original
        TriggerClientEvent('chatMessage', source, '', {255, 255, 255}, message)
    end
end

local DefaultTrackMetadata = {
    description = nil,
    raceType = nil
}

local RaceResults = {}
if Config.Debug then
    -- RaceResults = DebugRaceResults
end

local function leftRace(src)
    local player = Player(src)
    player.state.inRace = false
    player.state.raceId = nil
end

local function setInRace(src, raceId)
    local player = Player(src)
    player.state.inRace = true
    player.state.raceId = raceId
end

local function updateRaces()
    while not RADB do Wait(100) end
    local tracks = RADB.getAllRaceTracks()
    if tracks[1] ~= nil then
        for _, v in pairs(tracks) do
            local metadata

            if v.metadata ~= nil then
                metadata = json.decode(v.metadata)
            else
                if UseDebug then
                    -- print('Metadata is undefined for track', v.name)
                end
                metadata = DeepCopy(DefaultTrackMetadata)
            end

            Tracks[v.raceid] = {
                RaceName = v.name,
                Checkpoints = json.decode(v.checkpoints),
                Creator = v.creatorid,
                CreatorName = v.creatorname,
                TrackId = v.raceid,
                Started = false,
                Waiting = false,
                Distance = v.distance,
                LastLeaderboard = {},
                Racers = {},
                MaxClass = nil,
                Access = json.decode(v.access) or {},
                Curated = v.curated,
                NumStarted = 0,
                Metadata = metadata
            }
        end
    end
    IsFirstUser = RADB.getSizeOfRacerNameTable() == 0
end

CreateThread(function()
    while not exports['mysql-async'] do Wait(100) end
    updateRaces()
    CreateThread(function()
        while not BountyHandler do Wait(100) end
        generateBounties()
    end)
end)

local function getAmountOfRacers(raceId)
    local AmountOfRacers = 0
    local PlayersFinished = 0
    for _, v in pairs(Races[raceId].Racers) do
        if v.Finished then
            PlayersFinished = PlayersFinished + 1
        end
        AmountOfRacers = AmountOfRacers + 1
    end
    return AmountOfRacers, PlayersFinished
end

local function getTrackIdByRaceId(raceId)
    if Races[raceId] then return Races[raceId].TrackId end
end

local function raceWithTrackIdIsActive(trackId)
    for raceId, raceData in pairs(Races) do
        if raceData.TrackId == trackId then
            if UseDebug then print('found hosted race with same id:', json.encode(raceData, {indent=true})) end
            if raceData.Waiting or raceData.active then
                return true
            end
        end
    end
end

local function handleAddMoney(src, moneyType, amount, racerName, textKey)
    if UseDebug then print('DEBUG: handleAddMoney - Function entered. moneyType:', moneyType, 'amount:', amount) end
    if UseDebug then print('Attempting to give', racerName, amount, moneyType) end

    if moneyType == 'dirty' then
        if UseDebug then print('DEBUG: handleAddMoney - Giving dirty money. src:', src, 'amount:', amount, 'vRP.GenerateItem:', tostring(vRP and vRP.GenerateItem)) end
        if vRP and vRP.GenerateItem then
            local success = vRP.GenerateItem(src, "reaissujos", math.floor(tonumber(amount)), true)
            if UseDebug then print('DEBUG: vRP.GenerateItem success:', tostring(success)) end
            notifyPlayer(src,
                Lang(textKey or "dirty_money_received") .. math.floor(amount) .. ' ' .. "reaissujos",
                'success')
        else
            if UseDebug then print('DEBUG: handleAddMoney - vRP or vRP.GenerateItem is nil. vRP:', tostring(vRP), 'vRP.GenerateItem:', tostring(vRP and vRP.GenerateItem)) end
        end
    else
        Racing.Functions.AddMoney(src, math.floor(tonumber(amount)))
    end
end

local function handleRemoveMoney(src, moneyType, amount, racerName)
    if UseDebug then print('DEBUG: handleRemoveMoney called with src:', src, 'racerName:', racerName, 'amount:', amount) end
    if UseDebug then print('Attempting to charge', racerName, amount, moneyType) end
    -- Fallback para user_id se racerName for nil
    local user_id = vRP.getUserId(src)
    if not racerName and user_id then
        racerName = "Racer_" .. user_id -- Nome temporário baseado no user_id
    end
    if moneyType == 'dirty' then
        vRP.tryPayment(user_id, math.floor(tonumber(amount)))
        notifyPlayer(src,
            Lang("remove_dirty_money") .. math.floor(tonumber(amount)) .. ' ' .. Lang("dirty_money_currency"),
            'success')
    else
        if Racing.Functions.RemoveMoney(src, math.floor(tonumber(amount))) then
            return true
        end
        notifyPlayer(src,
            Lang("can_not_afford") .. math.floor(tonumber(amount)) .. ' ' .. Config.Payments.cryptoType,
            'error')
    end

    return false
end

local function hasEnoughMoney(src, moneyType, amount, racerName)
    local user_id = vRP.getUserId(src)
    if moneyType == 'dirty' then
        return vRP.hasMoney(user_id, math.floor(tonumber(amount)))
    else
        return Racing.Functions.CanPay(src, amount)
    end
end

local function giveSplit(src, racers, position, pot, racerName)
    -- Adiciona prêmio de 6000 dinheiro sujo para cada corredor
    handleAddMoney(src, 'dirty', 6000, racerName)

    local total = 0
    if (racers == 2 or racers == 1) and position == 1 then
        total = pot
    elseif racers == 3 and (position == 1 or position == 2) then
        total = Config.Splits['three'][position] * pot
        if UseDebug then print('Payout for ', position, total) end
    elseif racers > 3 and Config.Splits['more'][position] then
        total = Config.Splits['more'][position] * pot
        if UseDebug then print('Payout for ', position, total) end
    else
        if UseDebug then print('Racer finishing at postion', position, ' will not recieve a payout') end
    end
    if total > 0 then
        handleAddMoney(src, Config.Payments.racing, total, racerName)
    end
end

local function handOutParticipationTrophy(src, position, racerName)
    if Config.ParticipationTrophies.amount[position] then
        handleAddMoney(src, Config.Payments.participationPayout, Config.ParticipationTrophies.amount[position], racerName)
    end
end

local function handOutAutomationPayout(src, amount, racerName)
    if Config.Payments.automationPayout then
        handleAddMoney(src, Config.Payments.automationPayout, amount, racerName, 'extra_payout')
    end
end

local function changeRacerName(src, racerName)
    local result = RADB.changeRaceUser(Racing.Functions.GetCitizenId(src), racerName)
    if result then
        TriggerClientEvent('cw-racingapp:client:updateRacerNames', src)
    end
    return result
end

local function getRankingForRacer(racerName)
    if UseDebug then print('Fetching ranking for racer', racerName) end
    return RADB.getRaceUserRankingByName(racerName) or 0
end

local function updateRacerElo(source, racerName, eloChange)
    local currentRank = getRankingForRacer(racerName)
    RADB.updateRacerElo(racerName, eloChange)
    TriggerClientEvent('cw-racingapp:client:updateRanking', source, eloChange, currentRank + eloChange)
end

local function handleEloUpdates(results)
    RADB.updateEloForRaceResult(results)
    for _, racer in ipairs(results) do
        TriggerClientEvent('cw-racingapp:client:updateRanking', racer.RacerSource, racer.TotalChange,
            racer.Ranking + racer.TotalChange)
    end
end

local function resetTrack(raceId, reason)
    if UseDebug then
        print('^6Resetting race^0', raceId)
        print('Reason:', reason)
    end
    
    if not raceId or not Races[raceId] then
        if UseDebug then
            print('^3WARNING: Attempted to reset non-existent race ' .. tostring(raceId) .. '^0')
        end
        return
    end
    
    -- Limpa todos os corredores
    if Races[raceId].Racers then
        for citizenId, racerData in pairs(Races[raceId].Racers) do
            if racerData.RacerSource then
                leftRace(racerData.RacerSource)
            end
        end
        Races[raceId].Racers = {}
    end

        -- Reseta o estado da corrida
    Races[raceId].Started = false
    Races[raceId].Waiting = false
    Races[raceId].MaxClass = nil
    Races[raceId].Ghosting = false
    Races[raceId].GhostingTime = nil
    Races[raceId].SetupCitizenId = nil
    Races[raceId].AmountOfRacers = 0
    
    -- Remove da tabela Races após um delay para evitar conflitos
    SetTimeout(5000, function()
        if Races[raceId] then
            Races[raceId] = nil
            if UseDebug then
                print('^5Completely removed race ' .. raceId .. ' from Races table^0')
            end
        end
    end)
end

-- Adicione esta função para limpeza de corridas fantasmas
local function cleanupGhostRaces()
    if UseDebug then
        print('^5=== CLEANUP GHOST RACES ===^0')
        print('Races count:', #Races)
        print('AvailableRaces count:', #AvailableRaces)
    end
    
    local currentTime = os.time()
    local cleanedCount = 0
    
    -- Limpa AvailableRaces expiradas
    for raceId, raceData in pairs(AvailableRaces) do
        if raceData.ExpirationTime and currentTime > raceData.ExpirationTime then
            if UseDebug then
                print('Removing expired race from AvailableRaces:', raceId)
            end
            AvailableRaces[raceId] = nil
            cleanedCount = cleanedCount + 1
        end
    end
    
    -- Limpa Races sem corredores há muito tempo
    for raceId, raceData in pairs(Races) do
        if raceData and (not raceData.Racers or next(raceData.Racers) == nil) then
            local raceAge = currentTime - (raceData.CreatedTime or currentTime)
            if raceAge > 300 then -- 5 minutos
                if UseDebug then
                    print('Removing ghost race from Races:', raceId, 'Age:', raceAge)
                end
                Races[raceId] = nil
                cleanedCount = cleanedCount + 1
            end
        end
    end
    
    if UseDebug and cleanedCount > 0 then
        print('^5Cleaned ' .. cleanedCount .. ' ghost races^0')
    end
end

-- Adicione um timer para limpeza periódica
CreateThread(function()
    while true do
        Wait(300000) -- A cada 5 minutos
        cleanupGhostRaces()
    end
end)

local function createRaceResultsIfNotExisting(raceId)
    if UseDebug then print('Verifying race result table for ', raceId) end
    local existingResults = RaceResults[raceId]
    if not existingResults then
        if UseDebug then print('Initializing race result', raceId) end
        RaceResults[raceId] = {}
        return true
    end
    if not RaceResults[raceId].Result then
        if UseDebug then print('Initializing result table for', raceId) end
        RaceResults[raceId].Result = {}
    end
end

local function completeRace(amountOfRacers, raceData, availableKey)
    local totalLaps = raceData.TotalLaps
    if amountOfRacers == 1 then
        if UseDebug then print('^3Only one racer. No ELO change^0') end
    elseif amountOfRacers > 1 then
        if AvailableRaces[availableKey] and AvailableRaces[availableKey].Ranked then
            if UseDebug then print('Is ranked. Doing Elo check') end
            if UseDebug then print('^2 Pre elo', json.encode(RaceResults[raceData.RaceId].Result)) end
            local crewResult
            RaceResults[raceData.RaceId].Result, crewResult = calculateTrueSkillRatings(RaceResults[raceData.RaceId].Result)

            if UseDebug then print('^2 Post elo', json.encode(RaceResults[raceData.RaceId].Result)) end
            handleEloUpdates(RaceResults[raceData.RaceId].Result)
        end

        local crewResult
        if RaceResults[raceData.RaceId].Result then
            local _, tempCrewResult = calculateTrueSkillRatings(RaceResults[raceData.RaceId].Result)
            crewResult = tempCrewResult
        end

        if crewResult and #crewResult >= 1 then
            if UseDebug then print('Enough crews to give ranking') end
            HandleCrewEloUpdates(crewResult)
        end
        
        local raceEntryData = {
            raceId = raceData.RaceId,
            trackId = raceData.TrackId,
            results = RaceResults[raceData.RaceId].Result,
            amountOfRacers = amountOfRacers,
            laps = totalLaps,
            hostName = raceData.SetupRacerName,
            maxClass = raceData.MaxClass,
            ghosting = raceData.Ghosting,
            ranked = raceData.Ranked,
            reversed = Races[raceData.RaceId].Reversed,
            firstPerson = raceData.FirstPerson,
            automated = raceData.Automated,
            hidden = raceData.Hidden,
            silent = raceData.Silent,
            buyIn = raceData.BuyIn
        }

        RESDB.addRaceEntry(raceEntryData)
    end

    -- CORREÇÃO: Limpeza mais robusta do estado da corrida
    if UseDebug then
        print('^5COMPLETE RACE: Cleaning up race ' .. raceData.RaceId .. '^0')
        print('AvailableKey:', availableKey)
    end
    
    -- Remove da lista de corridas disponíveis
    if availableKey and AvailableRaces[availableKey] then
        AvailableRaces[availableKey] = nil
        if UseDebug then print('Removed from AvailableRaces') end
    end
    
    -- Limpa resultados da corrida
    if RaceResults[raceData.RaceId] then
        RaceResults[raceData.RaceId].Data.FinishTime = os.time()
        RaceResults[raceData.RaceId] = nil
    end
    
    -- Limpa lista de não finalizados
    if NotFinished[raceData.RaceId] then
        NotFinished[raceData.RaceId] = nil
    end
    
    -- Reseta o estado da corrida
    resetTrack(raceData.RaceId, 'Race completed and cleaned up')
    
    if UseDebug then
        print('^5Race ' .. raceData.RaceId .. ' completely cleaned up^0')
    end
end

RegisterNetEvent('cw-racingapp:server:finishPlayer',
    function(raceData, totalTime, totalLaps, bestLap, carClass, vehicleModel, ranking, racingCrew)
        local src = source
        local raceId = raceData.RaceId
        local availableKey = GetOpenedRaceKey(raceData.RaceId)
        local racerName = raceData.RacerName
        local playersFinished = 0
        local amountOfRacers = 0
        local reversed = Races[raceData.RaceId].Reversed

        if UseDebug then
            print('^3=== Finishing Racer: ' .. racerName .. ' ===^0')
        end

        local bestLapDef
        if totalLaps < 2 then
            if UseDebug then
                print('Sprint or 1 lap')
            end
            bestLapDef = totalTime
        else
            if UseDebug then
                print('2+ laps')
            end
            bestLapDef = bestLap
        end

        createRaceResultsIfNotExisting(raceData.RaceId)
        local raceResult = {
            TotalTime = totalTime,
            BestLap = bestLapDef,
            CarClass = carClass,
            VehicleModel = vehicleModel,
            RacerName = racerName,
            Ranking = ranking,
            RacerSource = src,
            RacingCrew = racingCrew
        }
        table.insert(RaceResults[raceId].Result, raceResult)

        local amountOfRacersThatLeft = 0
        if NotFinished and NotFinished[raceId] then
            if UseDebug then print('Race had racers that left before completion') end
           amountOfRacersThatLeft = #NotFinished[raceId]
        end

        for _, v in pairs(Races[raceId].Racers) do
            if v.Finished then
                playersFinished = playersFinished + 1
            end
            amountOfRacers = amountOfRacers + 1
        end
            RADB.increaseRaceCount(racerName, playersFinished)

        -- Reward logic
        local reward = 0
        local buyIn = Races[raceData.RaceId].BuyIn or 0

        if playersFinished == 1 then
            reward = buyIn * 2
        elseif playersFinished == 2 then
            reward = buyIn * 1.5
        elseif playersFinished == 3 then
            reward = buyIn * 1.2
        elseif playersFinished > 3 and playersFinished <= amountOfRacers then
            reward = buyIn * 0.5
        end

        if reward > 0 then
            local playerSrc = Racing.Functions.GetPlayerSource(racerName)
            if playerSrc then
                handleAddMoney(playerSrc, 'dirty', reward, racerName)
                RADB.addCryptoToRacer(racerName, reward)
                TriggerClientEvent('cw-racingapp:client:notify', playerSrc, 'Você ganhou ' .. reward .. ' de dinheiro na corrida!', 'success')
                if UseDebug then
                    print('^2DEBUG: ' .. racerName .. ' ganhou ' .. reward .. ' de dinheiro.^0')
                end
            else
                if UseDebug then
                    print('^1DEBUG: Could not find player source for racer: ' .. racerName .. '. Cannot give dirty money.^0')
                end
            end
        end

        if UseDebug then
            print('Total: ', totalTime)
            print('Best Lap: ', bestLapDef)
            print('Place:', playersFinished, Races[raceData.RaceId].BuyIn)
        end
        if Races[raceData.RaceId].BuyIn > 0 then
            giveSplit(src, amountOfRacers, playersFinished,
                Races[raceData.RaceId].BuyIn * Races[raceData.RaceId].AmountOfRacers, racerName)
        end

        -- Participation amount (global)
        if Config.ParticipationTrophies.enabled and Config.ParticipationTrophies.minimumOfRacers <= amountOfRacers then
            if UseDebug then print('Participation Trophies are enabled') end
            local distance = Tracks[raceData.TrackId].Distance
            if totalLaps > 1 then
                distance = distance * totalLaps
            end
            if distance > Config.ParticipationTrophies.minumumRaceLength then
                if not Config.ParticipationTrophies.requireBuyins or (Config.ParticipationTrophies.requireBuyins and Config.ParticipationTrophies.buyInMinimum >= Races[raceData.RaceId].BuyIn) then
                    if UseDebug then print('Participation Trophies buy in check passed', src) end
                    if not Config.ParticipationTrophies.requireRanked or (Config.ParticipationTrophies.requireRanked and AvailableRaces[availableKey].Ranked) then
                        if UseDebug then print('Participation Trophies Rank check passed, handing out to', src) end
                        handOutParticipationTrophy(src, playersFinished, racerName)
                    end
                end
            else
                if UseDebug then
                    print('Race length was to short: ', distance, ' Minumum required:',
                        Config.ParticipationTrophies.minumumRaceLength)
                end
            end
        end
        if UseDebug then
            print('Race has participation price', Races[raceData.RaceId].ParticipationAmount,
                Races[raceData.RaceId].ParticipationCurrency)
        end

        -- Participation amount (on this specific race)
        if Races[raceData.RaceId].ParticipationAmount and Races[raceData.RaceId].ParticipationAmount > 0 then
            local amountToGive = math.floor(Races[raceData.RaceId].ParticipationAmount)
            if Config.ParticipationAmounts.positionBonuses[playersFinished] then
                amountToGive = math.floor(amountToGive +
                    amountToGive * Config.ParticipationAmounts.positionBonuses[playersFinished])
            end
            if UseDebug then
                print('Race has participation price set', Races[raceData.RaceId].ParticipationAmount,
                    amountToGive, Races[raceData.RaceId].ParticipationCurrency)
            end
            handleAddMoney(src, Races[raceData.RaceId].ParticipationCurrency, amountToGive, racerName,
                'participation_trophy_crypto')
        end

        if Races[raceData.RaceId].Automated then
            if UseDebug then print('Race Was Automated', src) end
            if Config.AutomatedOptions.payouts then
                local payoutData = Config.AutomatedOptions.payouts
                if UseDebug then print('Automation Payouts exist', src) end
                local total = 0
                if payoutData.participation then total = total + payoutData.participation end
                if payoutData.perRacer then
                    total = total + payoutData.perRacer * amountOfRacers
                end
                if playersFinished == 1 and payoutData.winner then
                    total = total + payoutData.winner
                end
                handOutAutomationPayout(src, total, racerName)
            end
        end

        if BountyHandler then
            local bountyResult = BountyHandler.checkBountyCompletion(racerName, vehicleModel, ranking, raceData.TrackId,
                carClass, bestLapDef, totalLaps == 0, reversed)
            if bountyResult then
                addMoney(src, Config.Payments.bountyPayout, bountyResult)
                notifyPlayer(src, Lang("bounty_claimed") .. tostring(bountyResult),
                    'success')
            end
        end

        local raceType = 'Sprint'
        if totalLaps > 0 then raceType = 'Circuit' end

        -- PB check 
        local timeData = {
            trackId = raceData.TrackId,
            racerName = racerName,
            carClass = carClass,
            raceType = raceType,
            reversed = reversed,
            vehicleModel = vehicleModel,
            time = bestLapDef,
        }

        local newPb = RESDB.addTrackTime(timeData)
        if newPb then
            notifyPlayer(src,
                string.format(Lang("race_record"), raceData.RaceName, MilliToTime(bestLapDef)), 'success')
        end

        AvailableRaces[availableKey].RaceData = Races[raceData.RaceId]
        for _, racer in pairs(Races[raceData.RaceId].Racers) do
            TriggerClientEvent('cw-racingapp:client:playerFinish', racer.RacerSource, raceData.RaceId, playersFinished,
                racerName)
            leftRace(racer.RacerSource)
        end

        if playersFinished + amountOfRacersThatLeft == amountOfRacers then
            completeRace(amountOfRacers, raceData, availableKey)
        end

        if UseDebug then
            print('^2/=/ Finished Racer: ' .. racerName .. ' /=/^0')
        end
        handleAddMoney(src, 'dirty', 6000, racerName)
    end)




RegisterNetEvent('cw-racingapp:server:createTrack', function(RaceName, RacerName, Checkpoints)
    local src = source
    if UseDebug then print(src, RacerName, 'is creating a track named', RaceName) end

    if IsPermissioned(RacerName, 'create') then
        if IsNameAvailable(RaceName) then
            TriggerClientEvent('cw-racingapp:client:startRaceEditor', src, RaceName, RacerName, nil, Checkpoints)
        else
            notifyPlayer(src, Lang("race_name_exists"), 'error')
        end
    else
        notifyPlayer(src, Lang("no_permission"), 'error')
    end
end)

local function isToFarAway(src, trackId, reversed)
    if reversed then
        return Config.JoinDistance <=
            #(GetEntityCoords(GetPlayerPed(src)).xy - vec2(Tracks[trackId].Checkpoints[#Tracks[trackId].Checkpoints].coords.x, Tracks[trackId].Checkpoints[#Tracks[trackId].Checkpoints].coords.y))
    else
        return Config.JoinDistance <=
            #(GetEntityCoords(GetPlayerPed(src)).xy - vec2(Tracks[trackId].Checkpoints[1].coords.x, Tracks[trackId].Checkpoints[1].coords.y))
    end
end

RegisterNetEvent('cw-racingapp:server:joinRace', function(RaceData)
    local src = source
    local playerVehicleEntity = RaceData.PlayerVehicleEntity
    local raceName = RaceData.RaceName
    local raceId = RaceData.RaceId
    local trackId = RaceData.TrackId
    local availableKey = GetOpenedRaceKey(RaceData.RaceId)

    local citizenId = Racing.Functions.GetCitizenId(src)
    local currentRaceId = GetCurrentRace(citizenId)
    local racerName = RaceData.RacerName
    local racerCrew = RaceData.RacerCrew



    
    -- VERIFICAÇÃO DE SEGURANÇA ADICIONADA - Linha 635
    if not availableKey or not AvailableRaces[availableKey] then
        if UseDebug then
            print('ERROR: AvailableRaces[availableKey] is nil for key:', availableKey)
            print('Race might have been cancelled or does not exist anymore')
        end
        notifyPlayer(src, Lang("race_no_longer_available"), 'error')
        return
    end

    if isToFarAway(src, trackId, RaceData.Reversed) then
        if RaceData.Reversed then
            TriggerClientEvent('cw-racingapp:client:notCloseEnough', src,
                Tracks[trackId].Checkpoints[#Tracks[trackId].Checkpoints].coords.x,
                Tracks[trackId].Checkpoints[#Tracks[trackId].Checkpoints].coords.y)
        else
            TriggerClientEvent('cw-racingapp:client:notCloseEnough', src, Tracks[trackId].Checkpoints[1].coords.x,
                Tracks[trackId].Checkpoints[1].coords.y)
        end
        return
    end

    if not Races[raceId] or not Races[raceId].Started then


        if RaceData.BuyIn > 0 and not hasEnoughMoney(src, Config.Payments.racing, RaceData.BuyIn, racerName) then
            notifyPlayer(src, Lang("not_enough_money"))
        else
            if currentRaceId ~= nil then
                local amountOfRacers = 0
                local PreviousRaceKey = GetOpenedRaceKey(currentRaceId)
                for _, _ in pairs(Races[currentRaceId].Racers) do
                    amountOfRacers = amountOfRacers + 1
                end
                Races[currentRaceId].Racers[citizenId] = nil
                if (amountOfRacers - 1) == 0 then
                    if PreviousRaceKey then
                        AvailableRaces[PreviousRaceKey] = nil
                    end
                    notifyPlayer(src, Lang("race_last_person"))
                    TriggerClientEvent('cw-racingapp:client:leaveRace', src)
                    leftRace(src)
                else
                    if PreviousRaceKey and AvailableRaces[PreviousRaceKey] then
                        AvailableRaces[PreviousRaceKey].RaceData = Races[currentRaceId]
                    end
                    TriggerClientEvent('cw-racingapp:client:leaveRace', src)
                    leftRace(src)
                end
            end

            local amountOfRacers = 0
            for _, _ in pairs(Races[raceId].Racers) do
                amountOfRacers = amountOfRacers + 1
            end

            if amountOfRacers == 0 and not Races[raceId].Automated then
    
                Races[raceId].SetupCitizenId = citizenId
            end

            Races[raceId].AmountOfRacers = amountOfRacers + 1


            if RaceData.BuyIn > 0 then
                if not handleRemoveMoney(src, Config.Payments.racing, RaceData.BuyIn, racerName) then
                    return
                end
            end

            Races[raceId].Racers[citizenId] = {
                Checkpoint = 1,
                Lap = 1,
                Finished = false,
                RacerName = racerName,
                RacerCrew = racerCrew,
                Placement = 0,
                PlayerVehicleEntity = playerVehicleEntity,
                RacerSource = src,
                CheckpointTimes = {},
            }

            -- VERIFICAÇÃO ADICIONAL - Linha onde estava ocorrendo o erro

            if AvailableRaces[availableKey] then
                AvailableRaces[availableKey].RaceData = Races[raceId]
            else
                if UseDebug then 
                    -- print('DEBUG: AvailableRaces[availableKey] is nil for key:', availableKey)
                    -- print('Race might have been removed during join process')
                end
                notifyPlayer(src, Lang("race_no_longer_available"), 'error')
                Races[raceId].Racers[citizenId] = nil
                return
            end

            TriggerClientEvent('cw-racingapp:client:joinRace', src, Races[raceId], Tracks[trackId].Checkpoints, RaceData.Laps, racerName)
            
            for _, racer in pairs(Races[raceId].Racers) do
                TriggerClientEvent('cw-racingapp:client:updateActiveRacers', racer.RacerSource, raceId,
                    Races[raceId].Racers)
            end

            if not Races[raceId].Automated then
                -- VERIFICAÇÃO ADICIONAL para evitar erro na linha 635
                if AvailableRaces[availableKey] and AvailableRaces[availableKey].SetupCitizenId then
                    local creatorsource = Racing.Functions.GetSrcOfPlayerByCitizenId(AvailableRaces[availableKey].SetupCitizenId)
                    if creatorsource ~= nil and creatorsource ~= src then
                        if UseDebug then
                            print("DEBUG: Notifying creator about join")
                        end
                        notifyPlayer(creatorsource, Lang("race_someone_joined"))
                    end
                end
            end
        end
    else
        notifyPlayer(src, Lang("race_already_started"))
    end
end)

local function assignNewOrganizer(raceId, src)
    for citId, racerData in pairs(Races[raceId].Racers) do
        if citId ~= Racing.Functions.GetCitizenId(src) then
            Races[raceId].SetupCitizenId = citId
            notifyPlayer(racerData.RacerSource, Lang("new_host"))
            for _, racer in pairs(Races[raceId].Racers) do
                TriggerClientEvent('cw-racingapp:client:updateOrganizer', racer.RacerSource, raceId, citId)
            end
            return
        end
    end
end

local function leaveCurrentRace(src)
    TriggerClientEvent('cw-racingapp:server:leaveCurrentRace', src)    
end exports('leaveCurrentRace', leaveCurrentRace)

RegisterNetEvent('cw-racingapp:server:leaveCurrentRace', function(src)
    leaveCurrentRace(src)
end)

RegisterNetEvent('cw-racingapp:server:leaveRace', function(RaceData, reason)
    if UseDebug then
        print('Player left race', source)
        print('Reason:', reason)
        print(json.encode(RaceData, { indent = true }))
    end
    local src = source
    local citizenId = Racing.Functions.GetCitizenId(src)

    if not citizenId then print('ERROR: Could not find identifier for player with src', src) return end

    local racerName = RaceData.RacerName

    local raceId = RaceData.RaceId
    local availableKey = GetOpenedRaceKey(raceId)


    if not Races[raceId].Automated then
        local creator = Racing.Functions.GetSrcOfPlayerByCitizenId(AvailableRaces[availableKey].SetupCitizenId)

        if creator then
            notifyPlayer(creator, Lang("race_someone_left"))
        end
    end

    local amountOfRacers = 0
    local playersFinished = 0
    for _, v in pairs(Races[raceId].Racers) do
        if v.Finished then
            playersFinished = playersFinished + 1
        end
        amountOfRacers = amountOfRacers + 1
    end
    if NotFinished[raceId] ~= nil then
        NotFinished[raceId][#NotFinished[raceId] + 1] = {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = racerName
        }
    else
        NotFinished[raceId] = {}
        NotFinished[raceId][#NotFinished[raceId] + 1] = {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = racerName
        }
    end
    -- Races[raceId].Racers[citizenId] = nil
    if Races[raceId].SetupCitizenId == citizenId then
        assignNewOrganizer(raceId, src)
    end

    -- Check if last racer
    if (amountOfRacers - 1) == 0 then
        -- Complete race if leaving last
        if not Races[raceId].Automated then
            if UseDebug then print(citizenId, ' was the last racer. ^3Cancelling race^0') end
            resetTrack(raceId, 'last racer left')
            AvailableRaces[availableKey] = nil
            notifyPlayer(src, Lang("race_last_person"))
            NotFinished[raceId] = nil
        else
            if UseDebug then print(citizenId, ' was the last racer. ^Race was Automated. No cancel.^0') end
        end
    else
        AvailableRaces[availableKey].RaceData = Races[raceId]
    end
    if playersFinished == amountOfRacers - 1 then
        if UseDebug then print('Last racer to leave') end
        completeRace(amountOfRacers, RaceData, availableKey)
    end

    TriggerClientEvent('cw-racingapp:client:leaveRace', src)
    leftRace(src)

    for _, racer in pairs(Races[raceId].Racers) do
        TriggerClientEvent('cw-racingapp:client:updateRaceRacers', racer.RacerSource, raceId, Races[raceId].Racers)
    end
    if RaceData.Ranked and RaceData.Started and RaceData.TotalRacers > 1 and reason then
        if Config.EloPunishments[reason] then
            updateRacerElo(src, racerName, Config.EloPunishments[reason])
        end
    end
end)

local function createTimeoutThread(raceId)
    CreateThread(function()
        local count = 0
        while Races[raceId] and Races[raceId].Waiting do
            Wait(1000)
            if count < Config.TimeOutTimerInMinutes * 60 then
                count = count + 1
            else
                local availableKey = GetOpenedRaceKey(raceId)
                if UseDebug then print('AvailableKey', availableKey) end
                if Races[raceId].Automated then
                    if UseDebug then print('Track Timed Out. Automated') end
                    local amountOfRacers = getAmountOfRacers(raceId)
                    if amountOfRacers >= Config.AutomatedOptions.minimumParticipants then
                        if UseDebug then print('Enough Racers to start automated') end
                        if AvailableRaces[raceId] then
                            TriggerEvent('cw-racingapp:server:startRace', raceId)
                        else
                            print('DEBUG: AvailableRaces[' .. raceId .. '] is nil before starting automated race.')
                        end
                    else
                        SetTimeout(Config.AutomatedOptions.timeToWaitForPlayers, function()
                            if Races[raceId] and next(Races[raceId].Racers) == nil then
                                AvailableRaces[availableKey] = nil
                                resetTrack(raceId, 'timed out waiting for players')

                                local currentAmountOfRacers = getAmountOfRacers(raceId)
                                if currentAmountOfRacers > 0 then
                                    for cid, _ in pairs(Races[raceId].Racers) do
                                        local racerSource = Racing.Functions.GetSrcOfPlayerByCitizenId(cid)
                                        if racerSource ~= nil then
                                            notifyPlayer(racerSource, Lang("race_timed_out"),
                                                'error')
                                            TriggerClientEvent('cw-racingapp:client:leaveRace', racerSource)
                                            leftRace(racerSource)
                                        end
                                    end
                                end
                            end
                        end)
                    end
                else
                    if UseDebug then print('Track Timed Out. NOT automated', raceId) end
                    for cid, _ in pairs(Races[raceId].Racers) do
                        local racerSource = Racing.Functions.GetSrcOfPlayerByCitizenId(cid)
                        if racerSource then
                            notifyPlayer(racerSource, Lang("race_timed_out"), 'error')
                            TriggerClientEvent('cw-racingapp:client:leaveRace', racerSource)
                            leftRace(racerSource)
                        end
                    end
                    AvailableRaces[availableKey] = nil
                    resetTrack(raceId, 'Timed out, Not automated')
                end
            end
        end
    end)
end

local function joinRaceByRaceId(raceId, src)
    if src and raceId then
        TriggerClientEvent('cw-racingapp:client:joinRaceByRaceId', src, raceId)
        return true
    else
        -- print('Attempted to join a race but was lacking input')
        -- print('raceid:', raceId)
        -- print('src:', src)
        return false
    end
end exports('joinRaceByRaceId', joinRaceByRaceId)

-- Modifique a função setupRace para adicionar timestamp de criação
local function setupRace(setupData, src)
    local trackId = setupData.trackId
    local laps = setupData.laps
    local racerName = setupData.hostName or Config.AutoMatedRacesHostName
    local maxClass = setupData.maxClass
    local ghostingEnabled = setupData.ghostingEnabled
    local ghostingTime = setupData.ghostingTime
    local buyIn = setupData.buyIn
    local ranked = setupData.ranked
    local reversed = setupData.reversed
    local participationAmount = setupData.participationMoney
    local participationCurrency = setupData.participationCurrency
    local firstPerson = setupData.firstPerson
    local automated = setupData.automated
    local hidden = setupData.hidden
    local silent = setupData.silent
                         
    if not HostingIsAllowed then
        if src then notifyPlayer(src, Lang("hosting_not_allowed"), 'error') end
        return
    end

    local raceId = GenerateRaceId()

    if UseDebug then
        print('Setting up race', 'RaceID: '..raceId, json.encode(setupData))
    end
    
    if not src then
        if UseDebug then
            print('No Source was included. Defaulting to Automated')
        end
        automated = true
    end

     if Tracks[trackId] ~= nil then
        -- CORREÇÃO: Verifica se já existe uma corrida com este ID
        if Races[raceId] then
            if UseDebug then
                print('^3WARNING: Race ID ' .. raceId .. ' already exists, generating new one^0')
            end
            raceId = GenerateRaceId()
        end

        Races[raceId] = {}
        if not Races[raceId].Waiting then
            if not Races[raceId].Started then
                local setupId = 0
                if src then
                    setupId = Racing.Functions.GetCitizenId(src)
                end
                if Tracks[trackId] then
                    Tracks[trackId].NumStarted = Tracks[trackId].NumStarted + 1
                else
                    print('ERROR: Could not find track id', trackId)
                end

                local expirationTime = os.time() + 60 * Config.TimeOutTimerInMinutes

                -- CORREÇÃO: Adiciona timestamp de criação
                Races[raceId].RaceId = raceId
                Races[raceId].TrackId = trackId
                Races[raceId].RaceName = Tracks[trackId].RaceName
                Races[raceId].Waiting = true
                Races[raceId].Started = false
                Races[raceId].Automated = automated
                Races[raceId].SetupRacerName = racerName
                Races[raceId].SetupCitizenId = setupId
                Races[raceId].Ghosting = ghostingEnabled
                Races[raceId].GhostingTime = ghostingTime
                Races[raceId].BuyIn = buyIn
                Races[raceId].Ranked = ranked
                Races[raceId].Laps = laps
                Races[raceId].Reversed = reversed
                Races[raceId].FirstPerson = firstPerson
                Races[raceId].Hidden = hidden
                Races[raceId].ParticipationAmount = tonumber(participationAmount)
                Races[raceId].ParticipationCurrency = participationCurrency
                Races[raceId].ExpirationTime = expirationTime
                Races[raceId].CreatedTime = os.time() -- CORREÇÃO: Timestamp de criação
                Races[raceId].Racers = {}

                local allRaceData = {
                    TrackData = Tracks[trackId],
                    RaceData = Races[raceId],
                    Laps = laps,
                    RaceId = raceId,
                    RaceName = Races[raceId].RaceName,
                    TrackId = trackId,
                    SetupCitizenId = setupId,
                    SetupRacerName = racerName,
                    Ghosting = ghostingEnabled,
                    GhostingTime = ghostingTime,
                    BuyIn = buyIn,
                    Ranked = ranked,
                    Reversed = reversed,
                    ParticipationAmount = participationAmount,
                    ParticipationCurrency = participationCurrency,
                    FirstPerson = firstPerson,
                    ExpirationTime = expirationTime,
                    Hidden = hidden,
                    Checkpoints = Tracks[trackId].Checkpoints,
                }
                
                -- CORREÇÃO: Verifica se a chave já existe
                if AvailableRaces[raceId] then
                    if UseDebug then
                        print('^3WARNING: AvailableRaces key ' .. raceId .. ' already exists, overwriting^0')
                    end
                end
                
                AvailableRaces[raceId] = allRaceData

                local policeService, totalPolice = vRP.NumPermission("Policia")
                if totalPolice > 0 then
                    local raceCoords = allRaceData.Checkpoints[1].coords
                    for passports, sources in pairs(policeService) do
                        async(function()
                            TriggerClientEvent("NotifyPush", sources, { code = 32, title = "Corrida Ilegal Detectada", x = raceCoords.x, y = raceCoords.y, z = raceCoords.z, criminal = "ID da Corrida: " .. raceId .. ", Pista: " .. trackId, blipColor = 22 })
                        end)
                    end
                end
                
                if not automated then
                    notifyPlayer(src, Lang("race_created"), 'success')
                    TriggerClientEvent('cw-racingapp:client:readyJoinRace', src, allRaceData)
                end

                RaceResults[raceId] = { Data = allRaceData, Result = {} }

                if Config.NotifyRacers and not silent then
                    TriggerClientEvent('cw-racingapp:client:notifyRacers', -1, 'New Race Available')
                end
                
                createTimeoutThread(raceId)
                
                if UseDebug then
                    print('^2Successfully created race ' .. raceId .. '^0')
                end
                
                return raceId
            else
                if src then notifyPlayer(src, Lang("race_already_started"), 'error') end
                return false
            end
        else
            if src then notifyPlayer(src, Lang("race_already_started"), 'error') end
            return false
        end
    else
        if src then notifyPlayer(src, Lang("race_doesnt_exist"), 'error') end
        return false
    end
end

-- Adicione um comando para debug do estado das corridas
if Config.EnableCommands then
    registerCommand('cwracecleanup', 'Cleanup ghost races', {}, true, function(source, args)
        cleanupGhostRaces()
        notifyPlayer(source, 'Ghost races cleanup executed', 'success')
    end, true)

    registerCommand('cwracestate', 'Show current race state', {}, true, function(source, args)
        print("=== RACES STATE ===")
        print("Races table:")
        for raceId, raceData in pairs(Races) do
            print("  " .. raceId .. ": " .. (raceData.RaceName or "Unknown") .. 
                  " - Racers: " .. (raceData.Racers and #raceData.Racers or 0) ..
                  " - Waiting: " .. tostring(raceData.Waiting) ..
                  " - Started: " .. tostring(raceData.Started))
        end
        
        print("AvailableRaces table:")
        for raceId, raceData in pairs(AvailableRaces) do
            print("  " .. raceId .. ": " .. (raceData.RaceName or "Unknown"))
        end
        print("===================")
    end, true)
end

RegisterServerCallback('cw-racingapp:server:setupRace', function(source, setupData)
    local src = source
    if not Tracks[setupData.trackId] then
       notifyPlayer(src, Lang("no_track_found").. tostring(setupData.trackId), 'error')
    end
    if isToFarAway(src, setupData.trackId, setupData.reversed) then
        if setupData.reversed then
            TriggerClientEvent('cw-racingapp:client:notCloseEnough', src,
                Tracks[setupData.trackId].Checkpoints[#Tracks[setupData.trackId].Checkpoints].coords.x,
                Tracks[setupData.trackId].Checkpoints[#Tracks[setupData.trackId].Checkpoints].coords.y)
        else
            TriggerClientEvent('cw-racingapp:client:notCloseEnough', src,
                Tracks[setupData.trackId].Checkpoints[1].coords.x, Tracks[setupData.trackId].Checkpoints[1].coords.y)
        end
        return false
    end
    if (setupData.buyIn > 0 and not hasEnoughMoney(src, Config.Payments.racing, setupData.buyIn, setupData.hostName)) then
        notifyPlayer(src, Lang("not_enough_money"))
    else
        setupData.automated = false
        return setupRace(setupData, src)
    end
end)

-- AUTOMATED RACES SETUP
local function generateAutomatedRace()
    if not AutoHostIsAllowed then
        -- if UseDebug then print('Auto hosting is not allowed') end
        return
    end
    local race = Config.AutomatedRaces[math.random(1, #Config.AutomatedRaces)]
    if race == nil or race.trackId == nil then
        -- if UseDebug then print('Race Id for generated track was nil, your Config might be incorrect') end
        return
    end
    if Tracks[race.trackId] == nil then
        -- if UseDebug then print('ID' .. race.trackId .. ' does not exist in tracks list') end
        return
    end
    if raceWithTrackIdIsActive(race.trackId) then
        if UseDebug then print('Automation: Race on track is already active, skipping Automated') end
        return
    end
    -- if UseDebug then print('Creating new Automated Race from', race.trackId) end
    local ranked = race.ranked
    if ranked == nil then
        if UseDebug then print('Automation: ranked was not set. defaulting to ranked = true') end
        ranked = true
    end
    local reversed = race.reversed
    if reversed == nil then
        if UseDebug then print('Automation: rank was not set. defaulting to reversed = false') end
        reversed = false
    end
    race.automated = true

    setupRace(race, nil)
end

-- Adicione esta função para debug detalhado
local function debugAvailableRaces()
    if UseDebug then
        -- -- print('=== DEBUG AvailableRaces ===')
        print('Count:', #AvailableRaces)
        for k, v in pairs(AvailableRaces) do
            print('['..k..'] RaceId:', v.RaceId, 'TrackId:', v.TrackId, 'SetupCitizenId:', v.SetupCitizenId)
        end
        print('=== END DEBUG ===')
    end
end
RegisterNetEvent('cw-racingapp:server:newAutoHost', function()
    generateAutomatedRace()
end)

if Config.AutomatedOptions and Config.AutomatedRaces then
    CreateThread(function()
        if #Config.AutomatedRaces == 0 then
            if UseDebug then print('^3No automated races in list') end
            return
        end
        while true do
            if not UseDebug then Wait(Config.AutomatedOptions.timeBetweenRaces) else Wait(1000) end
            generateAutomatedRace()
            Wait(Config.AutomatedOptions.timeBetweenRaces)
        end
    end)
end

RegisterNetEvent('cw-racingapp:server:updateRaceState', function(raceId, started, waiting)
    Races[raceId].Waiting = waiting
    Races[raceId].Started = started
end)

local function timer(raceId)
    local trackId = getTrackIdByRaceId(raceId)
    local NumStartedAtTimerCreation = Tracks[trackId].NumStarted
    if UseDebug then
        print('============== Creating timer for ' ..
            raceId .. ' with numstarted: ' .. NumStartedAtTimerCreation .. ' ==============')
    end
    SetTimeout(Config.RaceResetTimer, function()
        if UseDebug then print('============== Checking timer for ' .. raceId .. ' ==============') end
        if NumStartedAtTimerCreation ~= Tracks[trackId].NumStarted then
            if UseDebug then
                print('============== A new race has been created on this track. Canceling ' ..
                    trackId .. ' ==============')
            end
            return
        end
        if next(Races[raceId].Racers) == nil then
            if UseDebug then print('Race is finished. Canceling timer ' .. raceId .. '') end
            return
        end
        if math.abs(GetGameTimer() - Timers[raceId]) < Config.RaceResetTimer then
            Timers[raceId] = GetGameTimer()
            timer(raceId)
        else
            if UseDebug then print('Cleaning up race ' .. raceId) end
            for _, racer in pairs(Races[raceId].Racers) do
                TriggerClientEvent('cw-racingapp:client:leaveRace', racer.RacerSource)
                leftRace(racer.RacerSource)
            end
            resetTrack(raceId, 'Idle race')
            NotFinished[raceId] = nil
            local AvailableKey = GetOpenedRaceKey(trackId)
            if AvailableKey then
                AvailableRaces[AvailableKey] = nil
            end
        end
    end)
end

local function startTimer(raceId)
    if UseDebug then print('Starting timer', raceId) end
    Timers[raceId] = GetGameTimer()
    timer(raceId)
end

local function updateTimer(raceId)
    if UseDebug then print('Updating timer', raceId) end
    Timers[raceId] = GetGameTimer()
end

RegisterNetEvent('cw-racingapp:server:updateRacerData', function(raceId, checkpoint, lap, finished, raceTime)
    local src = source
    local citizenId = Racing.Functions.GetCitizenId(src)
    if Races[raceId].Racers[citizenId] then
        Races[raceId].Racers[citizenId].Checkpoint = checkpoint
        Races[raceId].Racers[citizenId].Lap = lap
        Races[raceId].Racers[citizenId].Finished = finished
        Races[raceId].Racers[citizenId].RaceTime = raceTime

        Races[raceId].Racers[citizenId].CheckpointTimes[#Races[raceId].Racers[citizenId].CheckpointTimes + 1] = {
            lap =
                lap,
            checkpoint = checkpoint,
            time = raceTime
        }

        for _, racer in pairs(Races[raceId].Racers) do
            if GetPlayerName(racer.RacerSource) then 
                TriggerClientEvent('cw-racingapp:client:updateRaceRacerData', racer.RacerSource, raceId, citizenId,
                    Races[raceId].Racers[citizenId])
            else
                if UseDebug then 
                    print('^1Could not find player with source^0', racer.RacerSource)
                    print(json.encode(racer, {indent=true})) 
                end
            end
        end
    else
        -- Attemt to make sure script dont break if something goes wrong
        notifyPlayer(src, Lang("youre_not_in_the_race"), 'error')
        TriggerClientEvent('cw-racingapp:client:leaveRace', -1, nil)
        leftRace(src)
    end
    if Config.UseResetTimer then updateTimer(raceId) end
end)

RegisterNetEvent('cw-racingapp:server:startRace', function(raceId)
    -- Notifica a polícia sobre a corrida ilegal
    local playerPed = GetPlayerPed(source)
    local coords = GetEntityCoords(playerPed)
    local policeService = vRP.NumPermission("Policia")
    for _, policeSource in pairs(policeService) do
        async(function()
            TriggerClientEvent("NotifyPush", policeSource, { code = 31, title = "Corrida Ilegal", x = coords.x, y = coords.y, z = coords.z, criminal = "Corrida ilegal iniciada!", blipColor = 44 })
        end)
    end

    if UseDebug then print(source, 'is starting race', raceId) end
    local src = source
    local AvailableKey = GetOpenedRaceKey(raceId)

    if Races[raceId] and Races[raceId].Started then
        if UseDebug then print('Race was already started', raceId) end
        return
    end

    if not raceId then
        if src then notifyPlayer(src, Lang("not_in_race"), 'error') end
        return
    end

    if not AvailableRaces[AvailableKey] then
        if UseDebug then print('Could not find available race', raceId) end
        return
    end

    if next(Races[raceId].Racers) == nil then
        if UseDebug then print('DEBUG: Attempted to start race ' .. raceId .. ' with no racers.') end
        return
    end

    Races[raceId].Started = true
    Races[raceId].Waiting = false
    TriggerClientEvent('cw-racingapp:client:startRace', -1, raceId)

    if not AvailableRaces[AvailableKey].RaceData then
        if UseDebug then print('Could not find available race data', raceId) end
        return
    end
    local TotalRacers = 0
    for _, _ in pairs(Races[raceId].Racers) do
        TotalRacers = TotalRacers + 1
    end
    if UseDebug then print('Total Racers', TotalRacers) end
    for _, racer in pairs(Races[raceId].Racers) do
        if racer.RacerSource ~= nil then
            TriggerClientEvent('cw-racingapp:client:raceCountdown', racer.RacerSource, TotalRacers)
            setInRace(racer.RacerSource, raceId)
        end
    end
    if Config.UseResetTimer then startTimer(raceId) end
end)

RegisterNetEvent('cw-racingapp:server:getRaceData', function(raceId)
    local src = source
    if Races[raceId] then
        TriggerClientEvent('cw-racingapp:client:receiveRaceData', src, Races[raceId])
    else
        TriggerClientEvent('cw-racingapp:client:receiveRaceData', src, nil)
    end
end)


RegisterNetEvent('cw-racingapp:server:saveTrack', function(trackData)
    local src = source
    local citizenId = Racing.Functions.GetCitizenId(src)
    local trackId
    if trackData.TrackId ~= nil then
        trackId = trackData.TrackId
    else
        trackId = GenerateTrackId()
    end
    local checkpoints = {}
    for k, v in pairs(trackData.Checkpoints) do
        checkpoints[k] = {
            offset = v.offset,
            coords = v.coords
        }
    end

    if trackData.IsEdit then
        print('Saving over previous track', trackData.TrackId)
        RADB.setTrackCheckpoints(checkpoints, trackData.TrackId)
        Tracks[trackId].Checkpoints = checkpoints
    else
        Tracks[trackId] = {
            RaceName = trackData.RaceName,
            Checkpoints = checkpoints,
            Creator = citizenId,
            CreatorName = trackData.RacerName,
            TrackId = trackId,
            Started = false,
            Waiting = false,
            Distance = math.ceil(trackData.RaceDistance),
            Racers = {},
            Metadata = DeepCopy(DefaultTrackMetadata),
            Access = {},
            LastLeaderboard = {},
            NumStarted = 0,
        }
        RADB.createTrack(trackData, checkpoints, citizenId, trackId)
    end
end)

RegisterNetEvent('cw-racingapp:server:deleteTrack', function(trackId)
    RADB.deleteTrack(trackId)
    Tracks[trackId] = nil
end)

RegisterNetEvent('cw-racingapp:server:removeRecord', function(record)
    if UseDebug then print('Removing record', json.encode(record, { indent = true })) end
    RESDB.removeTrackRecord(record.id)
end)

RegisterNetEvent('cw-racingapp:server:clearLeaderboard', function(trackId)
    RESDB.clearTrackRecords(trackId)
end)

RegisterServerCallback('cw-racingapp:server:getRaceResults', function(source, amount)
    local limit = amount or 10
    local result = RESDB.getRecentRaces(limit)
    for i, track in ipairs(result) do
        result[i].raceName = Tracks[track.trackId].RaceName
    end
    return result
end)

RegisterServerCallback('cw-racingapp:server:getAllRacers', function(source)
    if UseDebug then print('Fetching all racers') end
    local allRacers = RADB.getAllRacerNames()
    if UseDebug then print("^2Result", json.encode(allRacers)) end
    return allRacers
end)

RegisterServerCallback('cw-racingapp:server:isFirstUser', function(source)
    -- if UseDebug then print('Is first user:', IsFirstUser) end
    return IsFirstUser
end)

-----------------------
----   Functions   ----
-----------------------

function MilliToTime(milli)
    local milliseconds = milli % 1000;
    milliseconds = tostring(milliseconds)
    local seconds = math.floor((milli / 1000) % 60);
    local minutes = math.floor((milli / (60 * 1000)) % 60);
    if minutes < 10 then
        minutes = "0" .. tostring(minutes);
    else
        minutes = tostring(minutes)
    end
    if seconds < 10 then
        seconds = "0" .. tostring(seconds);
    else
        seconds = tostring(seconds)
    end
    return minutes .. ":" .. seconds .. "." .. milliseconds;
end

function IsPermissioned(racerName, type)
    local auth = RADB.getUserAuth(racerName)
    if not auth then
        if UseDebug then print('Could not find user with this racer Name', racerName) end
        return false
    end
    if UseDebug then print(racerName, 'has auth', auth) end
    return Config.Permissions[auth][type]
end

function IsNameAvailable(trackname)
    local retval = true
    for trackId, _ in pairs(Tracks) do
        if Tracks[trackId].RaceName == trackname then
            retval = false
            break
        end
    end
    -- if UseDebug then print('DEBUG: GetOpenedRaceKey returning:', retval) end
    return retval
end

function GetOpenedRaceKey(raceId)
    if not raceId then
        return nil
    end
    
    for key, race in pairs(AvailableRaces) do
        if race and race.RaceId == raceId then
            return key
        end
    end
    return nil
end
    

function GetCurrentRace(citizenId)
    for raceId, race in pairs(Races) do
        for cid, _ in pairs(race.Racers) do
            if cid == citizenId then
                return raceId
            end
        end
    end
end

function GetRaceId(name)
    for k, v in pairs(Tracks) do
        if v.RaceName == name then
            return k
        end
    end
    return nil
end

function GenerateTrackId()
    local trackId = "LR-" .. math.random(1000, 9999)
    while Tracks[trackId] ~= nil do
        trackId = "LR-" .. math.random(1000, 9999)
    end
    return trackId
end

function GenerateRaceId()
    local raceId = "RI-" .. math.random(100000, 999999)
    while Races[raceId] ~= nil do
        raceId = "RI-" .. math.random(100000, 999999)
    end
    return raceId
end

function openRacingApp(source)
    -- if UseDebug then print('opening ui') end

    TriggerClientEvent('cw-racingapp:client:openUi', source)
end

exports('openRacingApp', openRacingApp)

RegisterServerCallback('cw-racingapp:server:cancelRace', function(source, raceId)
    local src = source
    if UseDebug then
        print('Player is canceling race', src, raceId)
    end
    if not raceId or not Races[raceId] then return false end

    for _, racer in pairs(Races[raceId].Racers) do
        notifyPlayer(racer.RacerSource, Lang("race_canceled"),
            'error')
        TriggerClientEvent('cw-racingapp:client:leaveRace', racer.RacerSource, Races[raceId])
        leftRace(racer.RacerSource)
    end
    Wait(500)
    local availableKey = GetOpenedRaceKey(raceId)
    -- if UseDebug then print('Available Key', availableKey) end
    AvailableRaces[availableKey] = nil
    resetTrack(raceId, 'Manually canceled by src ' .. tostring(src or 'UNKNOWN'))
    return true
end)


RegisterServerCallback('cw-racingapp:server:getAvailableRaces', function(source)
    return AvailableRaces
end)

RegisterServerCallback('cw-racingapp:server:getRaceRecordsForTrack', function(source, trackId)
    return RESDB.getAllBestTimesForTrack(trackId)
end)

RegisterServerCallback('cw-racingapp:server:getTracks', function(source)
    return Tracks
end)

RegisterServerCallback('cw-racingapp:server:getTracksTrimmed', function(source)
    local tracksWithoutCheckpoints = DeepCopy(Tracks)
    for i, track in pairs(tracksWithoutCheckpoints) do
        tracksWithoutCheckpoints[i] = track
        tracksWithoutCheckpoints[i].Checkpoints = nil
    end
    return tracksWithoutCheckpoints
end)

local function getTracks()
    return Tracks    
end exports('getTracks', getTracks)

local function getRaces()
    return Races
end exports('getRaces', getRaces)

RegisterServerCallback('cw-racingapp:server:getRaces', function(source)
    return Races
end)

RegisterServerCallback('cw-racingapp:server:getTrackData', function(source, trackId)
    return Tracks[trackId] or false
end)

RegisterServerCallback('cw-racingapp:server:getAccess', function(source, trackId)
    local track = Tracks[trackId]
    return track.Access or 'NOTHING'
end)

RegisterNetEvent('cw-racingapp:server:setAccess', function(trackId, access)
    local src = source
    if UseDebug then
        print('source ', src, 'has updated access for', trackId)
        print(json.encode(access))
    end
    local res = RADB.setAccessForTrack(access, trackId)
    if res then
        if res == 1 then
            notifyPlayer(src, Lang("access_updated"), "success")
        end
        Tracks[trackId].Access = access
    end
end)

RegisterServerCallback('cw-racingapp:server:isAuthorizedToCreateRaces', function(source, trackName, racerName)
    return { permissioned = IsPermissioned(racerName, 'create'), nameAvailable = IsNameAvailable(trackName) }
end)


local function nameIsValid(racerName, citizenId)
    local result = RADB.getRaceUserByName(racerName)
    if result then
        if result.citizenid == citizenId then
            return true
        end
        return false
    else
        return true
    end
end

local function addRacerName(citizenId, racerName, targetSource, auth, creatorCitizenId)
    if not RADB.getRaceUserByName(racerName) then
        IsFirstUser = false
        RADB.createRaceUser(citizenId, racerName, auth, creatorCitizenId)
        Wait(500)
        TriggerClientEvent('cw-racingapp:client:updateRacerNames', tonumber(targetSource))
        return true
    end
    return false
end

RegisterServerCallback('cw-racingapp:server:getAmountOfTracks', function(source, citizenId)
    if Config.UseNameValidation then
        local tracks = RADB.getTracksByCitizenId(citizenId)
        return #tracks
    else
        return 0
    end
end)

RegisterServerCallback('cw-racingapp:server:nameIsAvailable', function(source, racerName, serverId)
    if UseDebug then
        print('checking availability for',
            json.encode({ racerName = racerName, sererId = serverId }, { indent = true }))
    end
    if Config.UseNameValidation then
        local citizenId = Racing.Functions.GetCitizenId(serverId)
        if nameIsValid(racerName, citizenId) then
            return true
        else
            return false
        end
    else
        return true
    end
end)

local function getActiveRacerName(raceUsers, source)
    if UseDebug then print('^2DEBUG: getActiveRacerName - Source recebida:', source, '^0') end
    
    -- Aguarda o vRP estar pronto para este jogador
    local maxAttempts = 15  -- Aumentei para 15 tentativas
    local attempts = 0
    local user_id = nil
    
    while attempts < maxAttempts do
        if vRP and vRP.Passport then
            user_id = vRP.Passport(source)
            if user_id and user_id > 0 then
                if UseDebug then print('^2DEBUG: User ID obtido com sucesso:', user_id, '^0') end
                break
            end
        end
        attempts = attempts + 1
        if UseDebug then
            print('^3DEBUG: Aguardando user_id... Tentativa', attempts, 'de', maxAttempts, '^0')
        end
        Wait(500) -- Aguarda 500ms entre tentativas
    end
    
    if not user_id then
        if UseDebug then 
            print('^1DEBUG: getActiveRacerName - Não foi possível obter user_id para source:', source, ' após ', attempts, ' tentativas^0')
        end
        return nil
    end

    if UseDebug then print('^2DEBUG: getActiveRacerName - vRP.Passport(source) retornou:', user_id, '^0') end

    -- Aguarda um pouco mais para garantir que o banco de dados está pronto
    Wait(300)

    -- Get all racers for this citizenId
    local allRacersForCitizen = RADB.getRaceUsersBelongingToCitizenId(tostring(user_id))
    
    if UseDebug then
        print('^2DEBUG: getActiveRacerName - Racers encontrados para user_id', user_id, ':', json.encode(allRacersForCitizen), '^0')
    end

    local activeRacer = nil

    -- Procura por um corredor ativo
    for _, racer in pairs(allRacersForCitizen) do
        if racer.active == 1 or racer.active == true then
            activeRacer = racer
            break
        end
    end

    -- Se encontrou um corredor ativo, retorna ele
    if activeRacer then
        if UseDebug then 
            print('^2DEBUG: getActiveRacerName - Retornando corredor ativo:', activeRacer.racername, '^0')
        end
        return activeRacer
    end

    -- Se não há corredores ativos E não há nenhum corredor cadastrado, retorna nil
    if #allRacersForCitizen == 0 then
        if UseDebug then 
            print('^2DEBUG: getActiveRacerName - Nenhum corredor encontrado. Jogador precisa criar um nome no tablet.^0')
        end
        return nil
    end

    -- Se há corredores mas nenhum está ativo, ativa o primeiro da lista
    if #allRacersForCitizen > 0 then
        local firstRacer = allRacersForCitizen[1]
        RADB.changeRaceUser(tostring(user_id), firstRacer.racername)
        if UseDebug then 
            print('^2DEBUG: getActiveRacerName - Ativou corredor existente:', firstRacer.racername, '^0')
        end
        return firstRacer
    end

    return nil
end


-- Função para verificar se o personagem está carregado
local function isCharacterLoaded(source)
    if not vRP or not vRP.Passport then
        return false
    end
    
    local user_id = vRP.Passport(source)
    return user_id and user_id > 0
end

-- Função para aguardar o carregamento do personagem
local function waitForCharacterLoaded(source, maxWaitTime)
    local maxAttempts = math.floor(maxWaitTime / 500) -- 500ms por tentativa
    local attempts = 0
    
    while attempts < maxAttempts do
        if isCharacterLoaded(source) then
            return true
        end
        attempts = attempts + 1
        Wait(500)
    end
    
    return false
end

RegisterNetEvent('cw-racingapp:playerCharacterChosen', function(source, passport)
    local src = source
    local user_id = passport

    if UseDebug then
        print('^2[Creative] Personagem escolhido - Source:', src, 'Passport:', user_id, '^0')
        TriggerClientEvent(source, 'cw-racingapp:client:characterSelected', user_id)
    end

    -- Aguarda um pouco para garantir que tudo está carregado
    Wait(1000)

    -- Busca os dados do corredor usando o user_id (passport)
    local racerData = getActiveRacerName(nil, src)

    if racerData then
        -- Aguarda mais um pouco para garantir que o client está pronto
        Wait(500)
        TriggerClientEvent('cw-racingapp:client:updateTabletData', src, racerData)
        if UseDebug then
            print('[Creative] Dados do corredor enviados ao tablet após escolha de personagem:', json.encode(racerData))
        end
    else
        if UseDebug then
            print('[Creative] Nenhum dado de corredor encontrado para o jogador:', src, 'após escolha de personagem.')
        end
        -- Envia dados vazios para o tablet forçar a criação de nome
        TriggerClientEvent('cw-racingapp:client:updateTabletData', src, nil)
    end
end)


RegisterServerCallback('cw-racingapp:server:getRacerNamesByPlayer', function(source, serverId)
    if UseDebug then print('getRacerNamesByPlayer called with source:', source, 'serverId:', serverId) end
    local playerSource = serverId or source
    if UseDebug then print('playerSource:', playerSource) end

    -- Sistema de retry aprimorado para garantir que o personagem está carregado
    local maxAttempts = 10
    local attempts = 0
    local citizenId = nil
    
    -- Aguarda o personagem estar completamente carregado
    while attempts < maxAttempts and not citizenId do
        -- Verifica se o vRP está pronto e se o jogador tem um passport válido
        if vRP and vRP.Passport then
            local user_id = vRP.Passport(playerSource)
            if user_id and user_id > 0 then
                citizenId = Racing.Functions.GetCitizenId(playerSource)
                if citizenId then
                    break
                end
            end
        end
        
        if not citizenId then
            attempts = attempts + 1
            if UseDebug then
                print('Aguardando personagem carregar... Tentativa', attempts, 'de', maxAttempts)
            end
            Wait(500)
        end
    end

    if UseDebug then print('Racer citizenid:', citizenId) end

    if not citizenId then
        if UseDebug then
            print('^1ERRO: Não foi possível obter citizenId após', maxAttempts, 'tentativas^0')
            print('^3O personagem ainda não foi carregado completamente.^0')
        end
        return {}
    end

    local result = RADB.getRaceUsersBelongingToCitizenId(citizenId)
    
    if UseDebug then
        print('^2Racer Names found:', json.encode(result), '^0')
    end

    local activeRacer = getActiveRacerName(result, playerSource)
    
    -- Se não há corredor ativo, não faz nada - o jogador precisa criar um no tablet
    if not activeRacer then
        if UseDebug then
            print('^3Nenhum corredor ativo encontrado. Jogador precisa criar um nome no tablet.^0')
        end
    end

    return result
end)

RegisterServerCallback('cw-racingapp:server:curateTrack', function(source, trackId, curated)
    local res = RADB.setCurationForTrack(curated, trackId)
    local status = 'curated'
    if curated == 0 then status = 'NOT curated' end
    if res == 1 then
        notifyPlayer(source, 'Successfully set track ' .. trackId .. ' as ' .. status,
            'success')
        Tracks[trackId].Curated = curated
        return true
    else
        notifyPlayer(source, 'Your input seems to be lacking...', 'error')
        return false
    end
end)

local function createRacingName(source, citizenid, racerName, type, purchaseType, targetSource, creatorName)
    if UseDebug then
        print('Creating a racing user. Input:')
        print('citizenid', citizenid)
        print('racerName', racerName)
        print('type', type)
        print('purchaseType', json.encode(purchaseType, { indent = true }))
    end

    local cost = 1000
    if purchaseType and purchaseType.racingUserCosts and purchaseType.racingUserCosts[type] then
        cost = purchaseType.racingUserCosts[type]
    else
        notifyPlayer(source,
            'The user type you entered does not exist, defaulting to $1000', 'error')
    end

    if not handleRemoveMoney(source, purchaseType.moneyType, cost, creatorName) then return false end


    local creatorCitizenId = 'unknown'
    if Racing.Functions.GetCitizenId(source) then creatorCitizenId = Racing.Functions.GetCitizenId(source) end
    return addRacerName(citizenid, racerName, targetSource, type, creatorCitizenId)
end

RegisterServerCallback('cw-racingapp:server:attemptCreateUser', function(source, racerName, racerId, fobType, purchaseType)
    local citizenId = Racing.Functions.GetCitizenId(source)
    if not citizenId then
        -- Tenta obter o ID do usuário diretamente do vRP
        local user_id = nil
        if vRP.Passport then
            user_id = vRP.Passport(source)
        elseif vRP.getUserId then
            user_id = vRP.getUserId(source)
        end
        
        if user_id then
            citizenId = "vRP_" .. tostring(user_id)
        else
            -- if UseDebug then print('Racer citizenid nil in attemptCreateUser') end
            return false
        end
    end
    return createRacingName(source, citizenId, racerName, fobType, purchaseType, source, nil)
end)

local function getRacersCreatedByUser(src, citizenId, type)
    if Config.Permissions[type] and Config.Permissions[type].controlAll then
        if UseDebug then print('Fetching racers for a god') end
        return RADB.getAllRaceUsers()
    end
    if UseDebug then print('Fetching racers for a master') end
    return RADB.getRaceUsersBelongingToCitizenId(citizenId)
end

RegisterServerCallback('cw-racingapp:server:getRacersCreatedByUser', function(source, citizenid, type)
    if UseDebug then print('Fetching all racers created by ', citizenid) end
    local result = getRacersCreatedByUser(source, citizenid, type)
    if UseDebug then print('result from fetching racers created by user', citizenid, json.encode(result)) end
    return result
end)

RegisterServerCallback('cw-racingapp:server:changeRacerName', function(source, racerNameInUse)
    if UseDebug then print('Changing Racer Name for src', source, ' to name', racerNameInUse) end
    local result = changeRacerName(source, racerNameInUse)
    if UseDebug then print('Race user result:', result) end
    local ranking = getRankingForRacer(racerNameInUse)
    if UseDebug then print('Ranking:', json.encode(ranking)) end
    return result
end)

RegisterServerCallback('cw-racingapp:server:updateTrackMetadata', function(source, trackId, metadata)
    if not trackId then
        return false
    end
    if UseDebug then print('Updating track', trackId, ' metadata with:', json.encode(metadata, { indent = true })) end
    if RADB.updateTrackMetadata(trackId, metadata) then
        Tracks[trackId].Metadata = metadata
        return true
    end
    return false
end)

RegisterNetEvent('cw-racingapp:server:removeRacerName', function(racerName)
    if UseDebug then print('removing racer with name', racerName) end
    if UseDebug then print('removed by source', source, Racing.Functions.GetCitizenId(source)) end

    local res = RADB.getRaceUserByName(racerName)

    RADB.removeRaceUserByName(racerName)
    Wait(1000)
    local playerSource = Racing.Functions.GetSrcOfPlayerByCitizenId(res.citizenid)
    if playerSource ~= nil then
        if UseDebug then
            print('pinging player', playerSource)
        end
        TriggerClientEvent('cw-racingapp:client:updateRacerNames', tonumber(playerSource))
    end
end)

local function setRevokedRacerName(src, racerName, revoked)
    local res = RADB.getRaceUserByName(racerName)
    if res then
        RADB.setRaceUserRevoked(racerName, revoked)
        local readableRevoked = 'revoked'
        if revoked == 0 then readableRevoked = 'active' end
        notifyPlayer(src, 'User is now set to ' .. readableRevoked, 'success')
        if UseDebug then print('Revoking for citizenid', res.citizenid) end
        local playerSource = Racing.Functions.GetSrcOfPlayerByCitizenId(res.citizenid)
        if playerSource ~= nil then
            if UseDebug then
                print('pinging player', playerSource)
            end
            TriggerClientEvent('cw-racingapp:client:updateRacerNames', tonumber(playerSource))
        end
    else
        notifyPlayer(src, 'Race Name Not Found', 'error')
    end
end

RegisterNetEvent('cw-racingapp:server:setRevokedRacenameStatus', function(racername, revoked)
    if UseDebug then print('revoking racename', racername, revoked) end
    setRevokedRacerName(source, racername, revoked)
end)

RegisterNetEvent('cw-racingapp:server:createRacerName', function(playerId, racerName, type, purchaseType, creatorName)
    if UseDebug then
        print(
            'Creating a user',
            json.encode({ playerId = playerId, racerName = racerName, type = type, purchaseType = purchaseType })
        )
    end
    local citizenId = Racing.Functions.GetCitizenId(tonumber(playerId))
    if citizenId then
        createRacingName(source, citizenId, racerName, type, purchaseType, playerId, creatorName)
    else
        notifyPlayer(source, Lang("could_not_find_person"), "error")
    end
end)



local function srcHasUserAccess(src, access)
    local raceUser = RADB.getActiveRacerName(Racing.Functions.GetCitizenId(src))
    if not raceUser then 
        notifyPlayer(src, Lang("error_no_user"), 'error')
        return false
    end
    local auth = raceUser.auth

    local hasAuth = Config.Permissions[auth][access]

    if not hasAuth then
        notifyPlayer(src, Lang("not_auth"), 'error')
        return false
    end
    return true
end

RegisterServerCallback('cw-racingapp:server:toggleAutoHost', function(source)
    if not srcHasUserAccess(source,'handleAutoHost') then return end
    
    AutoHostIsAllowed = not AutoHostIsAllowed
    return AutoHostIsAllowed
end)

RegisterServerCallback('cw-racingapp:server:toggleHosting', function(source)
        local raceUser = RADB.getActiveRacerName(Racing.Functions.GetCitizenId(source))
    if not srcHasUserAccess(source, 'handleHosting') then return end

    HostingIsAllowed = not HostingIsAllowed
    return HostingIsAllowed
end)

RegisterServerCallback('cw-racingapp:server:getAdminData', function(source)
    return {
        autoHostIsEnabled = AutoHostIsAllowed,
        hostingIsEnabled = HostingIsAllowed
    }
end)

local function updateRacingUserAuth(data)
    if not Config.Permissions[data.auth] then return end
    local res = RADB.setRaceUserAuth(data.racername, data.auth)
    if res then
        local userSrc = Racing.Functions.GetSrcOfPlayerByCitizenId(data.citizenId)
        if userSrc then
            TriggerClientEvent('cw-racingapp:client:updateRacerNames', userSrc)
        end
        return true
    end
    return false
end

RegisterServerCallback('cw-racingapp:server:setUserAuth', function(source, data)
    if not srcHasUserAccess(source, 'controlAll') then return end

    return updateRacingUserAuth(data)
end)

RegisterServerCallback('cw-racingapp:server:fetchRacerHistory', function(source, racerName)
    return RESDB.getRacerHistory(racerName)
end)

RegisterServerCallback('cw-racingapp:server:getDashboardData', function(source, racerName, racers, daysBack)
    local trackStats = RESDB.getTrackRaceStats(daysBack or Config.Dashboard.defaultDaysBack)
    local racerStats = RESDB.getRacerHistory(racerName)
    local topRacerStats = RESDB.getTopRacerWinnersAndWinLoss(racers, daysBack or Config.Dashboard.defaultDaysBack)
    return { trackStats = trackStats, racerStats = racerStats, topRacerStats = topRacerStats }
end)

if Config.EnableCommands then
    registerCommand('changeraceuserauth', "Change authority on racing user. If used on another player they will need to relog for effect to take place.", {
        { name = 'Racer Name', help = 'Racer name. Put in quotations if multiple words' },
        { name = 'type',       help = 'racer/creator/master/god or whatever you got' },
    }, true, function(source, args)
        if not args[1] or not args[2] then
            print("^1PEBKAC error. Google it.^0")
            return
        end
        local data = {
            racername = args[1],
            auth = args[2],
            citizenId = Racing.Functions.GetCitizenId(source)
        }
        updateRacingUserAuth(data)
    end, true)

    registerCommand('createracinguser', "Create a racing user", {
        { name = 'type',       help = 'racer/creator/master/god' },
        { name = 'identifier', help = 'Server ID' },
        { name = 'Racer Name', help = 'Racer name. Put in quotations if multiple words' }
        }, true, function(source, args)
        local type = args[1]
        local id = tonumber(args[2])
        print(
            '^4Creating a user with input^0',
            json.encode({ playerId = args[2], racerName = args[3], type = args[1] })
        )
        if args[4] then
            print('^1Too many args!')
            notifyPlayer(source,
                "Too many arguments. You probably did not read the command input suggestions.", "error")
            return
        end

        if not Config.Permissions[type:lower()] then
            notifyPlayer(source, "This user type does not exist", "error")
            return
        end

        local citizenid
        local name = args[3]

        if tonumber(id) then
            citizenid = Racing.Functions.GetCitizenId(tonumber(id))
            if UseDebug then print('CitizenId', citizenid) end
            if not citizenid then
                notifyPlayer(source, Lang("id_not_found"), "error")
                return
            end
        else
            citizenid = id
        end

        if #name >= Config.MaxRacerNameLength then
            notifyPlayer(source, Lang("name_too_long"), "error")
            return
        end

        if #name <= Config.MinRacerNameLength then
            notifyPlayer(source, Lang("name_too_short"), "error")
            return
        end

        local tradeType = {
            moneyType = Config.Payments.createRacingUser,
            racingUserCosts = {
                racer = 0,
                creator = 0,
                master = 0,
                god = 0
            },
        }

        createRacingName(source, citizenid, name, type:lower(), tradeType, id)
    end, true)

    registerCommand('remracename', 'Remove Racing Name From Database',
        { { name = 'name', help = 'Racer name. Put in quotations if multiple words' } }, true, function(source, args)
            local name = args[1]
            print('name of racer to delete:', name)
            RADB.removeRaceUserByName(name)
        end, true)

    registerCommand('removeallracetracks', 'Remove the race_tracks table', {}, true, function(source, args)
        RADB.wipeTracksTable()
    end, true)

    registerCommand('racingappcurated', 'Mark/Unmark track as curated',
            { { name = 'trackid', help = 'Track ID (not name). Use quotation marks!!!' }, { name = 'curated', help = 'true/false' } },
        true,
        function(source, args)
            print('Curating track: ', args[1], args[2])
            local curated = 0
            if args[2] == 'true' then
                curated = 1
            end
            local res = exports['mysql-async']:execute('UPDATE race_tracks SET curated = ? WHERE raceid = ?', { curated, args[1] })
            if res == 1 then
                Tracks[args[1]].Curated = curated
                notifyPlayer(source, 'Successfully set track curated as ' .. args[2])
            else
                notifyPlayer(source, 'Your input seems to be lacking...')
            end
        end, true)

    registerCommand('cwdebugracing', 'toggle debug for racing', {}, true, function(source, args)
        UseDebug = not UseDebug
        print('debug is now:', UseDebug)
        TriggerClientEvent('cw-racingapp:client:toggleDebug', source, UseDebug)
    end, true)

    registerCommand('cwlisttracks', 'toggle debug for racing', {}, true, function(source, args)
        local tracksWithoutCheckpoints = {}
        for i, track in pairs(Tracks) do
            tracksWithoutCheckpoints[i] = track
            tracksWithoutCheckpoints[i].Checkpoints = nil
        end
        print(json.encode(tracksWithoutCheckpoints, {indent=true}))        
    end, true)

    registerCommand('cwracingapplist', 'list racingapp stuff', {}, true, function(source, args)
        print("=========================== ^3TRACKS^0 ===========================")
        print(json.encode(Tracks, { indent = true }))
        print("=========================== ^3AVAILABLE RACES^0 ===========================")
        print(json.encode(AvailableRaces, { indent = true }))
        print("=========================== ^3NOT FINISHED^0 ===========================")
        print(json.encode(NotFinished, { indent = true }))
        print("=========================== ^TIMERS^0 ===========================")
        print(json.encode(Timers, { indent = true }))
        print("=========================== ^RESULTS^0 ===========================")
        print(json.encode(RaceResults, { indent = true }))
    end, true)
end

-- Adicione esta função para debug detalhado
local function debugAvailableRaces()
    if UseDebug then
        -- print('=== DEBUG AvailableRaces ===')
        print('Count:', #AvailableRaces)
        for k, v in pairs(AvailableRaces) do
            print('['..k..'] RaceId:', v.RaceId, 'TrackId:', v.TrackId, 'SetupCitizenId:', v.SetupCitizenId)
        end
        -- print('=== END DEBUG ===')
    end
end




CreateThread(function()
    while not vRP do
        Wait(100)
    end
    updateRaces()
end)

