-- universal_bridge.lua
if Config.Debug then print('Loading Universal Standalone Bridge') end

local framework = nil
local playerLoaded = false

-- Detecção automática do framework
Citizen.CreateThread(function()
    while true do
        -- Tenta detectar vRP
        if not framework and GetResourceState('vrp') == 'started' then
            framework = 'vRP'
            if Config.Debug then print('Framework detected: vRP') end
            break
        end
        
        -- Tenta detectar vRPex (Creative)
        if not framework and GetResourceState('vrpex') == 'started' then
            framework = 'vrpex'
            if Config.Debug then print('Framework detected: vRPex') end
            break
        end
        
        -- Tenta detectar Other Framework
        if not framework and GetResourceState('other_core') == 'started' then
            framework = 'other'
            if Config.Debug then print('Framework detected: Other') end
            break
        end
        
        -- Se não detectou nenhum específico, usa modo genérico
        if not framework then
            framework = 'generic'
            if Config.Debug then print('Using Generic Standalone mode') end
            break
        end
        
        Wait(1000)
    end
end)

-- Evento quando o player carrega (compatível com vários frameworks)
RegisterNetEvent("playerLoaded", function()
    playerLoaded = true
    if initialSetup then initialSetup() end
end)

RegisterNetEvent("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Citizen.Wait(5000)
        playerLoaded = true
        if initialSetup then initialSetup() end
    end
end)

-- Função universal para pegar emprego
function getPlayerJobName()
    if not playerLoaded then return "unemployed" end
    
    if framework == 'vRP' then
        local user_id = nil
        TriggerServerEvent("vRP:getUserId", function(_user_id) user_id = _user_id end)
        if user_id then
            TriggerServerEvent("vRP:getUserIdentity", user_id, function(identity)
                if identity and identity.job then
                    return identity.job
                end
            end)
        end
        
    elseif framework == 'vrpex' then
        -- vRP Creative
        local user_id = exports['vrpex']:getUserId()
        if user_id then
            local identity = exports['vrpex']:getUserIdentity(user_id)
            if identity and identity.job then
                return identity.job
            end
        end
        
    else
        -- Modo genérico - usa eventos padrão
        local job = "unemployed"
        TriggerServerEvent("universal:getPlayerJob", function(_job)
            job = _job or "unemployed"
        end)
        Citizen.Wait(100)
        return job
    end
    
    return "unemployed"
end

-- Função universal para pegar nível do emprego
function getPlayerJobLevel()
    if not playerLoaded then return 0 end
    
    local jobLevel = 0
    TriggerServerEvent("universal:getPlayerJobLevel", function(level)
        jobLevel = level or 0
    end)
    Citizen.Wait(100)
    
    return jobLevel
end

-- Função universal para verificar GPS
function hasGps()
    if not playerLoaded then return false end
    
    if Config.Inventory == 'ox' then
        if exports.ox_inventory:Search('count', Config.ItemName.gps) >= 1 then
            return true
        end
    else
        -- Sistema genérico de inventário
        local hasItem = false
        TriggerServerEvent("universal:hasItem", Config.ItemName.gps, function(result)
            hasItem = result or false
        end)
        Citizen.Wait(100)
        return hasItem
    end
    
    return false
end

-- Função universal para pegar ID do player
function getCitizenId()
    if not playerLoaded then return nil end
    
    local citizenId = nil
    TriggerServerEvent("universal:getCitizenId", function(_citizenId)
        citizenId = _citizenId
    end)
    Citizen.Wait(100)
    
    return citizenId
end

-- Função universal para modelo do veículo (client-side apenas)
function getVehicleModel(vehicle)
    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model)
    local brand = "Unknown"
    
    -- Tabela universal de marcas
    local vehicleBrands = {
        ["adder"] = "Truffade",
        ["zentorno"] = "Pegassi",
        ["entityxf"] = "Överflöd",
        ["sultan"] = "Karin",
        ["banshee"] = "Bravado",
        ["elegy"] = "Annis",
        ["sentinel"] = "Ubermacht",
        ["blista"] = "Dinka"
    }
    
    local modelString = string.lower(modelName)
    if vehicleBrands[modelString] then
        brand = vehicleBrands[modelString]
    end
    
    return modelName, brand
end

-- Função universal para player mais próximo (client-side)
function getClosestPlayer()
    local playerPed = PlayerPedId()
    local players = GetActivePlayers()
    local closestDistance = -1
    local closestPlayer = -1
    
    for _, player in ipairs(players) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= playerPed then
            local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = GetPlayerServerId(player)
                closestDistance = distance
            end
        end
    end
    
    if closestDistance ~= -1 and closestDistance <= 3.0 then
        return closestPlayer, closestDistance
    end
    
    return -1, -1
end

-- Sistema universal de notificações
function notify(text, type)
    if not playerLoaded then return end
    
    -- Remove this block if you dont want in-app notifications
    if UiIsOpen then
        SendNUIMessage({
            type = "notify",
            data = {
                title = text,
                type = type,
            },
        })
        return
    end

    if Config.OxLibNotify then
        lib.notify({
            title = Config.NotifyTitle or 'RacingApp',
            description = text,
            type = type,
        })
    else
        -- Notificação genérica que funciona em qualquer base
        local color = "~b~" -- Azul padrão
        if type == "error" then
            color = "~r~" -- Vermelho
        elseif type == "success" then
            color = "~g~" -- Verde
        elseif type == "warning" then
            color = "~y~" -- Amarelo
        end
        
        -- Método 1: SetNotificationTextEntry (funciona em todas as bases)
        SetNotificationTextEntry("STRING")
        AddTextComponentString(color .. text)
        DrawNotification(false, false)
        
        -- Método 2: Trigger de evento genérico
        TriggerEvent("universal:notify", color .. text, type)
        
        -- Método 3: Envia para o server mostrar notificação
        TriggerServerEvent("universal:showNotification", text, type)
    end
end

-- Funções auxiliares universais
function getPlayerName()
    if not playerLoaded then return "Unknown" end
    
    local playerName = "Unknown"
    TriggerServerEvent("universal:getPlayerName", function(name)
        playerName = name or "Unknown"
    end)
    Citizen.Wait(100)
    
    return playerName
end

function getPlayerCash()
    if not playerLoaded then return 0 end
    
    local cash = 0
    TriggerServerEvent("universal:getPlayerCash", function(amount)
        cash = amount or 0
    end)
    Citizen.Wait(100)
    
    return cash
end

-- Verificador de permissões universal
function hasPermission(permission)
    if not playerLoaded then return false end
    
    local hasPerm = false
    TriggerServerEvent("universal:hasPermission", permission, function(result)
        hasPerm = result or false
    end)
    Citizen.Wait(100)
    
    return hasPerm
end

-- Debug helper universal
if Config.Debug then
    RegisterCommand('test_universal_bridge', function()
        print("=== UNIVERSAL BRIDGE DEBUG ===")
        print("Framework: " .. tostring(framework))
        print("Player Loaded: " .. tostring(playerLoaded))
        print("Job Name: " .. tostring(getPlayerJobName()))
        print("Job Level: " .. tostring(getPlayerJobLevel()))
        print("Has GPS: " .. tostring(hasGps()))
        print("Citizen ID: " .. tostring(getCitizenId()))
        print("Player Name: " .. tostring(getPlayerName()))
        print("Player Cash: " .. tostring(getPlayerCash()))
        print("===============================")
    end)
end

-- Export para outros scripts
exports('getFramework', function()
    return framework
end)

exports('isPlayerLoaded', function()
    return playerLoaded
end)