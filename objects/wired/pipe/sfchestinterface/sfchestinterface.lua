function init(virtual)
    pipes.init({itemPipe})

    if object.direction() < 0 then
        pipes.nodes["liquid"] = config.getParameter("flippedLiquidNodes")
        pipes.nodes["item"] = config.getParameter("flippedItemNodes")
    end

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
    local pos = object.toAbsolutePosition({object.direction(), 1})
    local searchPos = {pos[1] + 0.5, pos[2] + 0.1}
    local entityIds = world.objectLineQuery(searchPos, searchPos, { withoutEntityId = entity.id(), order = "nearest" })
    --world.logInfo("searched for chests, found entities %s", entityIds)
    for i, entityId in ipairs(entityIds) do
        if world.containerSize(entityId) then
            self.chest = entityId
            --world.logInfo("connected successfully to %s %d", world.entityName(entityId), entityId)
            break
        end
    end
end

function pushItems()
    local items = world.containerItems(self.chest)

    for key, wItem in pairs(items) do
        local item = {wItem.name, wItem.count, data = wItem.data}
        local canPut = peekPushItem(1, item)

        if canPut then
            local pushed = pushItem(1, canPut[1])

            if pushed then
                wItem.count = pushed[2][2]
                world.containerConsume(self.chest, wItem)
            end

            break
        end
    end
end

function beforeItemPut(item, nodeId)
    if item and self.chest then
        local wItem = {name = item[1], count = item[2], data = item.data}
        local canFit = world.containerItemsFitWhere(self.chest, wItem)
        if canFit then
            if canFit.leftover ~= 0 then
                item[2] = item[2] - canFit.leftover
            end

            return item
        end
    end

    return nil
end

function onItemPut(item, nodeId)
    if item and self.chest then
        local wItem = {name = item[1], count = item[2], data = item.data}
        local returnedItem = world.containerAddItems(self.chest, wItem)

        if returnedItem then
            item[2] = item[2] - returnedItem.count
        end

        return item
    end
    return nil
end

function beforeItemGet(filter, nodeId)
    local res = nil

    if self.chest then
        for _, item in pairs(world.containerItems(self.chest)) do
            if filter then
                if filter[item.name] and item.count > filter[item.name][1] then
                    item.count = math.min(item.count, filter[item.name][2])
                    res = {item.name, item.count, data = item.data}
                    break
                end
            else
                res = {item.name, item.count, data = item.data}
                break
            end
        end
    end

    return res
end

function onItemGet(filter, nodeId)
    local res = nil

    if self.chest then
        for _, item in pairs(world.containerItems(self.chest)) do
            if filter then
                if filter[item.name] and item.count > filter[item.name][1] then
                    item.count = math.min(item.count, filter[item.name][2])
                    res = {item.name, item.count, data = item.data }
                    world.containerConsume(self.chest, item)
                    break
                end
            else
                res = {item.name, item.count, data = item.data}
                world.containerConsume(self.chest, item)
                break
            end
        end
    end

    return res
end
