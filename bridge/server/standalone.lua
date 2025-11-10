
if Config.Debug then print('Loading Universal Bridge Server') end

-- Eventos genéricos que funcionam em qualquer framework
RegisterNetEvent("universal:getPlayerJob", function(cb)
    local src = source
    
    -- Tenta vRP primeiro
    if GetResourceState('vrp') == 'started' then
        local user_id = vRP.getUserId(src)
        if user_id then
            local identity = vRP.getUserIdentity(user_id)
            if identity and identity.job then
                cb(identity.job)
                return
            end
        end
    end
    
    -- Tenta vRPex (Creative)
    if GetResourceState('vrpex') == 'started' then
        local user_id = exports['vrpex']:getUserId(src)
        if user_id then
            local identity = exports['vrpex']:getUserIdentity(user_id)
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
    local src = source
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
    if GetResourceState('vrp') == 'started' then
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
    
    -- vRP
    if GetResourceState('vrp') == 'started' then
        local user_id = vRP.getUserId(src)
        cb(tostring(user_id))
        return
    end
    
    -- vRPex
    if GetResourceState('vrpex') == 'started' then
        local user_id = exports['vrpex']:getUserId(src)
        cb(tostring(user_id))
        return
    end
    
    -- Fallback - usa ID da sessão
    cb(tostring(src))
end)

RegisterNetEvent("universal:getPlayerName", function(cb)
    local src = source
    local playerName = GetPlayerName(src)
    cb(playerName)
end)

RegisterNetEvent("universal:getPlayerCash", function(cb)
    local src = source
    
    -- vRP
    if GetResourceState('vrp') == 'started' then
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
    if GetResourceState('vrp') == 'started' then
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