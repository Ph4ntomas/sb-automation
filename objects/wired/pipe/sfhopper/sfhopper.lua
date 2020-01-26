function init()
    pipes.init({itemPipe})

    self.timer = 0
    self.pickupCooldown = 0.2

    self.ignoreIds = {}
    self.dropPoint = {entity.position()[1] + 1, entity.position()[2] + 1.5}
end

--------------------------------------------------------------------------------
local function tryPushItem(item)
    local res = nil
    local peek = nil
    local node = 1
    local peek1 = peekPushItem(1, item)
    local peek2 = peekPushItem(2, item)

    if peek1 and peek2 then
        if peek1[2][2] >= peek[2][2] then
            peek = peek1
            node = 1
        else
            peek = peek2
            node = 2
        end
    elseif peek1 then
        peek = peek1
        node = 1
    elseif peek2 then
        peek = peek2
        node = 2
    end

    if peek then
        res = pushItem(node, peek[1])
    end

    return res
end

function update(dt)
    pipes.update(dt)

    if self.timer > self.pickupCooldown and (isItemNodeConnected(1) or isItemNodeConnected(2)) then
        --Try to push from inventory first
        local result = nil;
        local items = world.containerItems(entity.id())

        for key, wItem in pairs(items) do
            result = tryPushItem({wItem.name, wItem.count, data = wItem.data})
            if result then
                item.count = result[2][2] --amount accepted
                world.containerConsume(entity.id(), item)

                break
            end
        end

        --If inventory fails
        if not result then
            local itemDropList = findItemDrops()
            if #itemDropList > 0 then
                for i, itemId in ipairs(itemDropList) do
                    if not self.ignoreIds[itemId] then
                        local item = world.takeItemDrop(itemId, entity.id())
                        if item then
                            outputItem(item)
                        end
                    end
                end
            end
        end
        self.timer = 0
    end
    self.timer = self.timer + dt
end

function findItemDrops()
    local pos = entity.position()
    return world.itemDropQuery(pos, {pos[1] + 2, pos[2] + 1})
end

function outputItem(item)
    local result = tryPushItem(item)

    if result then
        item.count = item.count - result[2][2]
    end

    if item.count ~= 0 then
        ejectItem(item)
    end
end

function ejectItem(item)
    local itemDropId
    itemDropId = world.spawnItem(item.name, self.dropPoint, item.count, item.parameters)
    self.ignoreIds[itemDropId] = true
end
