-- creative.lua
if Config.Debug then print('Using vRP Creative bridge') end

local vRP = nil

-- Inicialização do vRP
Citizen.CreateThread(function()
    while not vRP do
        TriggerEvent("vRP:getSharedObject", function(obj) 
            vRP = obj 
        end)
        Wait(100)
    end
    print('vRP Creative bridge loaded successfully')
end)

-- Evento quando o player carrega (equivalente ao OnPlayerLoaded)
RegisterNetEvent("vRP:client:OnPlayerLoaded", function()
    initialSetup()
end)

-- Função para pegar o emprego do player
function getPlayerJobName()
    local user_id = vRP.getUserId(source)
    if user_id then
        local identity = vRP.getUserIdentity(user_id)
        if identity and identity.job then
            return identity.job
        end
    end
    return "unemployed"
end

-- Função para pegar o nível/grade do emprego
function getPlayerJobLevel()
    local user_id = vRP.getUserId(source)
    if user_id then
        -- No vRP creative, você pode adaptar para seu sistema de grades
        -- Exemplo básico - ajuste conforme sua implementação
        local job = getPlayerJobName()
        if job == "police" then
            return 1 -- Grade level padrão
        elseif job == "mechanic" then
            return 1
        end
        -- Adicione mais jobs conforme necessário
    end
    return 0
end

-- Função para verificar se tem GPS
function hasGps()
    local user_id = vRP.getUserId(source)
    if user_id then
        if Config.Inventory == 'creative' then
            -- Sistema de inventário do vRP creative
            local item_count = vRP.getInventoryItemAmount(user_id, Config.ItemName.gps)
            if item_count and item_count >= 1 then
                return true
            end
        elseif Config.Inventory == 'ox' then
            -- Se estiver usando ox_inventory com vRP
            if exports.ox_inventory:Search('count', Config.ItemName.gps) >= 1 then
                return true
            end
        else
            -- Sistema padrão do vRP
            local item_count = vRP.getInventoryItemAmount(user_id, Config.ItemName.gps)
            return item_count and item_count > 0
        end
    end
    return false
end

-- Função para pegar o ID único do cidadão (equivalente ao citizenid)
local RacingFunctions = nil

Citizen.CreateThread(function()
    while RacingFunctions == nil do
        RacingFunctions = exports['cw-racingapp']:getRacingFunctions()
        Citizen.Wait(100)
    end
end)

function getCitizenId(source)
    if RacingFunctions and RacingFunctions.GetCitizenId then
        local user_id = RacingFunctions.GetCitizenId(source)
        if user_id then
            -- No vRP, o user_id é o identificador único
            return tostring(user_id)
        end
    end
    return nil
end

-- Função para pegar modelo e marca do veículo
function getVehicleModel(vehicle)
    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model)
    local brand = "Unknown"
    
    -- Você pode criar uma tabela customizada para marcas ou usar a do vRP se existir
    -- Exemplo básico - adapte conforme suas necessidades
    local vehicleBrands = {
        ["adder"] = "Truffade",
        ["zentorno"] = "Pegassi", 
        ["entityxf"] = "Överflöd",
        -- Adicione mais veículos conforme necessário
    }
    
    local modelString = string.lower(modelName)
    if vehicleBrands[modelString] then
        brand = vehicleBrands[modelString]
    end
    
    return modelName, brand
end

-- Função para pegar player mais próximo
function getClosestPlayer()
    local playerPed = PlayerPedId()
    local players = vRP.getUsers()
    local closestDistance = -1
    local closestPlayer = -1
    
    for _, player in ipairs(players) do
        local targetPed = GetPlayerPed(GetPlayerFromServerId(player))
        if targetPed ~= playerPed then
            local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = player
                closestDistance = distance
            end
        end
    end
    
    if closestDistance ~= -1 and closestDistance <= 3.0 then
        return closestPlayer, closestDistance
    end
    
    return -1, -1
end

-- Sistema de notificações
function notify(text, type)
    local user_id = vRP.getUserId(source)
    if not user_id then return end
    
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
        -- Notificação padrão do vRP creative
        local color = "~b~" -- Azul padrão
        if type == "error" then
            color = "~r~" -- Vermelho para erro
        elseif type == "success" then
            color = "~g~" -- Verde para sucesso
        elseif type == "warning" then
            color = "~y~" -- Amarelo para aviso
        end
        
        vRPclient.notify(source, {color .. text})
        
        -- Alternativa: Trigger de evento para notificação customizada
        -- TriggerEvent("creative:notify", color .. text)
    end
end

-- Funções adicionais que podem ser úteis
function getPlayerName()
    local user_id = vRP.getUserId(source)
    if user_id then
        local identity = vRP.getUserIdentity(user_id)
        if identity then
            return identity.firstname .. " " .. identity.name
        end
    end
    return "Unknown"
end

function getPlayerCash()
    local user_id = vRP.getUserId(source)
    if user_id then
        return vRP.getMoney(user_id)
    end
    return 0
end

-- Export para outras scripts usarem o bridge
exports('getVRPObject', function()
    return vRP
end)

-- Debug helper
if Config.Debug then
    RegisterCommand('test_bridge', function()
        print("Job Name: " .. tostring(getPlayerJobName()))
        print("Job Level: " .. tostring(getPlayerJobLevel()))
        print("Has GPS: " .. tostring(hasGps()))
        print("Citizen ID: " .. tostring(getCitizenId()))
        print("Player Name: " .. tostring(getPlayerName()))
        print("Player Cash: " .. tostring(getPlayerCash()))
    end)
end