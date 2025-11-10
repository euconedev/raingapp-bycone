-- Inicialização do bridge vRP
global_vRP = nil
global_vRPclient = nil
Racing = Racing or {}
Racing.Functions = Racing.Functions or {}

-- Carrega os módulos vRP necessários
local Tunnel = module("vrp","lib/Tunnel")
local Proxy = module("vrp","lib/Proxy")

-- Obtém a interface do vRP e a define como global
vRP = Proxy.getInterface("vRP")
global_vRP = vRP
global_vRPclient = Tunnel.getInterface("vRP")

-- Define GetCitizenId para usar o vRP diretamente
Racing.Functions.GetCitizenId = function(source)
    while not vRP do Wait(0) end -- Wait for vRP to be initialized
    if not source then return nil end
    
    -- No Creative, usa vRP.Passport() ou vRP.getUserId()
    local user_id = nil
    
    if vRP.Passport then
        user_id = vRP.Passport(source)
    elseif vRP.getUserId then
        user_id = vRP.getUserId(source)
    end
    
    return user_id
end

-- Função para obter source a partir do user_id
Racing.Functions.GetSrcOfPlayerByCitizenId = function(user_id)
    if not user_id then return nil end
    return vRP.Source(user_id)
end

-- Função para obter nome do jogador
Racing.Functions.GetPlayerName = function(source)
    local user_id = vRP.Passport(source)
    if not user_id then return GetPlayerName(source) end
    
    local identity = vRP.Identity(user_id)
    if identity then
        if identity.firstname and identity.name then
            return identity.firstname .. " " .. identity.name
        elseif identity.name then
            return identity.name
        end
    end
    
    return GetPlayerName(source)
end


-- Adaptação das funções de dinheiro
Racing.Functions.AddMoney = function(source, amount)
    local user_id = vRP.Passport(source)
    if user_id then
        vRP.GiveMoney(user_id, amount)
        return true
    end
    return false
end

Racing.Functions.RemoveMoney = function(source, amount)
    local user_id = vRP.Passport(source)
    if user_id then
        if vRP.GetBank(user_id) >= amount then
            vRP.TakeBank(user_id, amount)
            return true
        end
    end
    return false
end

Racing.Functions.CanPay = function(source, amount)
    local user_id = vRP.Passport(source)
    if user_id then
        return vRP.GetBank(user_id) >= amount
    end
    return false
end

exports('getRacingFunctions', function()
    return Racing.Functions
end)