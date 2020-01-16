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
    return false
end

function liquidPipe.msgHooks.peekPut(_, _, liquid, nodeId)
    if beforeLiquidPut then
        return beforeLiquidPut(liquid, nodeId)
    end
    return false
end

function liquidPipe.msgHooks.get(_, _, filter, nodeId)
    if onLiquidGet then
        return onLiquidGet(filter, nodeId)
    end
    return false
end

function liquidPipe.msgHooks.peekGet(_, _, filter, nodeId)
    if beforeLiquidGet then
        return beforeLiquidGet(filter, nodeId)
    end
    return false
end

--- Pushes liquid
-- @param nodeId the node to push from
-- @param liquids - An array of liquids to push, specified as array {liquidId, amount}
-- @returns And array of results if successful, an empty array otherwise
function pushLiquid(nodeId, liquids)
  return pipes.push("liquid", nodeId, liquids)
end

--- Pulls liquid
-- @param nodeId the node to push from
-- @param filter array of filters of liquids {liquidId = {minAmount,maxAmount}, otherLiquidId = {minAmount,maxAmount}}
-- @returns An array of liquids, if successful, an empty array otherwise
function pullLiquid(nodeId, filters)
  return pipes.pull("liquid", nodeId, filters)
end

--- Peeks a liquid push, does not go through with the transfer
-- @param nodeId the node to push from
-- @param liquid the liquid to push, specified as array {liquidId, amount}
-- @returns An array filled with liquids accepted by each entities.
function peekPushLiquid(nodeId, liquid)
  return pipes.peekPush("liquid", nodeId, liquid)
end

--- Peeks a liquid pull, does not go through with the transfer
-- @param nodeId the node to push from
-- @param filter array of filters of liquids {liquidId = {minAmount,maxAmount}, otherLiquidId = {minAmount,maxAmount}}
-- @returns An array liquid available for each entities if successful
function peekPullLiquid(nodeId, filter)
  return pipes.peekPull("liquid", nodeId, filter)
end

--- Build a map containing the total amount of liquid to send at a certain distance, as well as the number of liquid to be sent.
function buildDistMap(liquids)
    local min = liquids[1][3]
    local max = liquids[#liquids][3]
    local delta = (max - min) / max
    local map = {}
    local percent = 1

    if delta then
        for i, l in pairs(liquids) do
            if l[2] > 0 then
                local dist = l[3]

                if not filter[dist] then
                    filter[dist] = { 1 - ((l[3] - min) / (delta)), 1 }
                else
                    filter[dist][2] = filter[dist][2] + 1
                end
            end
        end
    else
        map[max] = { 1, #liquids }
    end

    return map
end

--- Load balance a given liquid between all request
-- @param threshold - The liquid to be distributed in the format {liquidId, amount}
-- @param liquids - An array of max amount of liquids (in the format {liquidId, amount, distance})
-- @return An array similar to liquids, but with the proper amount of each liquid
function balanceLoadLiquid(threshold, liquids)
    if threshold ~= nil and liquids and #liquids > 0 then
        local maxAmount = 0
        local ret = {}
        local filter = {}


        for i, l in pairs(liquids) do
            maxAmount = maxAmount + l[2]
        end

        if maxAmount > threshold[2] then
            local percent = {}
            local amount = threshold[2]

            for i, l in pairs(liquids) do
                local percent = l[2] / maxAmount
                local dist = l[3]

                if filter[dist] then
                    percent = (percent + (dist[1] / dist[2])) / 2
                end
                
                local avail = amount * percent

                if l[2] < avail then
                    amount = amount - l[2]
                else
                    l[2] = avail
                    amount = amount - avail
                end

                ret[i] = l
            end

            return ret
        else
            return liquids
        end
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
  if filter then
    for i,liquid in ipairs(liquids) do
      local liquidId = tostring(liquid[1])
      if filter[liquidId] and liquid[2] > filter[liquidId][1]then
        if liquid[2] <= filter[liquidId][2] then
          return liquid, i
        else
          return {liquid[1], filter[liquidId][2]}, i
        end
      end
    end

    return nil, 0
  else
    return liquids[1], 1
  end
end
