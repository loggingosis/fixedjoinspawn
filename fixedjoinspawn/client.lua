-- EDIT THIS: your forced join spawn
local JOIN_SPAWN = vector4(-1037.6, -2737.7, 20.2, 330.0)

-- Internal state: ensure we only act on the join/initial spawn during THIS session,
-- but it will run again every time the player reconnects to the server.
local appliedThisSession = false

local function forceJoinSpawn()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) then return end

    -- Hard teleport to the join coordinate
    RequestCollisionAtCoord(JOIN_SPAWN.x, JOIN_SPAWN.y, JOIN_SPAWN.z)
    SetEntityCoordsNoOffset(ped, JOIN_SPAWN.x, JOIN_SPAWN.y, JOIN_SPAWN.z, false, false, false)
    SetEntityHeading(ped, JOIN_SPAWN.w)
    FreezeEntityPosition(ped, true)

    -- Ensure ground + collision
    local timeout = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        Wait(0)
    end
    local foundGround, groundZ = GetGroundZFor_3dCoord(JOIN_SPAWN.x, JOIN_SPAWN.y, JOIN_SPAWN.z + 50.0, false)
    if foundGround then
        SetEntityCoordsNoOffset(ped, JOIN_SPAWN.x, JOIN_SPAWN.y, groundZ, false, false, false)
    end

    -- Unfreeze after stabilization
    Wait(250)
    FreezeEntityPosition(ped, false)
end

-- This fires when the network player becomes active (each time they join/reconnect)
AddEventHandler('playerSpawned', function()
    -- playerSpawned also fires on some respawn flows; we refuse to handle those by:
    -- - applying once per session only, and
    -- - only when the player has just become network-active (first spawn after join).
    if appliedThisSession then return end
    appliedThisSession = true

    -- Delay a bit so other resources finish their own initial positioning,
    -- then override to the fixed join spawn.
    CreateThread(function()
        Wait(1000)
        forceJoinSpawn()
    end)
end)

-- Extra safeguard: if some framework teleports after playerSpawned,
-- re-apply shortly after join initialization only (still once per session).
CreateThread(function()
    -- Wait until player is active in-session
    while not NetworkIsPlayerActive(PlayerId()) do
        Wait(100)
    end

    -- If playerSpawned didn’t run for some reason, apply once here.
    if not appliedThisSession then
        appliedThisSession = true
        Wait(1000)
        forceJoinSpawn()
    end
end)
