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

function beforeItemPush(item, nodeId)
    if self.filterCount > 0 and self.filter[item.name] then
        for _, filtItem in pairs(self.filter[item.name]) do
            if sfutil.compare(filtItem, item, self.ignoreFields) then
                local ret = peekPushItem(self.connectionMap[nodeId], item)

                if ret then return ret[2] end
            end
        end
    end

    return nil
end

function onItemPush(item, nodeId)
    local pushResult = nil

    if self.filterCount > 0 and self.filter[item.name] then
        for _, filtItem in pairs(self.filter[item.name]) do
            if sfutil.compare(filtItem, item, self.ignoreFields) then
                local peek = peekPushItem(self.connectionMap[nodeId], item)

                if peek then
                    pushResult = pushItem(self.connectionMap[nodeId], peek[1])

                    if pushResult then
                        showPass()

                        return pushResult[2]
                    end
                end
            end
        end
    end

    showFail()
    return pushResult
end

local function mergeFilters(filters)
    local filterMatch = false
    local pullFilter = {}

    if self.filterCount > 0 and filters then
        for _, filter in pairs(filters) do
            local filtItem = filter.item
            if self.filter[filtItem.name] then
                for _, item in pairs(self.filter[filtItem.name]) do
                    if sfutil.compare(filtItem, item, self.ignoreFields) then
                        pullFilter[#pullFilter + 1] = filter
                        filterMatch = true
                        break
                    end
                end
            end
        end
    end

    return filterMatch, pullFilter
end

function beforeItemPull(filters, nodeId)
    local match, pullFilters = mergeFilters(filters)

    if match then
        ret = peekPullItem(self.connectionMap[nodeId], pullFilters)

        if ret then return ret[2] end
    end

    return nil
end

function onItemPull(item, nodeId)
    local pullResult = nil
    local filters = {{
        item = item,
        amount = {item.count, item.count}
    }}

    local match, pullFilters = mergeFilters(filters)

    if match then
        local peek = peekPushItem(self.connectionMap[nodeId], pullFilters)

        if peek then
            pullResult = pullItem(self.connectionMap[nodeId], peek[1])
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
    self.ignoreFields = { count = true, sfdist = true }
    local contents = world.containerItems(entity.id())

    if contents then
        for key, item in pairs(contents) do
            self.filter[item.name] = self.filter[item.name] or {}

            local size = #self.filter[item.name]
            
            self.filter[item.name][size + 1] = item
            self.filterCount = self.filterCount + 1
        end
    end

    if self.filterCount > 0 and animator.animationState("filterState") == "off" then
        animator.setAnimationState("filterState", "on")
    elseif self.filterCount <= 0 then
        animator.setAnimationState("filterState", "off")
    end
end
