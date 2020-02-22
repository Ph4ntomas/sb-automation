function init(virtual)
    pipes.init({itemPipe}, object.direction() == -1)

    connectChest()
end

function update(dt)
    pipes.update(dt)

    connectChest()

    --Push out items if switched on
    if self.chest and object.getInputNodeLevel(0) then
        pushItems()
    end
end

function connectChest()
    self.chest = false
    local pos = object.toAbsolutePosition({object.direction(), 0})
    local searchPos = {pos[1] + 0.5, pos[2] + 0.5}
    local entityIds = world.objectLineQuery(searchPos, searchPos, { withoutEntityId = entity.id(), order = "nearest" })

    for i, entityId in ipairs(entityIds) do
        if world.containerSize(entityId) then
            self.chest = entityId
            break
        end
    end
end

function pushItems()
    local items = world.containerItems(self.chest)

    for key, item in pairs(items) do
        local canPut = peekPushItem(1, item)

        if canPut then
            local pushed = pushItem(1, canPut[1])

            if pushed then
                item.count = pushed[2].count
                world.containerConsumeAt(self.chest, key - 1, item.count)
            end

            break
        end
    end
end

function beforeItemPush(item, nodeId)
    if item and self.chest then
        local canFit = world.containerItemsFitWhere(self.chest, item)

        if canFit then
            if canFit.leftover ~= 0 then
                item.count = item.count - canFit.leftover
            end

            return item
        end
    end

    return nil
end

function onItemPush(item, nodeId)
    if item and self.chest then
        local returnedItem = world.containerAddItems(self.chest, item)

        if returnedItem then
            item.count = item.count - returnedItem.count
        end

        return item
    end
    return nil
end

function beforeItemPull(filters, nodeId)
    local res = nil

    if self.chest then
        local items = world.containerItems(self.chest)

        res = filterItems(filters, item)
    end

    return res
end

function onItemPull(item, nodeId)
    local res = nil

    if self.chest then
        local items = world.containerItems(self.chest)
        res, idx = filterItems({{
            item = item,
            amount = {item.count, item.count}
        }}, items)
        
        if res then
            world.containerConsumeAt(self.chest, i - 1, ret.count)
        end
    end

    return res
end
