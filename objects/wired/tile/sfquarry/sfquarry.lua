function init()
    energy.init()
    storageApi.init({mode = 2, capacity = 16, merge = true, join = true, ondeath = 1})
    pipes.init({itemPipe}, true)

    object.setInteractive(true)

    self.state = stateMachine.create({
        "prepareState", 
        "runState",
        "returnState"
    })
    self.state.autoPickState = nil
    self.state.leavingState = function(stateName) end

    function nextState(data)
        return self.state.pickState(data)
    end

    if storage.quarry == nil then
        storage.quarry = {
            run = nil,
            build = false,
            dig = false,
            home = false,
            stuck = 0,
            range = 25,
            pos = object.position(),
            dir = object.direction(),
            loadInterval = config.getParameter("returningLoadInterval"),
            maxDepth = config.getParameter("maxDepth") or 100,
            digRange = config.getParameter("digRange") or 2
        }
    end

    storage.quarry.digRange = 3

    self.state.pickState(storage.quarry)

    updateAnimationState()
end

function update(dt)
    local pos = object.position()

    self.state.update(dt)
    pipes.update(dt)
    energy.update(dt)

    storage.quarry.home = isHome(storage.quarry)

    if storage.quarry.home then
        sendItem()
    end

    updateAnimationState()
end

function onInteraction(args, active)
    if storage.quarry.home and storageApi.getCount() > 0 then
        storageApi.dropAll()
    else
        storage.quarry.build = true
        storage.quarry.active = active or not storage.quarry.active

        if storage.run or storage.run == false then
            storage.run = not storage.run
        end

        if not storage.quarry.active and storage.quarry.id then
            sfutil.safe_await(world.sendEntityMessage(storage.quarry.id, "collide"))
        end

        if not self.state.hasState() then
            self.state.pickState(storage.quarry)
        end
    end

    updateAnimationState()
end

-------------------

function destroyQuarryHolders(from, range, dir)
    local pos = {0, from[2] + 1}
    for i=1, range do
        pos[1] = i * -dir + from[1]
        world.damageTiles({pos}, "foreground", from, "plantish", 22000)
    end

    return false
end

function bootQuarry(quarry)
    local dir = object.direction()
    local spawnPos = object.toAbsolutePosition({math.min(0, dir), 0})

    --animator.setAnimationState("quarryState", "idle")

    quarry.pos = spawnPos
    quarry.homePos = spawnPos
    quarry.dir = dir
    quarry.curDir = dir
end

----------------------

local function isStuck(quarry, quarryPos)
    if inPosition({quarry.pos[1] - quarryPos[1], quarry.pos[2] - quarryPos[2]}, 0.01) then
        self.stuck = self.stuck + 1
        if self.stuck > 4 then
            quarry.curPos[1] = 0
            quarry.curPos[2] = quarry.curPos[2] + 2
            if quarry.curPos[2] > 0 then quarry.curPos[2] = 0 end
            return true
        end
    end

    return false
end

function loadRegions(quarry)
    --Load quarry digging position
    if quarry.headPos then
        local minPosX = toAbsolutePosition(quarry.homePos, {-5.5 * quarry.dir, 0})[1]
        local maxPosX = toAbsolutePosition(quarry.homePos, {(quarry.width + 5.5) * quarry.dir, 0})[1]
        local minPosY = toAbsolutePosition(quarry.headPos, {0, -5.5 - quarry.digRange})[2]
        local maxPosY = toAbsolutePosition(quarry.headPos, {0, 5.5})[2]

        local poly = {
            {minPosX, minPosY}, {minPosX, maxPosY},
            {maxPosX, maxPosY}, {maxPosX, minPosY}
        }
        world.debugPoly(poly, "blue")

        world.loadRegion({minPosX, minPosY, maxPosX, maxPosY})
    end

    --Load actual quarry position
    local minPos = toAbsolutePosition(quarry.homePos, {-5.5 * quarry.dir, -5.5})
    local maxPos = toAbsolutePosition(quarry.homePos, {(quarry.width + 5.5) * quarry.dir, 5.5})

    local poly = {
        minPos, {minPos[1], maxPos[2]}, 
        maxPos, {maxPos[1], minPos[2]}
    }
    world.debugPoly(poly, "red")

    world.loadRegion({minPos[1], minPos[2], maxPos[1], maxPos[2]})
end

function loadQuarryRegions(dt, quarry)
    if quarry.loadTimer > quarry.loadInterval then
        loadRegions(quarry)
        quarry.loadTimer = 0
    end

    quarry.loadTimer = quarry.loadTimer + dt
end


function spawnQuarry(quarry, pos)
    quarry.id = nil
    pos = pos or quarry.headPos

    if pos then
        quarry.id = world.spawnMonster("squarry", pos)
        if quarry.id then
            quarry.justspawned = true
        end
    end

    return quarry.id
end

function respawnQuarry(quarry, pos)
    killQuarry(quarry)
    return spawnQuarry(quarry, pos)
end

function killQuarry(quarry)
    if quarry.id then
        sfutil.safe_await(world.sendEntityMessage(quarry.id, "damage"))
        quarry.id = nil
    end
end

--- Move quarry toward desired position (specified by it's distance)
-- @return booliean - Return true if the quarry was moved.
function moveQuarry(quarry, distance)
    if not inPosition(distance, 0.04) then -- if distance is further than
        local chainlength = (quarry.homePos[2] - quarry.headPos[2]) * 8 + 2 -- compute chain length
        local push = config.getParameter("push")
        local max = config.getParameter("maxSpeed")

        if distance[1] > 0.04 then
            distance[1] = math.min(distance[1]+push[1], max[1])
        elseif distance[1] < -0.04 then
            distance[1] = math.max(distance[1]-push[1], -max[1])
        end

        if distance[2] > 0.04 then
            chainlength = chainlength - 2
            distance[2] = math.min(distance[2]+push[2], max[2])
        elseif distance[2] < -0.04 then
            distance[2] = math.max(distance[2]-push[2], -max[2])
        end

        sfutil.safe_await(world.sendEntityMessage(quarry.id, "move", {velocity = distance, chain = chainlength}))

        return true
    end

    return false
end

function sendItem()
    if next(pipes.nodeEntities) ~= nil and storageApi.getCount() > 0 then
        for i,item in storageApi.getIterator() do
            local canPush = peekPushItem(1, item)

            if canPush then
                local pushed = pushItem(1, canPush[1])

                if pushed and pushed[2].count >= item.count then
                    storageApi.returnItem(i)
                elseif pushed then
                    item.count = item.count - pushed[2].count
                end
            end
        end
    end

    if storageApi.getCount() == 0 and storage.quarry.run ~= nil then
        storage.quarry.active = storage.quarry.run -- If the quarry was running, restart if empty.
    end
end

function drawChain(quarry)
    local chainlength = (quarry.homePos[2] - quarry.headPos[2]) * 8 + 2 -- compute chain length
    local xtrans = (quarry.homePos[1] - quarry.headPos[1])

    animator.resetTransformationGroup("chain")
    animator.transformTransformationGroup("chain", 1, 0, 0, chainlength, -object.direction() * (xtrans + (-object.direction()) * 2.75), 1.5 - chainlength / 8)
end


function updateAnimationState()
    if storage.quarry and storage.quarry.homePos and storage.quarry.headPos then
        drawChain(storage.quarry)
    end

    if energy.getEnergy() > 1 then
        if storage.quarry.run and storage.quarry.active then
            animator.setAnimationState("quarryState", "run")
        elseif storage.quarry.returnPosition then
            animator.setAnimationState("quarryState", "return")
        elseif storageApi.getCount() > 0 then
            animator.setAnimationState("quarryState", "items")
        else
            animator.setAnimationState("quarryState", "idle")
        end
    else
        animator.setAnimationState("quarryState", "energy")
    end
end

function toAbsolutePosition(pos, vec)
    return {vec[1] + pos[1], vec[2] + pos[2]}
end

function inPosition(distance, marge)
    marge = marge or 0.01
    if math.abs(distance[1]) > marge or math.abs(distance[2]) > marge then
        return false
    end
    return true
end

function onNodeConnectionChange(args)
    updateAnimationState()
end

function onInputNodeChange(args)
    onInteraction({}, args.level)
end

function isActive()
    return storage.quarry.active and storage.quarry.run and not storage.quarry.returnPosition
end

function isHome(quarry) 
    if not quarry.headPos or not quarry.homePos then
        return false
    end

    local distance = world.distance(quarry.headPos, quarry.homePos)

    return inPosition(distance, 0.04)
end

function die()
    energy.die()
    if storage.quarry then
        killQuarry(storage.quarry)
        if storage.quarry.standPos then
            if storage.quarry.quarryHolders then
                if storage.quarry.width then
                    destroyQuarryHolders(storage.quarry.standPos, 
                    storage.quarry.width + 1, 
                    object.direction())
                else
                    destroyQuarryHolders(storage.quarry.standPos,
                    stored.quarry.range + 3,
                    object.direction())
                end
                storage.quarry.quarryHolders = false
            end
            world.damageTiles({storage.quarry.standPos}, "foreground", storage.quarry.standPos, "plantish", 22000)
        end
    end

    storageApi.dropAll()
end
