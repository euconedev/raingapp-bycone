UseDebug = Config.Debug
UiIsOpen = false

Countdown = 10
FinishedUITimeout = false
IsFirstUser = false
CharacterHasLoaded = false

CurrentName = nil
CurrentAuth = nil
CurrentCrew = nil
CurrentCrypto = nil
CurrentRanking = nil
MyRacerNames = {}

Classes = getVehicleClasses()
Entities = {}
Kicked = false

RaceData = {
    InCreator = false,
    InRace = false,
    ClosestCheckpoint = 0
}

CurrentRaceData = {
    RaceId = nil,
    TrackId = nil,
    RaceName = nil,
    RacerName = nil,
    MaxClass = nil,
    Checkpoints = {},
    Started = false,
    CurrentCheckpoint = nil,
    TotalLaps = 0,
    TotalRacers = 0,
    Lap = 0,
    Position = 0,
    Ghosted = false,
}

function DebugLog(message, message2, message3, message4)
    if UseDebug then
        print('^2[Creative] ', message, message2, message3, message4)
    end
end

function GetActiveRacerName()
    local racerName = ""
    if Config.UseVrp then
        local user_id = VRP.getUserId({"player"})
        if user_id ~= nil then
            local identity = VRP.getUserIdentity({user_id})
            if identity ~= nil then
                racerName = identity.name .. " " .. identity.firstname
            end
        end
    else
        racerName = GetPlayerName(PlayerId())
    end
    return racerName
end
