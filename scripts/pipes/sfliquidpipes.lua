require '/scripts/sfutil.lua'

liquidPipe = {
    pipeName = "liquid",
    nodesConfigParameter = "liquidNodes",
    flippedNodesConfigParameter = "flippedLiquidNodes",
    tiles = {"metalpipe", "sewerpipe", "sfcleanpipe"},
    hooks = {
        push = "onLiquidPush",
        pull = "onLiquidPull",
        peekPush = "beforeLiquidPush",
        peekPull = "beforeLiquidPull"
    },
    msgHooks = {
    }
}

--- Hook called when an entity is trying to push some liquids
-- As entities are always connected by pipe, the first two argument of the message handler are ignored.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param liquid The liquid that the remote entity is trying to push
-- @param nodeId The node id of the entity.
function liquidPipe.msgHooks.push(_, _, liquid, nodeId)
    if onLiquidPush and liquid then
        return onLiquidPush(liquid, nodeId)
    end
    return nil
end

--- Hook called when an entity is trying to push some liquids, without proceeding to the actual transfer
-- As entities are always connected by pipe, the first two argument of the message handler are ignored.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param liquid The liquid that the remote entity is trying to push
-- @param nodeId The node id of the entity.
function liquidPipe.msgHooks.peekPush(_, _, liquid, nodeId)
    if beforeLiquidPush and liquid then
        return beforeLiquidPush(liquid, nodeId)
    end
    return nil
end

--- Hook called when an entity is trying to pull some liquids
-- As entities are always connected by pipe, the first two argument of the message handler are ignored.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param filter Some parameter to filter out unacceptable liquid. Nil will accept everything.
-- @param nodeId The node id of the entity.
function liquidPipe.msgHooks.pull(_, _, liquid, nodeId)
    if onLiquidPull then
        return onLiquidPull(liquid, nodeId)
    end
    return nil
end

--- Hook called when an entity is trying to pull some liquids, without proceeding to the actual transfer
-- As entities are always connected by pipe, the first two argument of the message handler are ignored.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param filter Some parameter to filter out unacceptable liquid. Nil will accept everything.
-- @param nodeId The node id of the entity.
function liquidPipe.msgHooks.peekPull(_, _, filters, nodeId)
    if beforeLiquidPull then
        return beforeLiquidPull(filters, nodeId)
    end
    return nil
end

--- Pushes liquids
-- @param nodeId the node to push from
-- @param liquids - An array of liquids to push, specified as array {liquidId, amount}
-- @returns And array of results if successful, an empty array otherwise
function pushLiquid(nodeId, liquids)
    local res = pipes.push("liquid", nodeId, liquids)

    if res and next(res) then
        return {res, pipes.sumUpResources(res)}
    end

    return nil
end

--- Pulls liquid
-- @param nodeId the node to push from
-- @param filter array of filters of liquids {liquidId = {minAmount,maxAmount}, otherLiquidId = {minAmount,maxAmount}}
-- @returns An array of liquids, if successful, an empty array otherwise
function pullLiquid(nodeId, liquids)
    local res = pipes.pull("liquid", nodeId, liquids)

    if res and next(res) then
        return {res, pipes.sumUpResources(res)}
    end

    return nil
end

--- Peeks a liquid push, does not go through with the transfer
-- @param nodeId the node to push from
-- @param liquid the liquid to push, specified as array {liquidId, amount}
-- @returns An array filled with liquids accepted by each entities.
function peekPushLiquid(nodeId, liquid)
    local res = pipes.balanceLoadResources(liquid.count, pipes.peekPush("liquid", nodeId, liquid))

    if res and next(res) then
        return {res, pipes.sumUpResources(res, liquid)}
    end

    return nil
end

--- Peeks a liquid pull, does not go through with the transfer
-- @param nodeId the node to push from
-- @param filter array of filters of liquids in the form {{ liquid = liquid, amount = {minAmount,maxAmount} }, {liquid = liquid, amount = { minAmount,maxAmount }}}
-- @returns An array liquid available for each entities if successful
function peekPullLiquid(nodeId, filter)
    local res = pipes.peekPull("liquid", nodeId, filter)

    if res and next(res) then
        local sum = pipes.sumUpResources(res)
        local balanced = pipes.balanceLoadResources(sum.count, res, false, sum)
        return {balanced, pipes.sumUpResources(balanced, sum)} -- because summing the balancing can lead to some liquids not being used
    end
    return nil
end

function isLiquidNodeConnected(nodeId)
    if pipes.nodeEntities["liquid"] == nil or pipes.nodeEntities["liquid"][nodeId] == nil then return false end
    if #pipes.nodeEntities["liquid"][nodeId] > 0 then
        return pipes.nodeEntities["liquid"][nodeId]
    else
        return false
    end
end

--- Filter a list of liquids, and return the first matching.
-- @param filters -- a list of filters in which each element is { liquid = liquid, amount = {min, max} }
-- @param liquids -- a list of liquids to be filtered.
-- @returns The first matching liquid.
function filterLiquids(filters, liquids)
    local ret = nil

    if filters then
        for _, filter in pairs(filters) do
            local filtLiquid = filter.liquid
            local amount = filter.amount

            if not filtLiquid then
                ret = liquids[1], 1
                break
            else
                for i, liquid in pairs(liquids) do
                    if filtLiquid.name == liquid.name and 
                        liquid.count >= amount[1] then
                        liquid.count = math.min(liquid.count, amount[2])

                        if liquid.count > 0 then
                            return liquid, i
                        end
                    end
                end
            end
        end
    else
        ret = liquids[1], 1
    end

    return ret
end
