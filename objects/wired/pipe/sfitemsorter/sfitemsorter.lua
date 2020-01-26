function init()
    pipes.init({itemPipe})

    self.connectionMap = {}
    self.connectionMap[1] = {2, 3, 4}
    self.connectionMap[2] = {1, 3, 4}
    self.connectionMap[3] = {1, 2, 4}
    self.connectionMap[4] = {1, 2, 3}

    self.filtermap = {
        1, 2, 2, 3,
        1, 2, 2, 3,
        1, 4, 4, 3,
        1, 4, 4, 3
    }

    filter = {}
    filter[1] = {}
    filter[2] = {}
    filter[3] = {}
    filter[4] = {}

    self.stateMap = {"right", "up", "left", "down"}

    self.filterCount = {}

    buildFilter()
end

--------------------------------------------------------------------------------
function update(dt)
    buildFilter()
    pipes.update(dt)
end

function showPass(direction)
    animator.setAnimationState("filterState", "pass." .. direction)
end

function showFail()
    animator.setAnimationState("filterState", "fail")
end

function beforeItemPut(item, nodeId)
    for _,node in ipairs(self.connectionMap[nodeId]) do
        if self.filterCount[node] > 0 then
            if self.filter[node][item[1]] then
                local ret = peekPushItem(self.connectionMap[nodeId], item)

                if ret then return ret[2] end
            end
        end
    end

    return nil
end

function onItemPut(item, nodeId)
    local pushResult = nil
    local resultNode = 1

    for _,node in ipairs(self.connectionMap[nodeId]) do
        if self.filterCount[node] > 0 then
            if self.filter[node][item.name] then
                local peek = peekPushItem(node, item)

                if peek then
                    pushResult = pushItem(node, peek[1])
                    if pushResult then resultNode = node end
                end
            end
        end
    end

    if pushResult then
        showPass(self.stateMap[resultNode])

        return pushResult[2]
    else
        showFail()
    end

    return pushResult
end

function beforeItemGet(filter, nodeId)
    for _,node in ipairs(self.connectionMap[nodeId]) do
        if self.filterCount[node] > 0 then
            local pullFilter = {}
            local filterMatch = false
            for filterString, amount in pairs(filter) do
                if self.filter[node][filterString] then
                    pullFilter[filterString] = amount
                    filterMatch = true
                end
            end

            if filterMatch then
                local ret = peekPullItem(self.connectionMap[nodeId], pullFilter)

                if ret then return ret[2] end
            end
        end
    end

    return nil
end

function onItemGet(filter, nodeId)
    local pullResult = false
    local resultNode = 1

    for _,node in ipairs(self.connectionMap[nodeId]) do
        if self.filterCount[node] > 0 then
            local pullFilter = {}
            local filterMatch = false
            for filterString, amount in pairs(filter) do
                if self.filter[filterString] then
                    pullFilter[filterString] = amount
                    filterMatch = true
                end
            end

            if filterMatch then
                local peek = peekPullItem(self.connectionMap[nodeId], pullFilter)

                if peek then 
                    pullResult = pullItem(self.connectionMap[nodeId], peek[1])
                    if pullResult then resultNode = node end
                end
            end
        end
    end

    if pullResult then
        showPass(self.stateMap[resultNode])

        return pullResult[2]
    else
        showFail()
    end

    return pullResult
end

function buildFilter()
    self.filter = {{}, {}, {}, {}}
    self.filterCount = {0, 0, 0, 0}
    local totalCount = 0

    local contents = world.containerItems(entity.id())
    if contents then
        for key, item in pairs(contents) do
            if self.filter[self.filtermap[key]][item.name] then
                self.filter[self.filtermap[key]][item.name] = math.min(self.filter[self.filtermap[key]][item.name], item.count)
            else
                self.filter[self.filtermap[key]][item.name] = item.count
                self.filterCount[self.filtermap[key]] = self.filterCount[self.filtermap[key]] + 1
                totalCount = totalCount + 1
            end
        end
    end

    if totalCount > 0 and animator.animationState("filterState") == "off" then
        animator.setAnimationState("filterState", "on")
    elseif totalCount <= 0 then
        animator.setAnimationState("filterState", "off")
    end
end
