-- Creative vRP Bridge (Server-side)
print('[RACING] Carregando Creative vRP Bridge (Server)')

-- Verifica se o vRP está disponível
local function checkVRP()
    if _G.vRP then
        return true
    end
    return false
end

-- Exporta funções para uso no sistema de corridas
local CreativeBridge = {}

CreativeBridge.getUserId = function(source)
    if checkVRP() and vRP.getUserId then
        return vRP.getUserId(source)
    end
    return nil
end

CreativeBridge.getInventoryItemAmount = function(user_id, item)
    if checkVRP() and vRP.getInventoryItemAmount then
        return vRP.getInventoryItemAmount(user_id, item)
    end
    return 0
end

CreativeBridge.tryPayment = function(user_id, amount)
    if checkVRP() and vRP.tryPayment then
        return vRP.tryPayment(user_id, amount)
    end
    return false
end

CreativeBridge.giveMoney = function(user_id, amount)
    if checkVRP() and vRP.giveMoney then
        return vRP.giveMoney(user_id, amount)
    elseif checkVRP() and vRP.giveBankMoney then
        return vRP.giveBankMoney(user_id, amount)
    end
    return false
end

CreativeBridge.getUserSource = function(user_id)
    if checkVRP() and vRP.getUserSource then
        return vRP.getUserSource(user_id)
    end
    return nil
end

CreativeBridge.hasPermission = function(user_id, permission)
    if checkVRP() and vRP.hasPermission then
        return vRP.hasPermission(user_id, permission)
    end
    return false
end

-- Exporta o bridge
return CreativeBridge