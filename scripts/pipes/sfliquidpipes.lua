require '/scripts/sfutil.lua'

liquidPipe = {
    pipeName = "liquid",
    nodesConfigParameter = "liquidNodes",
    tiles = {"metalpipe", "sewerpipe", "sfcleanpipe"},
    hooks = {
        put = "onLiquidPut",  --Should take whatever argument get returns
        get = "onLiquidGet", --Should return whatever argument you want to plug into the put hook, can take whatever argument you want like a filter or something
        peekPut = "beforeLiquidPut", --Should return true if object will put the item
        peekGet = "beforeLiquidGet" --Should return true if object will get the item
    },
    msgHooks = {
    }
}

function liquidPipe.msgHooks.put(_, _, liquid, nodeId)
    if onLiquidPut then
        return onLiquidPut(liquid, nodeId)
    end
    return nil
end

function liquidPipe.msgHooks.peekPut(_, _, liquid, nodeId)
    if beforeLiquidPut then
        return beforeLiquidPut(liquid, nodeId)
    end
    return nil
end

function liquidPipe.msgHooks.get(_, _, filter, nodeId)
    if onLiquidGet then
        return onLiquidGet(filter, nodeId)
    end
    return nil
end

function liquidPipe.msgHooks.peekGet(_, _, filter, nodeId)
    if beforeLiquidGet then
        return beforeLiquidGet(filter, nodeId)
    end
    return nil
end

--- Pushes liquids
-- @param nodeId the node to push from
-- @param liquids - An array of liquids to push, specified as array {liquidId, amount}
-- @returns And array of results if successful, an empty array otherwise
function pushLiquid(nodeId, liquids)
    local res = pipes.push("liquid", nodeId, liquids)

    if res and #res ~= 0 then
        return {res, pipes.sumUpResources(res)}
    end

    return nil
end

--- Pulls liquid
-- @param nodeId the node to push from
-- @param filter array of filters of liquids {liquidId = {minAmount,maxAmount}, otherLiquidId = {minAmount,maxAmount}}
-- @returns An array of liquids, if successful, an empty array otherwise
function pullLiquid(nodeId, filters)
    local res = pipes.pull("liquid", nodeId, filters)

    if res and #res ~= 0 then
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

    if res and #res ~= 0 then
        return {res, pipes.sumUpResources(res, liquid)}
    end

    return nil
end

--- Peeks a liquid pull, does not go through with the transfer
-- @param nodeId the node to push from
-- @param filter array of filters of liquids {liquidId = {minAmount,maxAmount}, otherLiquidId = {minAmount,maxAmount}}
-- @returns An array liquid available for each entities if successful
function peekPullLiquid(nodeId, filter)
    local liquid = nil
    local res = pipes.peekPull("liquid", nodeId, filter)

    if res and #res ~= 0 then
        local balanced = pipes.balanceLoadResources(filter[2][2], res)
        return {balanced, pipes.sumUpResources(balanced)}
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

function filterLiquids(filter, liquids)
    if filter and filter[1] ~= nil then
        for i,liquid in ipairs(liquids) do
            local liquidId = tostring(liquid.name)
            if liquidId and filter[1] == liquidId and liquid.count > filter[1] then
                if liquid.count <= filter[2] then
                    return liquid, i
                else
                    return {name = liquid.name, count = filter[2]}, i
                end
            end
        end

        return nil, 0
    elseif filter[1] == nil then
        local amount = filter[2]

        if amount == nil or liquids[1].count <= amount then
            return liquids[1], 1
        else
            return {name = liquids[1].name, count = amount}, 1
        end
    else
        return liquids[1], 1
    end
end
