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

    return {res, sumUpLiquid(res)}
end

--- Pulls liquid
-- @param nodeId the node to push from
-- @param filter array of filters of liquids {liquidId = {minAmount,maxAmount}, otherLiquidId = {minAmount,maxAmount}}
-- @returns An array of liquids, if successful, an empty array otherwise
function pullLiquid(nodeId, filters)
    local liquid = nil
    local res = pipes.pull("liquid", nodeId, filters)
    sb.logInfo("res = %s", res)

    return {res, sumUpLiquid(res)}
end

--- Peeks a liquid push, does not go through with the transfer
-- @param nodeId the node to push from
-- @param liquid the liquid to push, specified as array {liquidId, amount}
-- @returns An array filled with liquids accepted by each entities.
function peekPushLiquid(nodeId, liquid)
    local res = balanceLoadLiquid(liquid[2], pipes.peekPush("liquid", nodeId, liquid))

    if res then
        return {res, sumUpLiquid(res, liquid)}
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

    sb.logInfo("filter = %s", filter)
    if res then
        local balanced = balanceLoadLiquid(filter[2][2], res)

        return {balanced, sumUpLiquid(balanced)}
    end
    return nil
end

function sumUpLiquid(liquids, liquid)
    local ret = nil

    if liquid then
        ret = {liquid[1], 0}
    end

    if liquids ~= nil then
        for i, l in pairs(liquids) do
            if l ~= nil and ret == nil then
                ret = l
            elseif l ~= nil and ret[1] == l[1] then
                ret[2] = ret[2] + l[2]
            end
        end

        return ret
    end

    return nil
end


--- Build a map containing the total amount of liquid to send at a certain distance, as well as the number of liquid to be sent.
function buildDistMap(liquids)
    local min = liquids[1][3]
    local max = liquids[#liquids][3]
    local delta = max - min
    local map = {}
    local percent = 1

    sb.logInfo("dist delta = %s", delta)

    if delta ~= 0 then
        for i, l in pairs(liquids) do
            if l[2] > 0 then
                local dist = l[3]
                local percent = 0.5

                if i == #liquids then
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
        map[max] = { 1, #liquids }
    end

    return map
end

--- Load balance a given liquid between all request
-- @param threshold - The amount of liquid to be distributed.
-- @param liquids - An array of max amount of liquids (in the format {liquidId, amount, distance})
-- @return An array similar to liquids, but with the proper amount of each liquid
function balanceLoadLiquid(threshold, liquids)
    if liquids and #liquids > 0 then
        local ret = {}

        local percent = {}
        local amount = threshold
        local distMap = buildDistMap(liquids)
        local count = 0
        local leftover = 0

        sb.logInfo("liquids = %s", liquids)
        sb.logInfo("distmap = %s", distMap)

        for i, l in pairs(liquids) do
            local percent = 0
            local dist = l[3]

            if not distMap[dist][3] then
                percent = (distMap[dist][1] / distMap[dist][2])
                distMap[dist][3] = amount * percent
                amount = amount - (amount * distMap[dist][1])
                count = 1
                leftover = 0
            else
                count = count + 1
            end

            local avail = distMap[dist][3]

            if l[2] < avail then
                amount = amount + (avail - l[2])
            else
                l[2] = avail
            end

            ret[i] = l
        end

        return ret
    end

    return {}
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
            local liquidId = tostring(liquid[1])
            if liquidId and filter[1] == liquidId and liquid[2] > filter[1]then
                if liquid[2] <= filter[2] then
                    return liquid, i
                else
                    return {liquid[1], filter[2]}, i
                end
            end
        end

        return nil, 0
    elseif filter[1] == nil then
        local amount = filter[2]

        if amount == nil or liquids[1] <= amount then
            return liquids[1], 1
        else
            return {liquids[1][1], amount}, 1
        end
    else
        return liquids[1], 1
    end
end
