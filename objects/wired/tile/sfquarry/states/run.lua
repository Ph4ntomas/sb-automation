--- Handle the quarry being stuck somewhere
-- If the quarry has been stuck for too long, try to find a new suitable position above.
local function handleStuck(quarry, actualPos)
    if quarry.headPos then
        local dist = world.distance(quarry.headPos, actualPos)
        if inPosition(dist, 0.01) then
            quarry.stuck = quarry.stuck + 1
            if quarry.stuck == 5 then
                quarry.returnPosition = homePos -- TODO: Find a better position.
                return true
            end
        else
            quarry.stuck = 0
        end
    end

    quarry.headPos = actualPos

    return false
end

local function digBackground(quarry, digPos) 
    local done = false

    for _, pos in pairs(digPos) do
        local mod = world.mod(pos, "background")

        if mod then
            local mconfig = root.modConfig(mod)

            if mconfig and mconfig["config"]["itemDrop"] ~= nil then
                world.placeMod(pos, "background", "grass", nil, false)
                world.damageTiles({pos}, "background", quarry.targetPos, "blockish", 0, 0)
                world.spawnItem({name = mconfig["config"]["itemDrop"], amount = 1}, pos)

                done = true
            end
        end
    end

    return done
end

local function dig(quarry, from)
    local digPos = {}
    from = from or quarry.headPos

    sfutil.safe_await(world.sendEntityMessage(quarry.id, "dig"))

    for i = 0.5 - (quarry.digRange / 2), (quarry.digRange / 2), 1 do
        local start = -(1) - 0.5
        local max = start - (quarry.digRange - 0.5)
        for j = start, max, -1 do
            digPos[#digPos + 1] = toAbsolutePosition(from, {i, j})
        end
    end

    local done = world.damageTiles(digPos, "foreground", from, "blockish", 25000)
    done = digBackground(quarry, digPos) or done

    if done then
        quarry.targetPos = nil
    end

    return done
end

local function moveToSpot(quarry)
    local distance = world.distance(quarry.targetPos, quarry.headPos)

    local res = moveQuarry(quarry, distance)

    return res
end

local function checkSpot(pos)
    local ret = false
    ret = world.pointCollision(pos)

    if not ret then
        local mod = world.mod(pos, "background")

        if mod then
            local mconfig = root.modConfig(mod)
            ret = (mconfig and mconfig["config"]["itemDrop"]) or ret
        end
    end 

    return ret
end

local function highlightChunk(posUp, posDown, color, label)
    poly = {
        posUp, {posDown[1], posUp[2]},
        posDown, {posUp[1], posDown[2]}
    }

    world.debugPoly(poly, color or "red")

    if label then
        local labelPos = {(posUp[1] + posDown[1]) / 2, (posUp[2] + posDown[2]) / 2}
        world.debugText(label, posDown, color or "red")
    end
end

local function checkChunk(quarry, col, line)
    local step = quarry.digRange * quarry.dir
    local rect = {col + 0.5 * quarry.dir, line - 0.5, col + step - 0.5 * quarry.dir, line - quarry.digRange + 0.5}

    local poly = {{rect[1], rect[2]}, {rect[3], rect[2]}, {rect[3], rect[4]}, {rect[1], rect[4]}}

    world.debugPoly(poly, "green")

    if world.rectCollision(rect) then
        return true
    else
        for y = rect[2], rect[4], -1 do
            for x = rect[1], rect[3], quarry.dir do
                if checkSpot({x, y}) then
                    return true
                end
            end
        end
    end

    return false
end

local function isBehind(dir, distance)
    if dir > 0 then
        return distance < 0
    else
        return distance > 0
    end
end

local function findSpot(quarry)
    local spot = nil
    local dist = nil
    local behind = false

    for line = quarry.headPos[2] - 1, quarry.maxDepth, -quarry.digRange do
        local startSearch = quarry.homePos[1] - quarry.dir
        local endSearch = startSearch + (quarry.width + 2) * quarry.dir
        local step = quarry.digRange * quarry.dir

        for col = startSearch, endSearch, step do
            if (quarry.dir > 0 and (col + step) > endSearch) or
                (quarry.dir < 0 and (col + step) < endSearch) then 
                col = endSearch - step 
            end

            if checkChunk(quarry, col, line) then
                center = col + (step / 2)
                distance = center - quarry.headPos[1]

                if math.abs(distance) <= 0.04 then
                    dist = math.abs(distance)
                    spot = {center, line + 1}
                    behind = false
                    break
                else
                    local curBehind = isBehind(quarry.curDir, distance)

                    if  not spot or
                        (behind and not curBehind) or
                        ((math.abs(distance)) < dist and behind == curBehind) -- we take the distance into account, but only if it does not change the direction of the quarry.
                    then
                        spot = {center, line + 1}
                        dist = math.abs(distance)
                        behind = curBehind
                    end
                end

                highlightChunk({col, line}, {col + step, line - quarry.digRange}, "green")
            else
                highlightChunk({col, line}, {col + step, line - quarry.digRange}, "red")
            end
        end

        if spot then
            highlightChunk(spot, {spot[1] + quarry.dir, spot[2] + 1}, "blue")
            break
        end
    end

    return spot, behind
end

local function moveToNextSpot(quarry)
    if quarry.targetPos then
        if moveToSpot(quarry) then
            return true
        end
    end

    local spot, turn = findSpot(quarry)

    quarry.targetPos = spot
    if turn then
        quarry.curDir = -quarry.curDir
    end

    if not quarry.targetPos then
        quarry.returnPosition = quarry.homePos
        quarry.active = false
    end

    return true
end

--- Query for drops in the vicinity of the quarry head. If some drop are found, try to take the item, and add it to the storageApi.
-- If the item does not fit in storage, the quarry head will drop it again.
local function takeDrops(quarry)
    local drops = world.itemDropQuery({ quarry.headPos[1], quarry.headPos[2] - (quarry.digRange)}, quarry.digRange / 2)

    if drops then
        for _, drop in pairs(drops) do
            local item = world.takeItemDrop(drop, quarry.id)

            if item then
                local ret = storageApi.storeItemFit(item.name, item.count, item.parameters)

                if ret > 0 then
                    item.count = ret
                    world.spawnItem(item)
                end
            end
        end
    end
end


--------------------------------------------------------------------------------
--  Run State                                                              --
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

runState = {}

function runState.enter()
    return nil
end

function runState.enterWith(quarry)
    if not quarry.run or not quarry.id or quarry.returnPosition then return nil end --or energy.getEnergy() < 1 then return nil end

    quarry.home = false
    quarry.stuck = 0
    quarry.loadTimer = 0

    return quarry
end

function runState.update(dt, quarry)
    local actualPos = world.entityPosition(quarry.id)

    if quarry.active and not storageApi.isFull() and energy.consumeEnergy(dt) then -- and energy.consumeEnergy(dt)
        if not actualPos then -- If we can't find a postion, reset the quarry to start from prepare state.
            quarry.id = false
            quarry.returnPosition = nil
            return true
        else
            loadQuarryRegions(dt, quarry)

            if handleStuck(quarry, actualPos) then return true end -- handleStuck should find a proper returnPosition. If the position is unreachable, it will be respawned by returnState.

            if quarry.targetPos then
                local dist = world.distance(quarry.targetPos, actualPos)
                if inPosition(dist, 0.04) then
                    dig(quarry)
                end
            end
            takeDrops(quarry)
            moveToNextSpot(quarry)

            return false -- while we can dig, continue
        end
    end

    quarry.returnPosition = quarry.homePos -- we come home if called by the user (active = false) or if the quarry is full.
    quarry.active = false

    return true
end

function runState.leavingState(quarry)
    nextState(quarry)
end
