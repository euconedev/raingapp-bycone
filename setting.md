# Configurações de Localização - cw-racingapp

Documentação dos locais onde são utilizados os seguintes termos:
- `busca`
- `passaporte` 
- `id`
- `dinheiro`
- `user_id`

## 1. Termo: busca
### Arquivo: server/main.lua
- Linha 411: `-- Adiciona prêmio de 6000 dinheiro sujo para cada corredor`
- Linha 727: `TriggerClientEvent('cw-racingapp:client:notify', playerSrc, 'Você ganhou ' .. reward .. ' de dinheiro na corrida!', 'success')`

### Arquivo: server/main_original.lua
- Mesmas ocorrências que main.lua

## 2. Termo: passport
### Arquivo: server/main_original.lua
- Linha 201: `RegisterNetEvent('cw-racingapp:playerCharacterChosen', function(source, passport))` - Evento que recebe o passport.
- Linha 203: `local user_id = passport` - Atribuição do passport ao user_id.
- Linha 206: `print('^2[Creative] Personagem escolhido - Source:', src, 'Passport:', user_id, '^0')` - Log do passport.
- Linha 218: `-- Busca os dados do corredor usando o user_id (passport)` - Comentário indicando uso do passport para buscar dados.
- Linha 1313: `for passports, sources in pairs(policeService) do` - Iteração sobre passports (provavelmente IDs de jogadores).
- Linha 1942-1943: `if vRP and vRP.Passport then user_id = vRP.Passport(source)` - Obtenção do user_id através de `vRP.Passport`.
- Linha 1963: `if UseDebug then print('^2DEBUG: getActiveRacerName - vRP.Passport(source) retornou:', user_id, '^0') end` - Debug do retorno de `vRP.Passport`.
- Linha 2017-2021: `if not vRP or not vRP.Passport then local user_id = vRP.Passport(source)` - Verificação e obtenção do user_id.
- Linha 2041: `RegisterNetEvent('cw-racingapp:playerCharacterChosen', function(source, passport))` - Evento que recebe o passport.
- Linha 2043: `local user_id = passport` - Atribuição do passport ao user_id.
- Linha 2046: `print('^2[Creative] Personagem escolhido - Source:', src, 'Passport:', user_id, '^0')` - Log do passport.
- Linha 2053: `-- Busca os dados do corredor usando o user_id (passport)` - Comentário indicando uso do passport para buscar dados.
- Linha 2085-2087: `-- Verifica se o vRP está pronto e se o jogador tem um passport válido if vRP and vRP.Passport then local user_id = vRP.Passport(playerSource)` - Verificação e obtenção do user_id.
- Linha 2178-2179: `if vRP.Passport then user_id = vRP.Passport(source)` - Obtenção do user_id através de `vRP.Passport`.

### Arquivo: server/main.lua
- Mesmas ocorrências que server/main_original.lua

### Arquivo: bridge/server_bridge.lua
- Linha 12: `print('DEBUG: vRP.Passport exists?', type(vRP.Passport) ~= 'nil')` - Debug para verificar a existência de `vRP.Passport`.
- Linha 172-174: `if vRP.Passport then user_id = vRP.Passport(source) if UseDebug then print('DEBUG: GetCitizenId - vRP.Passport returned user_id:', user_id) end` - Obtenção e debug do user_id.

### Arquivo: bridge/vrp_bridge.lua
- Linha 21: `-- No Creative, usa vRP.Passport() ou vRP.getUserId()` - Comentário sobre o uso de `vRP.Passport()` ou `vRP.getUserId()`.
- Linha 24-25: `if vRP.Passport then user_id = vRP.Passport(source)` - Obtenção do user_id através de `vRP.Passport`.
- Linha 41: `local user_id = vRP.Passport(source)` - Obtenção do user_id através de `vRP.Passport`.
- Linha 59: `local user_id = vRP.Passport(source)` - Obtenção do user_id através de `vRP.Passport`.
- Linha 68: `local user_id = vRP.Passport(source)` - Obtenção do user_id através de `vRP.Passport`.
- Linha 79: `local user_id = vRP.Passport(source)` - Obtenção do user_id através de `vRP.Passport`.

## 3. Termo: identity
### Arquivo: bridge/server/standalone.lua
- Linha 12: `local identity = vRP.getUserIdentity(user_id)` - Obtenção da identidade do usuário.
- Linha 13: `if identity and identity.job then` - Verificação da existência da identidade e do cargo.
- Linha 24: `local identity = exports['vrpex']:getUserIdentity(user_id)` - Obtenção da identidade do usuário via `vrpex`.
- Linha 25: `if identity and identity.job then` - Verificação da existência da identidade e do cargo.

### Arquivo: bridge/vrp_bridge.lua
- Linha 44: `local identity = vRP.Identity(user_id)` - Obtenção da identidade do usuário.
- Linha 45: `if identity then` - Verificação da existência da identidade.
- Linha 46-47: `if identity.firstname and identity.name then return identity.firstname .. " " .. identity.name` - Retorna nome completo.
- Linha 48-49: `elseif identity.name then return identity.name` - Retorna apenas o nome.

### Arquivo: client/globals.lua
- Linha 53: `local identity = VRP.getUserIdentity({user_id})` - Obtenção da identidade do usuário.
- Linha 54: `if identity ~= nil then` - Verificação da existência da identidade.
- Linha 55: `racerName = identity.name .. " " .. identity.firstname` - Concatenação do nome completo.

### Arquivo: bridge/client/creative.lua
- Linha 26: `local identity = vRP.getUserIdentity(user_id)` - Obtenção da identidade do usuário.
- Linha 27: `if identity and identity.job then` - Verificação da existência da identidade e do cargo.
- Linha 189: `local identity = vRP.getUserIdentity(user_id)` - Obtenção da identidade do usuário.
- Linha 190: `if identity then` - Verificação da existência da identidade.
- Linha 191: `return identity.firstname .. " " .. identity.name` - Retorna nome completo.

### Arquivo: bridge/client/standalone.lua
- Linha 64: `TriggerServerEvent("vRP:getUserIdentity", user_id, function(identity))` - Requisição da identidade do usuário ao servidor.
- Linha 65: `if identity and identity.job then` - Verificação da existência da identidade e do cargo.
- Linha 75: `local identity = exports['vrpex']:getUserIdentity(user_id)` - Obtenção da identidade do usuário via `vrpex`.
- Linha 76: `if identity and identity.job then` - Verificação da existência da identidade e do cargo.

### Arquivo: bridge/server_bridge.lua
- Linha 389: `local identity = vRP.getUserIdentity and vRP.getUserIdentity(user_id)` - Obtenção condicional da identidade do usuário.
- Linha 390: `if identity and identity.job then` - Verificação da existência da identidade e do cargo.

## 4. Termo: id
### Arquivo: server/main.lua
- Linha 1939-1963: Lógica de obtenção de user_id
- Linha 2177-2185: Conversão para citizenId

## 4. Termo: dinheiro
### Arquivo: bridge/vrp_bridge.lua
- Linha 57: `-- Adaptação das funções de dinheiro`

### Arquivo: locales/pt.lua  
- Linha 387: `["dirty_money_currency"] = "dinheiro sujo"`

## 5. Termo: user_id
### Arquivo: bridge/client/creative.lua
- Linha 24-26: `local user_id = vRP.getUserId(source) if user_id then local identity = vRP.getUserIdentity(user_id)` - Obtenção do user_id e da identidade.
- Linha 36-37: `local user_id = vRP.getUserId(source) if user_id then` - Obtenção e verificação do user_id.
- Linha 53-54: `local user_id = vRP.getUserId(source) if user_id then` - Obtenção e verificação do user_id.
- Linha 57: `local item_count = vRP.getInventoryItemAmount(user_id, Config.ItemName.gps)` - Uso do user_id para verificar itens no inventário.
- Linha 68: `local item_count = vRP.getInventoryItemAmount(user_id, Config.ItemName.gps)` - Uso do user_id para verificar itens no inventário.
- Linha 87-90: `local user_id = RacingFunctions.GetCitizenId(source) if user_id then return tostring(user_id)` - Obtenção e retorno do user_id.
- Linha 146-147: `local user_id = vRP.getUserId(source) if not user_id then return end` - Obtenção e verificação do user_id.
- Linha 187-189: `local user_id = vRP.getUserId(source) if user_id then local identity = vRP.getUserIdentity(user_id)` - Obtenção do user_id e da identidade.
- Linha 198-200: `local user_id = vRP.getUserId(source) if user_id then return vRP.getMoney(user_id)` - Obtenção do user_id e do dinheiro.

### Arquivo: bridge/server_bridge.lua
- Linha 95-96: `local user_id = vRP.getUserId(source) if user_id then` - Obtenção e verificação do user_id.
- Linha 99: `user_id = user_id,` - Atribuição do user_id.
- Linha 108-109: `local user_id = vRP.getUserId(source) if user_id then` - Obtenção e verificação do user_id.
- Linha 112: `vRP.giveMoney(user_id, amount)` - Dar dinheiro ao user_id.
- Linha 114: `vRP.giveBankMoney(user_id, amount)` - Dar dinheiro no banco ao user_id.
- Linha 116: `if UseDebug then print('DEBUG: AddMoney successful for user_id', user_id, 'amount', amount) end` - Debug de adição de dinheiro.
- Linha 119: `print('ERROR: AddMoney - No user_id found for source', source)` - Erro se user_id não encontrado.
- Linha 125-127: `local user_id = vRP.getUserId(source) if not user_id then print("[ERROR] RemoveMoney - No user_id found for source " .. source)` - Obtenção e verificação do user_id para remover dinheiro.
- Linha 130: `if vRP.tryPayment(user_id, amount) then` - Tentativa de pagamento com user_id.
- Linha 140-141: `local user_id = vRP.getUserId(source) if user_id then` - Obtenção e verificação do user_id para obter dinheiro.
- Linha 144: `money = vRP.getMoney(user_id)` - Obtenção de dinheiro do user_id.
- Linha 146: `money = vRP.getBankMoney(user_id)` - Obtenção de dinheiro do banco do user_id.
- Linha 169: `local user_id = nil` - Inicialização do user_id.
- Linha 173: `user_id = vRP.Passport(source)` - Obtenção do user_id via Passport.
- Linha 174: `if UseDebug then print('DEBUG: GetCitizenId - vRP.Passport returned user_id:', user_id) end` - Debug do user_id do Passport.
- Linha 176: `user_id = vRP.getUserId(source)` - Obtenção do user_id via `vRP.getUserId`.
- Linha 177: `if UseDebug then print('DEBUG: GetCitizenId - vRP.getUserId returned user_id:', user_id) end` - Debug do user_id de `vRP.getUserId`.
- Linha 180-182: `if user_id then return "vRP_" .. tostring(user_id)` - Retorno do citizenId formatado.
- Linha 185: `if UseDebug then print('DEBUG: GetCitizenId - No user_id found for source:', source) end` - Debug se user_id não encontrado.
- Linha 194-197: `local user_id = tonumber(citizenId:gsub("vRP_", "")) if user_id and vRP.getUserSource then local source = vRP.getUserSource(user_id)` - Extração e uso do user_id do citizenId.
- Linha 234-235: `local user_id = vRP.getUserId(source) if user_id then` - Obtenção e verificação do user_id.
- Linha 237: `vRP.giveMoney(user_id, amount)` - Dar dinheiro ao user_id.
- Linha 239: `vRP.giveBankMoney(user_id, amount)` - Dar dinheiro no banco ao user_id.
- Linha 241: `if UseDebug then print('DEBUG: AddMoney successful for user_id', user_id, 'amount', amount) end` - Debug de adição de dinheiro.
- Linha 265-266: `local user_id = vRP.getUserId(source) if user_id then` - Obtenção e verificação do user_id para remover dinheiro.
- Linha 267: `if vRP.tryPayment(user_id, amount) then` - Tentativa de pagamento com user_id.
- Linha 268: `if UseDebug then print('DEBUG: RemoveMoney successful for user_id', user_id, 'amount', amount) end` - Debug de remoção de dinheiro.
- Linha 271: `print('ERROR: RemoveMoney - Payment failed for user_id', user_id, 'amount', amount)` - Erro de pagamento.
- Linha 292-293: `local user_id = vRP.getUserId(source) if user_id then` - Obtenção e verificação do user_id para obter dinheiro.
- Linha 296: `money = vRP.getMoney(user_id)` - Obtenção de dinheiro do user_id.
- Linha 298: `money = vRP.getBankMoney(user_id)` - Obtenção de dinheiro do banco do user_id.
- Linha 322-324: `local user_id = vRP.getUserId(source) if user_id then return "vRP_" .. tostring(user_id)` - Retorno do citizenId formatado.
- Linha 347-350: `local user_id = tonumber(citizenId:gsub("vRP_", "")) if user_id and vRP and vRP.getUserSource then local source = vRP.getUserSource(user_id)` - Extração e uso do user_id do citizenId.
- Linha 387-391: `local user_id = vRP.getUserId(src) if user_id then local identity = vRP.getUserIdentity and vRP.getUserIdentity(user_id)` - Obtenção do user_id e da identidade.
- Linha 418-420: `local user_id = vRP.getUserId(src) if user_id then local amount = vRP.getInventoryItemAmount(user_id, itemName)` - Obtenção do user_id e da quantidade de itens no inventário.
- Linha 446-448: `local user_id = vRP.getUserId(src) if user_id then cb(vRP.getMoney(user_id))` - Obtenção do user_id e do dinheiro.
- Linha 462-464: `local user_id = vRP.getUserId(src) if user_id then cb(vRP.hasPermission(user_id, permission))` - Obtenção do user_id e verificação de permissão.

### Arquivo: server/main.lua
- Linha 203: `local user_id = passport` - Atribuição do passport ao user_id.
- Linha 206: `print('^2[Creative] Personagem escolhido - Source:', src, 'Passport:', user_id, '^0')` - Log do passport.
- Linha 218: `-- Busca os dados do corredor usando o user_id (passport)` - Comentário indicando uso do passport para buscar dados.
- Linha 380-382: `local user_id = vRP.getUserId(src) if not racerName and user_id then racerName = "Racer_" .. user_id` - Fallback para user_id se racerName for nil.
- Linha 385: `vRP.tryPayment(user_id, math.floor(tonumber(amount)))` - Tentativa de pagamento com user_id.
- Linha 402-404: `local user_id = vRP.getUserId(src) return vRP.hasMoney(user_id, math.floor(tonumber(amount)))` - Verificação de dinheiro com user_id.
- Linha 1939: `local user_id = nil` - Inicialização do user_id.
- Linha 1943-1945: `user_id = vRP.Passport(source) if user_id and user_id > 0 then if UseDebug then print('^2DEBUG: User ID obtido com sucesso:', user_id, '^0') end` - Obtenção e debug do user_id via Passport.
- Linha 1951: `print('^3DEBUG: Aguardando user_id... Tentativa', attempts, 'de', maxAttempts, '^0')` - Debug de espera pelo user_id.
- Linha 1956-1958: `if not user_id then print('^1DEBUG: getActiveRacerName - Não foi possível obter user_id para source:', source, ' após ', attempts, ' tentativas^0')` - Erro se user_id não obtido.
- Linha 1963: `if UseDebug then print('^2DEBUG: getActiveRacerName - vRP.Passport(source) retornou:', user_id, '^0') end` - Debug do user_id do Passport.
- Linha 1969: `local allRacersForCitizen = RADB.getRaceUsersBelongingToCitizenId(tostring(user_id))` - Busca de corredores por user_id.
- Linha 1972: `print('^2DEBUG: getActiveRacerName - Racers encontrados para user_id', user_id, ':', json.encode(allRacersForCitizen), '^0')` - Debug de corredores encontrados.
- Linha 2004: `RADB.changeRaceUser(tostring(user_id), firstRacer.racername)` - Mudança de corredor com user_id.
- Linha 2021-2022: `local user_id = vRP.Passport(source) return user_id and user_id > 0` - Obtenção e verificação do user_id via Passport.
- Linha 2043: `local user_id = passport` - Atribuição do passport ao user_id.
- Linha 2046: `print('^2[Creative] Personagem escolhido - Source:', src, 'Passport:', user_id, '^0')` - Log do passport.
- Linha 2047: `TriggerClientEvent(source, 'cw-racingapp:client:characterSelected', user_id)` - Evento de seleção de personagem com user_id.
- Linha 2053: `-- Busca os dados do corredor usando o user_id (passport)` - Comentário indicando uso do passport para buscar dados.
- Linha 2087-2088: `local user_id = vRP.Passport(playerSource) if user_id and user_id > 0 then` - Obtenção e verificação do user_id via Passport.
- Linha 2177: `local user_id = nil` - Inicialização do user_id.
- Linha 2179: `user_id = vRP.Passport(source)` - Obtenção do user_id via Passport.
- Linha 2181: `user_id = vRP.getUserId(source)` - Obtenção do user_id via `vRP.getUserId`.
- Linha 2184-2185: `if user_id then citizenId = "vRP_" .. tostring(user_id)` - Formatação do citizenId com user_id.

### Arquivo: bridge/server/standalone.lua
- Linha 10-12: `local user_id = vRP.getUserId(src) if user_id then local identity = vRP.getUserIdentity(user_id)` - Obtenção do user_id e da identidade.
- Linha 22-24: `local user_id = exports['vrpex']:getUserId(src) if user_id then local identity = exports['vrpex']:getUserIdentity(user_id)` - Obtenção do user_id e da identidade via `vrpex`.
- Linha 54-56: `local user_id = vRP.getUserId(src) if user_id then local amount = vRP.getInventoryItemAmount(user_id, itemName)` - Obtenção do user_id e da quantidade de itens no inventário.
- Linha 71-72: `local user_id = vRP.getUserId(src) cb(tostring(user_id))` - Obtenção e retorno do user_id.
- Linha 78-79: `local user_id = exports['vrpex']:getUserId(src) cb(tostring(user_id))` - Obtenção e retorno do user_id via `vrpex`.
- Linha 98-100: `local user_id = vRP.getUserId(src) if user_id then cb(vRP.getMoney(user_id))` - Obtenção do user_id e do dinheiro.
- Linha 114-116: `local user_id = vRP.getUserId(src) if user_id then cb(vRP.hasPermission(user_id, permission))` - Obtenção do user_id e verificação de permissão.

### Arquivo: bridge/client/standalone.lua
- Linha 61-64: `local user_id = nil TriggerServerEvent("vRP:getUserId", function(_user_id) user_id = _user_id end) if user_id then TriggerServerEvent("vRP:getUserIdentity", user_id, function(identity))` - Obtenção do user_id via evento do servidor e da identidade.
- Linha 73-75: `local user_id = exports['vrpex']:getUserId() if user_id then local identity = exports['vrpex']:getUserIdentity(user_id)` - Obtenção do user_id e da identidade via `vrpex`.

### Arquivo: client/main.lua
- Linha 33-35: `RegisterNetEvent('cw-racingapp:client:characterSelected', function(user_id) print('^2[Creative] Personagem selecionado no cliente, user_id:', user_id)` - Evento de seleção de personagem com user_id.

### Arquivo: server/main_original.lua
- Mesmas ocorrências que server/main.lua

### Arquivo: bridge/vrp_bridge.lua
- Linha 22-30: `local user_id = nil user_id = vRP.Passport(source) user_id = vRP.getUserId(source) return user_id` - Obtenção do user_id via Passport ou `vRP.getUserId`.
- Linha 34-36: `Racing.Functions.GetSrcOfPlayerByCitizenId = function(user_id) if not user_id then return nil end return vRP.Source(user_id)` - Obtenção da source a partir do user_id.
- Linha 41-42: `local user_id = vRP.Passport(source) if not user_id then return GetPlayerName(source) end` - Obtenção do user_id via Passport ou nome do jogador.
- Linha 44: `local identity = vRP.Identity(user_id)` - Obtenção da identidade com user_id.
- Linha 59-61: `local user_id = vRP.Passport(source) if user_id then vRP.GiveMoney(user_id, amount)` - Obtenção do user_id e dar dinheiro.
- Linha 68-71: `local user_id = vRP.Passport(source) if user_id then if vRP.GetBank(user_id) >= amount then vRP.TakeBank(user_id, amount)` - Obtenção do user_id e verificação/remoção de dinheiro do banco.
- Linha 79-81: `local user_id = vRP.Passport(source) if user_id then return vRP.GetBank(user_id) >= amount` - Obtenção do user_id e verificação de dinheiro no banco.

### Arquivo: bridge/server/creative.lua
- Linha 22-24: `CreativeBridge.getInventoryItemAmount = function(user_id, item) return vRP.getInventoryItemAmount(user_id, item)` - Obtenção da quantidade de itens no inventário com user_id.
- Linha 29-31: `CreativeBridge.tryPayment = function(user_id, amount) return vRP.tryPayment(user_id, amount)` - Tentativa de pagamento com user_id.
- Linha 36-40: `CreativeBridge.giveMoney = function(user_id, amount) return vRP.giveMoney(user_id, amount) return vRP.giveBankMoney(user_id, amount)` - Dar dinheiro ao user_id.
- Linha 45-47: `CreativeBridge.getUserSource = function(user_id) return vRP.getUserSource(user_id)` - Obtenção da source a partir do user_id.
- Linha 52-54: `CreativeBridge.hasPermission = function(user_id, permission) return vRP.hasPermission(user_id, permission)` - Verificação de permissão com user_id.

### Arquivo: client/globals.lua
- Linha 51-53: `local user_id = VRP.getUserId({"player"}) if user_id ~= nil then local identity = VRP.getUserIdentity({user_id})` - Obtenção do user_id e da identidade.