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

    self.stateMap = {"left", "up", "right", "down"}

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

function beforeItemPush(item, nodeId)
    for _,node in pairs(self.connectionMap[nodeId]) do
        if self.filterCount[node] > 0 and self.filter[node][item.name] then
            for _,filtItem in pairs(self.filter[node][item.name]) do
                if sfutil.compare(item, filtItem, self.ignoreFields) then
                    local ret = peekPushItem(node, item)

                    if ret then return ret[2] end
                end
            end
        end
    end

    return nil
end

function onItemPush(item, nodeId)
    local pushResult = nil
    local resultNode = 1

    for _,node in ipairs(self.connectionMap[nodeId]) do
        if self.filterCount[node] > 0 and self.filter[node][item.name] then
            for _, filtItem in pairs(self.filter[node][item.name]) do
                if sfutil.compare(item, filtItem, self.ignoreFields) then
                    local peek = peekPushItem(node, item)

                    if peek then
                        pushResult = pushItem(node, peek[1])

                        if pushResult then 
                            showPass(self.stateMap[node])

                            return pushResult[2]
                        end
                    end
                end
            end
        end
    end

    showFail()
    return pushResult
end

local function mergeFilters(node, filters)
    local match = false
    local merged = {}

    if self.filterCount[node] > 0 and filters then
        for _, filter in pairs(filters) do
            local filtItem = filter.item
            if self.filter[node][filtItem.name] then
                for _, item in pairs(self.filter[node][filtItem.name]) do
                    if sfutil.compare(filtItem, item, self.ignoreFields) then
                        merged[#merged + 1] = filter
                        match = true
                        break
                    end
                end
            end
        end
    end

    return match, merged
end

function beforeItemPull(filters, nodeId)
    for _,node in ipairs(self.connectionMap[nodeId]) do
        local match, pullFilters = mergeFilters(node, filters)

        if match then
            local ret = peekPullItem(self.connectionMap[nodeId], pullFilters)

            if ret then return ret[2] end
        end
    end

    return nil
end

function onItemPull(item, nodeId)
    local pullResult = false
    local filters = {{
        item = item,
        amount = {item.count, item.count}
    }}

    for _,node in ipairs(self.connectionMap[nodeId]) do
        local match, pullFilters = mergeFilters(node, filters)

        if match then
            local peek = peekPullItem(self.connectionMap[nodeId], pullFilters)

            if peek then 
                pullResult = pullItem(self.connectionMap[nodeId], peek[1])
                if pullResult then resultNode = node end
                break
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
    self.ignoreFields = { count = true, sfdist = true }
    local totalCount = 0

    local contents = world.containerItems(entity.id())
    if contents then
        for key, item in pairs(contents) do
            self.filter[self.filtermap[key]][item.name] = self.filter[self.filtermap[key]][item.name] or {}

            local size = #self.filter[self.filtermap[key]][item.name]
            self.filter[self.filtermap[key]][item.name][size + 1] = item
            self.filterCount[self.filtermap[key]] = self.filterCount[self.filtermap[key]] + 1
            totalCount = totalCount + 1
        end
    end

    if totalCount > 0 and animator.animationState("filterState") == "off" then
        animator.setAnimationState("filterState", "on")
    elseif totalCount <= 0 then
        animator.setAnimationState("filterState", "off")
    end
end
