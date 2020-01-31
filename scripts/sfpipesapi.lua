require '/scripts/sfutil.lua'

--HOOKS

--- Hook used for determining if an object connects to a specified position
-- @param pipeName string - name of the pipe type to push through
-- @param position vec2 - world position to compare node positions to
-- @param pipeDirection vec2 - direction of the pipe to see if the object connects
-- @returns node ID if successful, false if unsuccessful
function entityConnectsAt(_, _, pipeName, position, pipeDirection)
    if pipes == nil or pipes.nodes[pipeName] == nil then
        return false 
    end

    local entityPos = entity.position()

    for i,node in ipairs(pipes.nodes[pipeName]) do
        local absNodePos = object.toAbsolutePosition(node.offset)
        local absNodePosOff = { absNodePos[1] + pipeDirection[1], absNodePos[2] + pipeDirection[2] }
        local distance = world.distance(position, absNodePos)
        local distanceOff = world.distance(position, absNodePosOff)

        if distance[1] == 0 and distance[2] == 0 and pipeDirection[1] == -1 * node.dir[1] and pipeDirection[2] == -1 * node.dir[2] then
            return i
        end
    end
    return false
end

--HELPERS

--- Checks if a table (array only) contains a value
-- @param table table - table to check
-- @param value (w/e) - value to compare
-- @returns true if table contains it, false if not
function table.contains(table, value)
    for _,val in ipairs(table) do
        if value == val then return true end
    end
    return false
end

--- Copies a table (not recursive)
-- @param table table - table to copy
-- @returns copied table
function table.copy(table)
    local newTable = {}
    for i,v in pairs(table) do
        newTable[i] = v
    end
    return newTable
end

--PIPES
pipes = {}

--- Initialize, always run this in init (when init args == false)
-- @param pipeTypes an array of pipe types (defined in sfitempipes.lua and sfliquidpipes.lua)
-- @returns nil
function pipes.init(pipeTypes)
    message.setHandler("entityConnectsAt", entityConnectsAt)

    pipes.updateTimer = 1 --Should be set to the same as updateInterval so it gets entities on the first update
    pipes.updateInterval = 1

    pipes.types = {}
    pipes.nodes = {} 
    pipes.nodeEntities = {}

    for _,pipeType in ipairs(pipeTypes) do
        pipes.types[pipeType.pipeName] = pipeType
    end

    -- Setup Nodes
    for pipeName,pipeType in pairs(pipes.types) do
        pipes.nodes[pipeName] = config.getParameter(pipeType.nodesConfigParameter)
        pipes.nodeEntities[pipeName] = {}

        if pipes.nodes[pipeName] ~= nil then
            local nodeList = {}

            for offset,node in ipairs(pipes.nodes[pipeName]) do
                nodeList[offset] = { node.offset, "sfinvisipipe" }
            end

            object.setMaterialSpaces(nodeList)
        end
    end

    pipes.rejectNode = {}

    for _,pipeType in ipairs(pipeTypes) do
        for name, hook in pairs(pipeType.hooks) do
            message.setHandler(hook, pipeType.msgHooks[name])
        end
    end
end

--- Push, calls the push hook on all connected object that returns true
-- @param pipeName string - name of the pipe type to push through
-- @param nodeId number - ID of the node to push through
-- @param args - The arguments to send to the push hook
-- @returns Hooks return if successful, false if unsuccessful
function pipes.push(pipeName, nodeId, args)
    if #pipes.nodeEntities[pipeName][nodeId] > 0 and not pipes.rejectNode[nodeId] then
        local ret = {}

        pipes.rejectNode[nodeId] = true
        for i,entity in ipairs(pipes.nodeEntities[pipeName][nodeId]) do
            local pEntityReturn = sfutil.safe_await(world.sendEntityMessage(entity.id, pipes.types[pipeName].hooks.push, args[i], entity.nodeId))

            if pEntityReturn:succeeded() then --return pEntityReturn:result() end
                local res = pEntityReturn:result()

                if res then
                    res.dist = #entity.path
                end

                ret[i] = res
            end
        end
        pipes.rejectNode[nodeId] = false

        return ret
    end
    return {}
end

--- Pull, calls the pull hook on connected objects that returns true
-- @param pipeName string - name of the pipe type to pull through
-- @param nodeId number - ID of the node to pull through
-- @param args - An array of arguments to send to the hooks
-- @returns An array of successful hooks return
function pipes.pull(pipeName, nodeId, args)
    if #pipes.nodeEntities[pipeName][nodeId] > 0 and not pipes.rejectNode[nodeId] then
        local ret = {}

        pipes.rejectNode[nodeId] = true
        for i,entity in pairs(pipes.nodeEntities[pipeName][nodeId]) do
            local pEntityReturn = sfutil.safe_await(world.sendEntityMessage(entity.id, pipes.types[pipeName].hooks.pull, args[i], entity.nodeId))

            if pEntityReturn:succeeded() and pEntityReturn:result() then --return pEntityReturn:result() end
                local res = pEntityReturn:result()

                if res then
                    res.dist = #entity.path
                end

                ret[i] = res
            end
        end
        pipes.rejectNode[nodeId] = false

        return ret
    end
    return {}
end

--- Peek push, calls the peekPush hook on connected objects that returns true
-- @param pipeName string - name of the pipe type to peek through
-- @param nodeId number - ID of the node to peek through
-- @param args - The arguments to send to the hook
-- @returns An array of successful hooks return
function pipes.peekPush(pipeName, nodeId, args)
    if #pipes.nodeEntities[pipeName][nodeId] > 0 and not pipes.rejectNode[nodeId] then
        local ret = {}

        pipes.rejectNode[nodeId] = true
        for i,entity in pairs(pipes.nodeEntities[pipeName][nodeId]) do
            local pEntityReturn = sfutil.safe_await(world.sendEntityMessage(entity.id, pipes.types[pipeName].hooks.peekPush, args, entity.nodeId))

            if pEntityReturn:succeeded() then --return pEntityReturn:result() end
                local res = pEntityReturn:result()

                if res then
                    res.dist = #entity.path
                end

                ret[i] = res
            end
        end
        pipes.rejectNode[nodeId] = false

        return ret
    end
    return {}
end

--- Peek pull, calls the peekPull hook on the closest connected object that returns true
-- @param pipeName string - name of the pipe type to peek through
-- @param nodeId number - ID of the node to peek through
-- @param args - The arguments to send to the hook
-- @returns Hook return if successful, false if unsuccessful
function pipes.peekPull(pipeName, nodeId, args)
    if #pipes.nodeEntities[pipeName][nodeId] > 0 and not pipes.rejectNode[nodeId] then
        local ret = {}

        for i,entity in pairs(pipes.nodeEntities[pipeName][nodeId]) do
            pipes.rejectNode[nodeId] = true
            local pEntityReturn = sfutil.safe_await(world.sendEntityMessage(entity.id, pipes.types[pipeName].hooks.peekPull, args, entity.nodeId))
            pipes.rejectNode[nodeId] = false

            if pEntityReturn:succeeded() then --return pEntityReturn:result() end
                local res = pEntityReturn:result()
                --sb.logInfo("Can Pull %s", res)

                if res then
                    res.dist = #entity.path
                end

                ret[i] = res
            end
        end

        return ret
    end

    return {}
end

--- Checks if two pipes connect up, direction-wise
-- @param firstDirection vec2 - vector2 of direction to match
-- @param secondDirections array of vec2s - List of directions to match against
-- @returns true if the secondDirections can connect to the firstDirection
function pipes.pipesConnect(firstDirection, secondDirections)
    for _,secondDirection in ipairs(secondDirections) do
        if firstDirection[1] == -secondDirection[1] and firstDirection[2] == -secondDirection[2] then
            return true
        end
    end
    return false
end

--- Gets the directions of a tile based on tile name
-- @param pipeName string - name of the pipe type to use
-- @param position vec2 - world position to check
-- @param layer - layer to check ("foreground" or "background")
-- @returns Hook return if successful, false if unsuccessful
function pipes.tileDirections(pipeName, position, layer)
    local checkedTile = world.material(position, layer)

    for _,tileType in ipairs(pipes.types[pipeName].tiles) do
        if checkedTile == tileType then
            return {
                {1, 0}, 
                {-1, 0},
                {0, 1},
                {0, -1}
            }
        end
    end
    return false
end

--- Gets the directions + layer for a connecting pipe, prioritises the layer specified in layerMode
-- @param pipeName string - name of the pipe type to use
-- @param position vec2 - world position to check
-- @param layerMode - layer to prioritise
-- @param direction (optional) - direction to compare to, if specified it will return false if the pipe does not connect
-- @returns Hook return if successful, false if unsuccessful
function pipes.getPipeTileData(pipeName, position, layerMode, direction)
    local layerSwitch = {foreground = "background", background = "foreground"}

    layerMode = layerMode or "foreground"

    local firstCheck = pipes.tileDirections(pipeName, position, layerMode)
    local secondCheck = pipes.tileDirections(pipeName, position, layerSwitch[layerMode])

    --Return relevant values
    if firstCheck and (direction == nil or pipes.pipesConnect(direction, firstCheck)) then
        return firstCheck, layerMode
    elseif secondCheck and (direction == nil or pipes.pipesConnect(direction, secondCheck)) then
        return secondCheck, layerSwitch[layerMode]
    end
    return false
end

--- Gets all the connected entities for a pipe type
-- @param pipeName string - name of the pipe type to use
-- @returns list of connected entities with format {nodeId = {{id = 1, nodeId = 1, path = {{1,0},{2,0}}}}
function pipes.getNodeEntities(pipeName)
    local position = entity.position()
    local nodeEntities = {}
    local nodesTable = {}

    if pipes.nodes[pipeName] == nil then return {} end

    for i,pipeNode in ipairs(pipes.nodes[pipeName]) do
        nodeEntities[i] = pipes.walkPipes(pipeName, pipeNode.offset, pipeNode.dir)
    end

    return nodeEntities

end

--- Should be run in main
-- @param dt number - delta time
-- @returns nil
function pipes.update(dt)
    local position = entity.position()
    pipes.updateTimer = pipes.updateTimer + dt

    if pipes.updateTimer >= pipes.updateInterval then
        --Get connected entities
        for pipeName,pipeType in pairs(pipes.types) do
            --Get Input
            pipes.nodeEntities[pipeName] = pipes.getNodeEntities(pipeName)
        end

        pipes.updateTimer = 0
    end
end

--- Calls a hook on the entity to see if it connects to the specified pipe
-- @param pipeName string - name of pipe type to use
-- @param entityId number - ID of entity to check against
-- @param position vec2 - position of the pipe tile
-- @param direction vec2 - direction of the pipe tile
-- @returns nil
function pipes.validEntity(pipeName, entityId, position, direction)
    local promise = sfutil.safe_await(world.sendEntityMessage(entityId, "entityConnectsAt", pipeName, position, direction))

    if promise:succeeded() then
        return promise:result()
    else
        return nil
    end
end

--- Walks through placed pipe tiles to find connected entities
-- @param pipeName string - name of pipe type to use
-- @param startOffset vec2 - Position *relative to the object* to start looking, should be set to a node's position
-- @param startDir vec2 - Direction to start looking in, should be set to a node's direction
-- @returns List of connected entities with ID, remote Node ID, and path info, sorted by nearest-first
function pipes.walkPipes(pipeName, startOffset, startDir)
    local validEntities = {}
    local visitedTiles = {}
    local tilesToVisit = {{pos = {startOffset[1] + startDir[1], startOffset[2] + startDir[2]}, layer = "foreground", dir = startDir, path = {}}}
    local layerMode = nil

    while #tilesToVisit > 0 do
        local tile = tilesToVisit[1]
        local pipeDirections, layerMode = pipes.getPipeTileData(pipeName, object.toAbsolutePosition(tile.pos), tile.layer)

        --sb.logInfo("walking pipedir %s", sb.print(pipeDirections))
        --If a tile, add connected spaces to the visit list
        if pipeDirections then
            tile.path[#tile.path+1] = tile.pos --Add tile to the path
            visitedTiles[tile.pos[1].."."..tile.pos[2]] = true --Add to global visited

            for _,dir in ipairs(pipeDirections) do
                local newPos = {tile.pos[1] + dir[1], tile.pos[2] + dir[2]}
                if visitedTiles[newPos[1].."."..newPos[2]] == nil then --Don't check the tile we just came from, and don't check already visited ones
                    local newTile = {pos = newPos, layer = layerMode, dir = dir, path = table.copy(tile.path)}
                    table.insert(tilesToVisit, 2, newTile)
                end
            end
        end
        --If not a tile, check for objects that might connect
        if not pipeDirections or layerMode == "background" then
            --local connectedObjects = world.objectQuery(object.toAbsolutePosition(tile.pos), 2)
            local absTilePos = object.toAbsolutePosition(tile.pos)
            local connectedObjects = world.entityLineQuery(absTilePos, {absTilePos[1] + 1, absTilePos[2] + 2})

            if connectedObjects then
                for key,objectId in ipairs(connectedObjects) do
                    local entNode = pipes.validEntity(pipeName, objectId, object.toAbsolutePosition(tile.pos), tile.dir)
                    if objectId ~= entity.id() and entNode and table.contains(validEntities, objectId) == false then
                        validEntities[#validEntities+1] = {id = objectId, nodeId = entNode, path = table.copy(tile.path)}
                    end
                end
            end
        end
        table.remove(tilesToVisit, 1)
    end

    table.sort(validEntities, function(a,b) return #a.path < #b.path end)
    return validEntities
end

function pipes.buildDistMap(resources)
    local min = resources[1].dist
    local max = resources[#resources].dist
    local delta = max - min
    local map = {}
    local percent = 1

    if delta ~= 0 then
        for i, r in pairs(resources) do
            if r.count > 0 then
                local dist = r.dist
                local percent = 0.5

                if i == #resources then
                    percent = 1
                end

                if not map[dist] then
                    map[dist] = { percent, 1 }
                else
                    map[dist][2] = map[dist][2] + 1
                end
            end
        end
    else
        map[max] = { 1, #resources }
    end

    return map
end

function pipes.sumUpResources(resources, resource)
    local ret = nil

    if resource then
        ret = {name = resource.name, count = 0}
    end

    if resources ~= nil then
        for _, r in pairs(resources) do
            if r ~= nil and ret == nil then
                ret = r
            elseif r ~= nil and ret.name == r.name then
                ret.count = ret.count + r.count
            end
        end
    end

    return ret
end

--- Load balance a given retources between all results
-- @param threshold - The amount to be distributed.
-- @param resources - An array of max amount of the resource (in the format {resourceId, amount, distance})
-- @param atoms - If true, the resource is considered atomic (thus only integer amount can be passed).
-- @return An array similar to resources, but balanced between all requests.
function pipes.balanceLoadResources(threshold, resources, atoms)
    local ret = {}

    if resources and #resources > 0 then
        local amount = threshold
        local distMap = pipes.buildDistMap(resources)
        local count = 0

        for i, r in pairs(resources) do
            local percent = 0
            local dist = r.dist

            if not distMap[dist][3] then
                percent = (distMap[dist][1] / distMap[dist][2])
                distMap[dist][3] = amount * percent

                if atoms then
                    distMap[dist][3] = math.ceil(amount * percent)
                end

                count = 1
            else
                count = count + 1
            end

            local avail = distMap[dist][3]

            if avail > amount then
                r.count = math.min(amount, r.count)
            else
                r.count = math.min(avail, r.count)
            end

            ret[i] = r
            amount = amount - r.count
        end
    end

    return ret
end

