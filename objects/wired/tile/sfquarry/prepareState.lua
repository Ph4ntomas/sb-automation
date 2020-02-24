--------------------------------------------------------------------------------
-- Local functions                                                            --
--------------------------------------------------------------------------------

--- Draw two beams from one position to another, and stop on first collision.
-- @param from - The position to begin scanning
-- @param range - the number of tiles to check
-- @param dir - The direction in which scanning should happens (either 1 or -1)
local function drawBeams(from, range, dir)
    for h = 0, 1 do
        for i = 2, range,1 do
            local pos = toAbsolutePosition(from, { dir * i, h + 0.5 })

            world.spawnProjectile("beam", pos, entity.id(), {0, 0}, false, {})
            if world.pointCollision(pos) then
                break
            end
        end
    end
end

--- Check every tile from the quarry up to it's maximum range to find the first marker in range.
-- @param from - The position to begin scanning
-- @param range - the number of tiles to check
-- @param dir - The direction in which scanning should happens (either 1 or -1)
-- #return Either false, or a table contaning the id of the marker as it's first value, and it's position as the second value.
local function scanForMaker(from, range, dir)
    sb.logInfo("scanForMarker")
    local marker = nil
    local pos = toAbsolutePosition(from, { dir * range, 0})

    world.debugLine(from, pos, "blue")
    local entityIds = world.objectLineQuery(from, pos, {name = "sfquarrymarker", withoutEntityId = entity.id(), order = "nearest"})

    if entityIds then
        for _, id in ipairs(entityIds) do
            world.debugText("entityType = %s", world.entityTypeName(id), world.entityPosition(id), "blue")
            if world.entityTypeName(id) == "sfquarrymarker" then
                return {id, world.entityPosition(id)}
            end
        end
    end

    return marker
end

--- Find the position of the opposite side of the quarry, by finding the nearest marker, up to max range,
-- checking for collision within said range,
-- If a suitable position is found, quarry's stand position is set in storage, as well as it's position, and it's width.
-- @return True if a suitable position was found.
local function findStandPosition(quarry)
    sb.logInfo("findingStand")
    local dir = quarry.dir
    local scanFrom = {quarry.pos[1] + quarry.dir, quarry.pos[2] - 1}
    if quarry.dir > 0 then
        scanFrom[1] = scanFrom[1] + quarry.dir
    end
    local marker = scanForMaker(scanFrom, quarry.range, dir)
    local pos = nil
    local collisionPos = nil

    sb.logInfo("marker %s", marker)
    if marker then
        pos = marker[2]
    else
        pos = toAbsolutePosition(quarry.pos, { dir * quarry.range, 0 })
    end

    if dir < 0 then
        colCheck = {
            pos[1] - dir * 2, pos[2],
            quarry.pos[1] + dir * 2, quarry.pos[2] + 1
        }
    else
        colCheck = {
            quarry.pos[1] + dir * 2, quarry.pos[2],
            pos[1] - dir * 2, pos[2] + 1
        }
    end

    if not world.rectCollision(colCheck) then
        if not marker or world.breakObject(marker[1], false) then
            quarry.standPos = pos
            quarry.width = math.ceil(math.abs(world.distance(pos, quarry.pos)[1])) - 3 -- is this the width of the quarry ? maybe
            return true
        end
    else
        drawBeams(quarry, math.abs(pos[1] - quarry.pos[1]), dir)
        quarry.active = false
    end

    return false
end

--- Place quarry holders object.
-- @param from - The position to begin building
-- @param range - the number of tiles to place
-- @param dir - The direction in which building should happens (either 1 or -1)
-- @return 
local function setupQuarryHolders(from, range, dir)
    local pos = {0, from[2]}
    for i = 1, range do
        pos[1] = i * -dir + from[1]
        world.placeObject("sfquarry_holder", pos, dir)
        i = i + 1
    end

    return true
end

--- Setup quarry stand and quarry head holders.
-- @param Quarry data.
-- @return boolean - True if the stand is properly placed.
local function placeStand(quarry)
    local dir = quarry.dir
    local standQuarryId = world.placeObject("sfquarry_stand", quarry.standPos, -dir)

    if standQuarryId then
        quarry.standId = standQuarryId
        quarry.quarryHolders = setupQuarryHolders(
            quarry.standPos, quarry.width + 1, dir
        )

        return true
    end

    return false
end

--- Setup initial quarry head position and direction, then spawn quarry.
-- @param Quarry data,
-- @return This function return nothing.
local function bootQuarry(quarry)
    local pos = {quarry.dir, 0}
    if quarry.dir > 0 then
        pos[1] = pos[1] + quarry.dir
    end
    local spawnPos = toAbsolutePosition(quarry.pos, pos)

    quarry.headPos = spawnPos
    quarry.homePos = spawnPos
    quarry.curDir = quarry.dir

    spawnQuarry(quarry)
end

--- Run the quarry if it stored and real positiona are the same. Instruct it to replace if not.
-- @param quarry - Quarry data.
local function replaceOrRunQuarry(quarry)
    local pos = quarry.headPos

    if not inPosition(world.distance(pos, world.entityPosition(quarry.id))) then
        if energy.getEnergy() < 1 or quarry.stuck > 5 then
            quarry.active = false
            quarry.returnPosition = quarry.homePos
        else
            quarry.returnPosition = pos
        end
    else
        quarry.run = 1
    end
end


--------------------------------------------------------------------------------
--  Prepare State                                                             --
--                                                                            --
--  PreConditions :                                                           --
--      Quarry should not be already running.                                 --
--      Quarry should not be returning somewhere.                             --
--  State Actions :                                                           --
--      The state ensure the quarry is properly set up.                       --
--      It takes 2 ticks to complete each steps, but skip steps already       --
--      complete, and retry failed step before moving to the next.            --
--                                                                            --
--      Steps:                                                                --
--        - Find stand position                                               --
--        - place stand position                                              --
--        - spawn quarry                                                      --
--        - run quarry                                                        --
--  State results :                                                           --
--      When the state end, three comportment can happens:                    --
--            - If the quarry is in it's stored position, the quarry will     --
--              resume or start.                                              --
--            - If the quarry has enough energy, the quarry will be returned  --
--              to it's last stored position.                                 --
--            - In any other case, the quarry will be returned to it's home   --
--              position.                                                     --
--------------------------------------------------------------------------------

prepareState = {}

--- Enter preparation state, or skip it if the quarry is prepared.
-- @param quarry - Data representing the quarry.
function prepareState.enterWith(quarry)
    if quarry.returnPosition or quarry.run then return nil end
    sb.logInfo("Quarry %s enter prepareState with %s", entity.id(), quarry)
    return quarry
end

function prepareState.update(dt, quarry)
    if quarry.build then -- We are building the quarry
        if quarry.standPos == nil then -- quarry stand is either not set up, or lost somehow
            findStandPosition(quarry)
            return false, 2
        elseif quarry.standId == nil then -- position has been found, but no stand has been placed yet (or somehow lost)
            placeStand(quarry)
            return false, 2
        elseif not quarry.id or not world.entityExists(quarry.id) then -- quarry head has not been spawn or does no longer exists
            bootQuarry(quarry)
            return false, 2
        elseif quarry.active then -- everything is OK. Starting quarry
            replaceOrRunQuarry(quarry)

            return true
        end
    end

    return false, 2 -- preparation is not done yet, wait for 2 ticks
end

function prepareState.leavingState(quarry)
    nextState(quarry)
end
