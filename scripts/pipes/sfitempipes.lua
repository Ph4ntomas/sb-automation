itemPipe = {
    pipeName = "item",
    nodesConfigParameter = "itemNodes",
    flippedNodesConfigParameter = "flippedItemNodes",
    tiles = {"metalpipe", "sewerpipe", "sfcleanpipe"},
    hooks = {
        push = "onItemPush", --Should take whatever argument pull returns
        pull = "onItemPull", --Should return whatever argument you want to plug into the push hook, can take whatever argument you want like a filter or something
        peekPush = "beforeItemPush", --Should return true if object will push the item
        peekPull = "beforeItemPull" --Should return true if object will pull the item
    },
    msgHooks = {
    }
}

--- Hook called when an entity is trying to push some items
-- As entities are always connected by pipe, the first two argument of the message handler are ignored.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param item The item that the remote entity is trying to push
-- @param nodeId The node id of the entity.
function itemPipe.msgHooks.push(_, _, item, nodeId)
    if onItemPush then
        return onItemPush(item, nodeId)
    end
end

--- Hook called when an entity is trying to push some items, without proceeding to the actual transfer
-- As entities are always connected by pipe, the first two argument of the message handler are ignored.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param item The item that the remote entity is trying to push
-- @param nodeId The node id of the entity.
function itemPipe.msgHooks.peekPush(_, _, item, nodeId)
    if beforeItemPush then
        return beforeItemPush(item, nodeId)
    end
    return false
end

--- Hook called when an entity is trying to pull some items
-- As entities are always connected by pipe, the first two argument of the message handler are ignored.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param filter Some parameter to filter out unacceptable item. Nil will accept everything.
-- @param nodeId The node id of the entity.
function itemPipe.msgHooks.pull(_, _, filter, nodeId)
    if onItemPull then
        return onItemPull(filter, nodeId)
    end
end

--- Hook called when an entity is trying to pull some items, without proceeding to the actual transfer
-- As entities are always connected by pipe, the first two argument of the message handler are ignored.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param _ [Ignored] Message handler params. Irrelevent here.
-- @param filter Some parameter to filter out unacceptable item. Nil will accept everything.
-- @param nodeId The node id of the entity.
function itemPipe.msgHooks.peekPull(_, _, filter, nodeId)
    if beforeItemPull then
        return beforeItemPull(filter, nodeId)
    end
    return false
end

--- Pushes item to another object
-- @param nodeId the node to push from
-- @param item the item to push, specified as map {name = "itemname", count = 1, parameters = {}}
-- @returns true if whole stack was pushed, number amount of items taken if stack was partly taken, false/nil if fail
function pushItem(nodeId, item)
    local res = pipes.push("item", nodeId, item)

    if res and #res ~= 0 then
        return {res, pipes.sumUpResources(res)}
    end

    return nil
end

--- Pulls item from another object
-- @param nodeId the node to pull to
-- @param filter an array of filters to specify what items to return and how many {itemname = {minAmount,maxAmount}, otherItem = {minAmount,maxAmount}}
-- @returns item if successful, false/nil if unsuccessful
function pullItem(nodeId, filter)
    local res = pipes.pull("item", nodeId, filter)

    if res and #res ~= 0 then
        return {res, pipes.sumUpResources(res)}
    end

    return nil
end

--- Peeks an item push, does not perform the push
-- @param nodeId the node to push from to
-- @param item the item to push, specified as map {name = "itemname", count = 1, parameters = {}}
-- @returns true if the item can be pushed, false if item cannot be pushed
function peekPushItem(nodeId, item)
    local res = pipes.peekPush("item", nodeId, item)

    if res and #res ~= 0 then
        return {res, pipes.sumUpResources(res, item)}
    end

    return nil
end

--- Peeks an item pull, does not perform the pull
-- @param nodeId the node to pull to
-- @param filter an array of filters to specify what items to return and how many {{itemname = {minAmount,maxAmount}}, {otherItem = {minAmount,maxAmount}}}
-- @returns item if successful, false/nil if unsuccessful
function peekPullItem(nodeId, filter)
    local res = pipes.peekPull("item", nodeId, filter)

    if res and #res ~= 0 then
        return {res, pipes.sumUpResources(res, item)}
    end

    return nil
end

function isItemNodeConnected(nodeId)
    if pipes.nodeEntities["item"] == nil or pipes.nodeEntities["item"][nodeId] == nil then return false end
    if #pipes.nodeEntities["item"][nodeId] > 0 then
        return pipes.nodeEntities["item"][nodeId]
    else
        return false
    end
end

function filterItems(filter, items)
    if filter then
        for i,item in ipairs(items) do
            if filter[item.name] and item.count >= filter[item.name][1]then
                if item.count <= filter[item.name][2] then
                    return item, i
                else
                    return {name = item.name, count = filter[item.name][2], parameters = item.parameters}, i
                end
            end
        end
    else
        return items[1], 1
    end
end
