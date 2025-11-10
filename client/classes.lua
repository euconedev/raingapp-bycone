--- Returns the class of a vehicle.
-- Should only return the class as a string, ei A, B etc.
function getVehicleClass(vehicle)
    return GetVehicleClass(vehicle)
end

--- Returns a list of all vehicle classes.
-- Needs to be formatted as a table with <letter> = <number>
-- For example: { A = 100, B = 50 }
function getVehicleClasses()
    return {
        ["COMPACTS"] = 1,
        ["SEDANS"] = 2,
        ["SUVS"] = 3,
        ["COUPES"] = 4,
        ["MUSCLE"] = 5,
        ["SPORTS"] = 6,
        ["SPORTS_CLASSICS"] = 7,
        ["SUPER"] = 8,
        ["MOTORCYCLES"] = 9,
        ["OFF_ROAD"] = 10,
        ["INDUSTRIAL"] = 11,
        ["UTILITY"] = 12,
        ["VANS"] = 13,
        ["CYCLES"] = 14,
        ["BOATS"] = 15,
        ["HELICOPTERS"] = 16,
        ["PLANES"] = 17,
        ["SERVICE"] = 18,
        ["EMERGENCY"] = 19,
        ["MILITARY"] = 20,
        ["COMMERCIAL"] = 21,
        ["TRAILERS"] = 22,
        ["TRAINS"] = 23,
    }
end

