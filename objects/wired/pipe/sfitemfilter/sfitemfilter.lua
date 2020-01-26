function init()
    pipes.init({itemPipe})

    self.connectionMap = {}
    self.connectionMap[1] = 2
    self.connectionMap[2] = 1
    self.connectionMap[3] = 4
    self.connectionMap[4] = 3

    buildFilter()
end

--------------------------------------------------------------------------------
function update(dt)
    buildFilter()
    pipes.update(dt)
end

function showPass()
    animator.setAnimationState("filterState", "pass")
end

function showFail()
    animator.setAnimationState("filterState", "fail")
end

function beforeItemPut(item, nodeId)
    if self.filterCount > 0 then
        if self.filter[item.name] then
            return peekPushItem(self.connectionMap[nodeId], item)
        end
    end

    return nil
end

function onItemPut(item, nodeId)
    local pushResult = nil

    if self.filterCount > 0 then
        if self.filter[item.name] then
            local peek = peekPushItem(self.connectionMap[nodeId], item)

            if peek then
                pushResult = pushItem(self.connectionMap[nodeId], peek[1])
            end
        end
    end

    if pushResult then
        showPass()

        return pushResult[2]
    else
        showFail()
    end

    return pushResult
end

function beforeItemGet(filter, nodeId)
    if self.filterCount > 0 then
        local pullFilter = {}
        local filterMatch = false
        for filterString, amount in pairs(filter) do
            if self.filter[filterString] then
                pullFilter[filterString] = amount
                filterMatch = true
            end
        end

        if filterMatch then
            return peekPullItem(self.connectionMap[nodeId], pullFilter)
        end
    end

    return false
end

function onItemGet(filter, nodeId)
    local pullResult = nil

    if self.filterCount > 0 then
        local pullFilter = {}
        local filterMatch = false
        for filterString, amount in pairs(filter) do
            if self.filter[filterString] then
                pullFilter[filterString] = amount
                filterMatch = true
            end
        end

        if filterMatch then
            local peek = peekPushItem(self.connectionMap[nodeId], pullFilter)

            if peek then
                pullResult = pullItem(self.connectionMap[nodeId], peek[1])
            end
        end
    end

    if pullResult then
        showPass()

        return pullResult[2]
    else
        showFail()
    end

    return pullResult
end

function buildFilter()
    self.filter = {}
    self.filterCount = 0
    local contents = world.containerItems(entity.id())
    if contents then
        for key, item in pairs(contents) do
            if self.filter[item.name] then
                self.filter[item.name] = math.min(self.filter[item.name], item.count)
            else
                self.filter[item.name] = item.count
                self.filterCount = self.filterCount + 1
            end
        end
    end

    if self.filterCount > 0 and animator.animationState("filterState") == "off" then
        animator.setAnimationState("filterState", "on")
    elseif self.filterCount <= 0 then
        animator.setAnimationState("filterState", "off")
    end
end
