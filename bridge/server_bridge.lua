-- /bridge/server_bridge.lua 

-- Criamos uma tabela global para acessar nossas funções facilmente 
Racing = {} 
Racing.Functions = {} 

-- Debug para verificar o framework e vRP
print('DEBUG: Config.Framework =', Config.Framework)
print('DEBUG: vRP global exists?', type(vRP) ~= 'nil')
if type(vRP) ~= 'nil' then
    print('DEBUG: vRP.getUserId exists?', type(vRP.getUserId) ~= 'nil')
    print('DEBUG: vRP.Passport exists?', type(vRP.Passport) ~= 'nil')
end

-- Variável para ativar logs de debug
local UseDebug = Config.Debug or false

-- Checa a configuração no config.lua 
if Config.Framework == 'esx' then 
    -- Se estiver usando ESX, preenchemos a tabela com as funções do ESX 
    local ESX = exports['es_extended']:getSharedObject() 
    
    Racing.Functions.GetPlayerFromId = function(source) 
        return ESX.GetPlayerFromId(source) 
    end 
    
    Racing.Functions.AddMoney = function(source, amount) 
        local xPlayer = ESX.GetPlayerFromId(source) 
        if xPlayer then 
            xPlayer.addMoney(amount) 
        end 
    end 

    Racing.Functions.RemoveMoney = function(source, amount) 
        local xPlayer = ESX.GetPlayerFromId(source) 
        if xPlayer then 
            xPlayer.removeMoney(amount) 
        end 
    end 

    Racing.Functions.Notify = function(source, message, type) 
        local xPlayer = ESX.GetPlayerFromId(source) 
        if xPlayer then 
            xPlayer.showNotification(message, type) 
        end 
    end 
    
    Racing.Functions.GetCitizenId = function(source)
        local xPlayer = ESX.GetPlayerFromId(source)
        if xPlayer then
            return xPlayer.identifier
        end
        return nil
    end

elseif Config.Framework == 'qbcore' then 
    -- Se estiver usando QBCore, preenchemos com as funções do QB 
    local QBCore = exports['qb-core']:GetCoreObject() 

    Racing.Functions.GetPlayerFromId = function(source) 
        return QBCore.Functions.GetPlayer(source) 
    end 

    Racing.Functions.AddMoney = function(source, amount) 
        local Player = QBCore.Functions.GetPlayer(source) 
        if Player then 
            Player.Functions.AddMoney('cash', amount) 
        end 
    end 

    Racing.Functions.RemoveMoney = function(source, amount) 
        local Player = QBCore.Functions.GetPlayer(source) 
        if Player then 
            Player.Functions.RemoveMoney('cash', amount) 
        end 
    end 

    Racing.Functions.Notify = function(source, message, type) 
        TriggerClientEvent('QBCore:Notify', source, message, type) 
    end 
    
    Racing.Functions.GetCitizenId = function(source)
        local Player = QBCore.Functions.GetPlayer(source)
        if Player then
            return Player.PlayerData.citizenid
        end
        return nil
    end

elseif Config.Framework == 'vrp' or Config.Framework == 'vrpex' then
    -- Implementação específica para vRP/vRPex
    print('DEBUG: Usando bridge vRP/vRPex')
    
    Racing.Functions.GetPlayerFromId = function(source) 
        local user_id = vRP.getUserId(source)
        if user_id then
            return { 
                source = source,
                user_id = user_id,
                name = GetPlayerName(source) 
            }
        end
        return nil
    end 

    Racing.Functions.AddMoney = function(source, amount) 
        if UseDebug then print('DEBUG: AddMoney called for source', source, 'amount', amount) end
        local user_id = vRP.getUserId(source)
        if user_id then
            -- Usar giveMoney ou giveBankMoney dependendo da sua configuração
            if vRP.giveMoney then
                vRP.giveMoney(user_id, amount)
            elseif vRP.giveBankMoney then
                vRP.giveBankMoney(user_id, amount)
            end
            if UseDebug then print('DEBUG: AddMoney successful for user_id', user_id, 'amount', amount) end
            return true
        else
            print('ERROR: AddMoney - No user_id found for source', source)
            return false
        end
    end 

Racing.Functions.RemoveMoney = function(source, amount)
    local user_id = vRP.getUserId(source)
    if not user_id then
        print("[ERROR] RemoveMoney - No user_id found for source " .. source)
        return false
    end
    if vRP.tryPayment(user_id, amount) then
        return true
    else
        TriggerClientEvent('cw-racingapp:client:notify', source, Lang("can_not_afford") .. " $" .. amount, "error")
        return false
    end
end 

    Racing.Functions.CanPay = function(source, amount)
        if UseDebug then print('DEBUG: CanPay called for source', source, 'amount', amount) end
        local user_id = vRP.getUserId(source)
        if user_id then
            local money = 0
            if vRP.getMoney then
                money = vRP.getMoney(user_id)
            elseif vRP.getBankMoney then
                money = vRP.getBankMoney(user_id)
            end
            local canPay = money >= amount
            if UseDebug then print('DEBUG: CanPay result - money:', money, 'canPay:', canPay) end
            return canPay
        end
        return false
    end

    Racing.Functions.Notify = function(source, message, type) 
        if vRP.notify then
            vRP.notify(source, message, type)
        else
            TriggerClientEvent('Racing:Client:Notify', source, message, type) 
        end
    end 
    
    Racing.Functions.GetCitizenId = function(source)
        if not source then
            if UseDebug then print('DEBUG: GetCitizenId - source is nil') end
            return nil
        end
        
        local user_id = nil
        
        -- Tenta todas as funções possíveis do vRP para obter o ID do usuário
        if vRP.Passport then
            user_id = vRP.Passport(source)
            if UseDebug then print('DEBUG: GetCitizenId - vRP.Passport returned user_id:', user_id) end
        elseif vRP.getUserId then
            user_id = vRP.getUserId(source)
            if UseDebug then print('DEBUG: GetCitizenId - vRP.getUserId returned user_id:', user_id) end
        end
        
        if user_id then
            if UseDebug then print('DEBUG: GetCitizenId - Returning citizenId:', "vRP_" .. tostring(user_id)) end
            return "vRP_" .. tostring(user_id)
        end
        
        if UseDebug then print('DEBUG: GetCitizenId - No user_id found for source:', source) end
        return nil
    end

    Racing.Functions.GetSrcOfPlayerByCitizenId = function(citizenId)
        if UseDebug then print('DEBUG: GetSrcOfPlayerByCitizenId called for citizenId', citizenId) end
        
        -- Se o citizenId começar com "vRP_", extrair o user_id
        if citizenId and citizenId:match("^vRP_") then
            local user_id = tonumber(citizenId:gsub("vRP_", ""))
            if user_id and vRP.getUserSource then
                local source = vRP.getUserSource(user_id)
                if UseDebug then print('DEBUG: GetSrcOfPlayerByCitizenId - found source', source, 'for vRP user_id', user_id) end
                return source
            end
        end
        
        -- Fallback: procurar por todos os jogadores
        for i = 0, 255 do
            if GetPlayerName(i) then
                local checkCitizenId = Racing.Functions.GetCitizenId(i)
                if checkCitizenId == citizenId then
                    if UseDebug then print('DEBUG: GetSrcOfPlayerByCitizenId - found source', i, 'via fallback') end
                    return i
                end
            end
        end
        
        if UseDebug then print('DEBUG: GetSrcOfPlayerByCitizenId - no source found for citizenId', citizenId) end
        return nil
    end

elseif Config.Framework == 'standalone' then 
    -- Carrega o bridge universal standalone
    print('DEBUG: Usando bridge universal standalone')
    
    Racing.Functions.GetPlayerFromId = function(source) 
        return { 
            source = source, 
            name = GetPlayerName(source) 
        } 
    end 

    -- Função para adicionar dinheiro
    Racing.Functions.AddMoney = function(source, amount) 
        if UseDebug then print('DEBUG: AddMoney called for source', source, 'amount', amount) end
        
        -- Tenta usar vRP se disponível
        if vRP and vRP.getUserId then
            local user_id = vRP.getUserId(source)
            if user_id then
                if vRP.giveMoney then
                    vRP.giveMoney(user_id, amount)
                elseif vRP.giveBankMoney then
                    vRP.giveBankMoney(user_id, amount)
                end
                if UseDebug then print('DEBUG: AddMoney successful for user_id', user_id, 'amount', amount) end
                return true
            end
        end
        
        -- Evento universal para outros frameworks
        local success = false
        TriggerEvent("universal:addMoney", source, amount, function(result)
            success = result
        end)
        
        if not success then
            print('ERROR: AddMoney - Failed to add money for source', source)
        end
        
        return success
    end 

    -- Função para remover dinheiro (importante!)
    Racing.Functions.RemoveMoney = function(source, amount) 
        if UseDebug then print('DEBUG: RemoveMoney called for source', source, 'amount', amount) end
        
        -- Tenta usar vRP se disponível
        if vRP and vRP.getUserId and vRP.tryPayment then
            local user_id = vRP.getUserId(source)
            if user_id then
                if vRP.tryPayment(user_id, amount) then
                    if UseDebug then print('DEBUG: RemoveMoney successful for user_id', user_id, 'amount', amount) end
                    return true
                else
                    print('ERROR: RemoveMoney - Payment failed for user_id', user_id, 'amount', amount)
                    return false
                end
            end
        end
        
        -- Evento universal para outros frameworks
        local success = false
        TriggerEvent("universal:removeMoney", source, amount, function(result)
            success = result
        end)
        
        return success
    end 

    -- Função para verificar se pode pagar
    Racing.Functions.CanPay = function(source, amount)
        if UseDebug then print('DEBUG: CanPay called for source', source, 'amount', amount) end
        
        -- Tenta usar vRP se disponível
        if vRP and vRP.getUserId then
            local user_id = vRP.getUserId(source)
            if user_id then
                local money = 0
                if vRP.getMoney then
                    money = vRP.getMoney(user_id)
                elseif vRP.getBankMoney then
                    money = vRP.getBankMoney(user_id)
                end
                local canPay = money >= amount
                if UseDebug then print('DEBUG: CanPay result - money:', money, 'canPay:', canPay) end
                return canPay
            end
        end
        
        -- Evento universal para outros frameworks
        local canPay = false
        TriggerEvent("universal:canPay", source, amount, function(result)
            canPay = result
        end)
        
        return canPay
    end

    Racing.Functions.Notify = function(source, message, type) 
        TriggerClientEvent('Racing:Client:Notify', source, message, type) 
    end 
    
    Racing.Functions.GetCitizenId = function(source)
        -- Tenta usar vRP se disponível
        if vRP and vRP.getUserId then
            local user_id = vRP.getUserId(source)
            if user_id then
                return "vRP_" .. tostring(user_id)
            end
        end
        
        -- Evento universal para outros frameworks
        local citizenId = nil
        TriggerEvent("universal:getCitizenId", source, function(id)
            citizenId = id
        end)
        
        -- Fallback para ID da sessão
        if not citizenId then
            citizenId = "player_" .. tostring(source)
        end
        
        return citizenId
    end

    Racing.Functions.GetSrcOfPlayerByCitizenId = function(citizenId)
        if UseDebug then print('DEBUG: GetSrcOfPlayerByCitizenId called for citizenId', citizenId) end
        
        -- Se o citizenId começar com "vRP_", extrair o user_id
        if citizenId and citizenId:match("^vRP_") then
            local user_id = tonumber(citizenId:gsub("vRP_", ""))
            if user_id and vRP and vRP.getUserSource then
                local source = vRP.getUserSource(user_id)
                if UseDebug then print('DEBUG: GetSrcOfPlayerByCitizenId - found source', source, 'for vRP user_id', user_id) end
                return source
            end
        end
        
        -- Evento universal para outros frameworks
        local playerSource = nil
        TriggerEvent("universal:getSrcOfPlayerByCitizenId", citizenId, function(src)
            playerSource = src
        end)
        
        if playerSource then
            return playerSource
        end
        
        -- Fallback: procurar por todos os jogadores
        for i = 0, 255 do
            if GetPlayerName(i) then
                local checkCitizenId = Racing.Functions.GetCitizenId(i)
                if checkCitizenId == citizenId then
                    if UseDebug then print('DEBUG: GetSrcOfPlayerByCitizenId - found source', i, 'via fallback') end
                    return i
                end
            end
        end
        
        if UseDebug then print('DEBUG: GetSrcOfPlayerByCitizenId - no source found for citizenId', citizenId) end
        return nil
    end
end

-- Registra eventos universais para compatibilidade com standalone.lua
RegisterNetEvent("universal:getPlayerJob", function(cb)
    local src = source
    
    -- Tenta vRP primeiro
    if vRP and vRP.getUserId then
        local user_id = vRP.getUserId(src)
        if user_id then
            local identity = vRP.getUserIdentity and vRP.getUserIdentity(user_id)
            if identity and identity.job then
                cb(identity.job)
                return
            end
        end
    end
    
    -- Fallback genérico
    cb("unemployed")
end)

RegisterNetEvent("universal:getPlayerJobLevel", function(cb)
    -- Implementação básica - adapte conforme sua base
    cb(1) -- Retorna level 1 como padrão
end)

RegisterNetEvent("universal:hasItem", function(itemName, cb)
    local src = source
    
    -- Se usa ox_inventory
    if GetResourceState('ox_inventory') == 'started' then
        local count = exports.ox_inventory:Search(src, 'count', itemName)
        cb(count >= 1)
        return
    end
    
    -- Se usa vRP inventory
    if vRP and vRP.getInventoryItemAmount then
        local user_id = vRP.getUserId(src)
        if user_id then
            local amount = vRP.getInventoryItemAmount(user_id, itemName)
            cb(amount >= 1)
            return
        end
    end
    
    -- Fallback
    cb(false)
end)

RegisterNetEvent("universal:getCitizenId", function(cb)
    local src = source
    cb(Racing.Functions.GetCitizenId(src))
end)

RegisterNetEvent("universal:getPlayerName", function(cb)
    local src = source
    local playerName = GetPlayerName(src)
    cb(playerName)
end)

RegisterNetEvent("universal:getPlayerCash", function(cb)
    local src = source
    
    -- vRP
    if vRP and vRP.getUserId and vRP.getMoney then
        local user_id = vRP.getUserId(src)
        if user_id then
            cb(vRP.getMoney(user_id))
            return
        end
    end
    
    -- Fallback
    cb(0)
end)

RegisterNetEvent("universal:hasPermission", function(permission, cb)
    local src = source
    
    -- vRP
    if vRP and vRP.getUserId and vRP.hasPermission then
        local user_id = vRP.getUserId(src)
        if user_id then
            cb(vRP.hasPermission(user_id, permission))
            return
        end
    end
    
    -- Fallback
    cb(false)
end)

RegisterNetEvent("universal:showNotification", function(text, type)
    local src = source
    -- Envia notificação de volta para o client de forma universal
    TriggerClientEvent("universal:clientNotification", src, text, type)
end)

print('DEBUG: Racing bridge carregado com sucesso para framework: ' .. Config.Framework)