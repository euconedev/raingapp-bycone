# Comandos do cw-racingapp

Este documento lista todos os comandos disponíveis no recurso `cw-racingapp`, categorizados por sua funcionalidade.

## Comandos de Head2Head (`server/head2head.lua`)

- `/h2hsetup`: Configura um evento Impromptu.
- `/h2hjoin`: Entra em um evento Impromptu.
- `/impdebugmap`: Mostra as localizações de H2H no mapa (para depuração).
- `/cwdebughead2head [true/false]`: Ativa/desativa o modo de depuração para Head2Head.

## Comandos da GUI (`client/gui.lua`)

- `/showroute`: Exibe a rota.
- `/ignoreroads`: Ignora estradas.
- `/basicwaypoint`: Define um waypoint básico.

## Comandos Principais (`server/main.lua`)

- `/changeraceuserauth [racername] [auth_level]`: Altera a autoridade de um usuário de corrida. (Requer reconexão do jogador para efeito).
- `/createracinguser [racername] [citizenid]`: Cria um usuário de corrida.
- `/remracename [racername]`: Remove um nome de corrida do banco de dados.
- `/removeallracetracks`: Remove a tabela `race_tracks` do banco de dados.
- `/racingappcurated [track_id] [true/false]`: Marca/desmarca uma pista como curada.
- `/cwdebugracing [true/false]`: Ativa/desativa o modo de depuração para corridas.
- `/cwlisttracks`: Lista as pistas de corrida (para depuração).
- `/cwracingapplist`: Lista informações do racingapp (para depuração).

## Comandos de Equipes (`server/crews.lua`)

- `/createracingcrew [founder] [citizenid] [crew]`: Cria uma nova equipe de corrida.
- `/joinracingcrew [member] [crew]`: Entra em uma equipe de corrida.
- `/leaveracingcrew [citizenid] [crew]`: Sai de uma equipe de corrida.
- `/addwintocrew [crew]`: Adiciona uma vitória a uma equipe de corrida.
- `/addracetocrew [crew]`: Adiciona uma corrida a uma equipe de corrida.
- `/updateranking [crew] [rank]`: Atualiza o ranking de uma equipe de corrida.
- `/disbandracingcrew [crew]`: Desfaz uma equipe de corrida.
- `/printracingcrews`: Imprime as equipes de corrida (para depuração).
- `/printinvites`: Imprime os convites de equipes (para depuração).

## Comandos de Edição de Pistas (Client-side) (`client/main.lua`)

- `/clickAddCheckpoint`: Adiciona um checkpoint ao editor de pistas.
- `/clickDeleteCheckpoint`: Deleta o último checkpoint adicionado.
- `/clickMoveCheckpoint`: Move o checkpoint atual.
- `/clickSaveRace`: Salva a pista de corrida atual.
- `/clickIncreaseDistance`: Aumenta a distância de um elemento da pista.
- `/clickDecreaseDistance`: Diminui a distância de um elemento da pista.
- `/clickExit`: Sai do editor de pistas.
