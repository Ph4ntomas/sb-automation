--------------------------------------------------------------------------------
--  Local helper functions                                                    --
--------------------------------------------------------------------------------

local function handleStuck(quarry, actualPos)
    if inPosition({quarry.pos[1] - actualPos[1], quarry.pos[2] - actualPos[2]}, 0.01) then
        quarry.stuck = quarry.stuck + 1
        if quarry.stuck > 5 then
            quarry.run = nil
            quarry.active = false
            quarry.id = respawnQuarry(quarry, homePos)
            return true
        end
    end

    return false
end

--------------------------------------------------------------------------------
--  Return State                                                              --
--                                                                            --
--  Pre Conditions:                                                           --
--      The quarry head has been spawned.                                     --
--      Quarry should have a return position                                  --
--  State Actions:                                                            --
--                                                                            --
--                                                                            --
--                                                                            --
--                                                                            --
--                                                                            --
--                                                                            --
--                                                                            --

returnState = {}

function returnState.enterWith(quarry)
    if not quarry.returnPosition then
        return nil
    elseif not quarry.id then
        quarry.run = false
        quarry.returnPosition = nil
        return nil
    end

    quarry.stuck = 0
    quarry.loadTimer = 0

    return quarry
end

function returnState.update(dt, quarry)
    local quarryPos = world.entityPosition(quarry.id)

    if quarryPos then
        loadQuarryRegions(dt, quarry)
        if handleStuck(quarry, quarryPos) then
            return true
        end

        local distance = world.distance(quarry.returnPosition, quarry.headPos)
        if inPosition(distance, 0.04) then
            quarry.home = true
            return true
        end

        quarry.headPos = quarryPos

        if moveQuarry(quarry, distance) then
            return false
        end
    else
        quarry.id = nil
        quarry.run = nil
    end

    return true
end

function returnState.leavingState(quarry)
    if quarry.stuck > 5 then -- stuck for too long. The quarry should have been respawned.
        quarry.run = false
        quarry.active = false
    end

    if quarry.id then
        sfutil.safe_await(world.sendEntityMessage(quarry.id, "collide"))
    end

    quarry.returnPosition = nil

    nextState(quarry)
end
