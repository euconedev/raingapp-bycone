-- /bridge/client_bridge.lua 

-- Criamos a tabela global no cliente também 
Racing = Racing or {} 
Racing.Functions = Racing.Functions or {} 

if Config.Framework == 'esx' then 
    local ESX = exports['es_extended']:getSharedObject() 
    
    Racing.Functions.Notify = function(message, type) 
        ESX.ShowNotification(message, type) 
    end 

elseif Config.Framework == 'qbcore' then 
    local QBCore = exports['qb-core']:GetCoreObject() 
    
    Racing.Functions.Notify = function(message, type) 
        QBCore.Functions.Notify(message, type) 
    end 
    
elseif Config.Framework == 'standalone' then 
    -- No modo standalone, usamos a ox_lib, que é excelente e não depende de framework. 
    Racing.Functions.Notify = function(message, type)
        notify(message, type)
    end 
end

exports('getRacingFunctions', function()
    return Racing.Functions
end)