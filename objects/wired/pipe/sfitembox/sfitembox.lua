function init(args)
    object.setInteractive(true)

    pipes.init({itemPipe})

    local initInv = config.getParameter("initialInventory")
    if initInv and storage.sApi == nil then
        storage.sApi = initInv
    end

    storageApi.init({ mode = 3, capacity = 16, merge = true })

    animator.resetTransformationGroup("invbar")
    animator.scaleTransformationGroup("invbar", {2, 0})

    if object.direction() < 0 then
        animator.setAnimationState("flipped", "left")
    end

    self.pushRate = config.getParameter("itemPushRate")
    self.pushTimer = 0
end

function die()
    local position = entity.position()
    if storageApi.getCount() == 0 then
        world.spawnItem("sfitembox", {position[1] + 1.5, position[2] + 1}, 1)
    else
        world.spawnItem("sfitembox", {position[1] + 1.5, position[2] + 1}, 1, {initialInventory = storage.sApi})
    end
end

function onInteraction(args)
    local count = storageApi.getCount()
    local capacity = storageApi.getCapacity()
    local itemList = ""

    for _,item in storageApi.getIterator() do
        itemList = itemList .. "^green;" .. item.name .. "^white; x " .. item.count .. ", "
    end

    return { "ShowPopup", { 
        message = "^white;Holding ^green;" .. count ..
        "^white; / ^green;" .. capacity ..
        "^white; stacks of items." ..
        "\n\nStorage: " ..
        itemList
    }}
end

function update(dt)
    pipes.update(dt)

    --Scale inventory bar
    local relStorage = storageApi.getCount() / storageApi.getCapacity()

    animator.resetTransformationGroup("invbar")
    animator.transformTransformationGroup("invbar", 2, 0, 0, relStorage, 0.36, -0.5 * (1 - relStorage))

    if relStorage < 0.5 then 
        animator.setAnimationState("invbar", "low")
    elseif relStorage < 1 then
        animator.setAnimationState("invbar", "medium")
    else
        animator.setAnimationState("invbar", "full")
    end

    --Push out items if switched on
    if self.pushTimer > self.pushRate then
        pushItems()
        self.pushTimer = 0
    end
    self.pushTimer = self.pushTimer + dt
end

local function tryPushItem(node, item)
    local peek = peekPushItem(node, item)

    if peek then
        return pushItem(node, peek[1])
    end

    return nil
end

function pushItems()
    for node = 0, 1 do
        if object.getInputNodeLevel(node) then
            for i, item in storageApi.getIterator() do
                local result = tryPushItem(node + 1, item)
                if result then 
                    storageApi.returnItem(i, result[2][2]) 
                    break 
                end
            end
        end
    end
end

function onItemPush(item, nodeId)
    if item and not object.getInputNodeLevel(nodeId - 1) then
        local ret = storageApi.storeItemFit(item.name, item.count, item.data)

        item.count = item.count - ret

        return item
    end
    return nil
end

function beforeItemPush(item, nodeId)
    if item and not object.getInputNodeLevel(nodeId - 1) then
        local ret = storageApi.storeItemFit(item.name, item.count, item.data, true)

        item.count = item.count - ret
        return item
    end
    return nil
end

function onItemPull(filter, nodeId)
    if filter then
        for i,item in storageApi.getIterator() do
            if filter[item.name] then
                local amount = filter[item.name]
                
                if amount[1] < item.count then
                    local it = storageApi.returnItem(i, amount[2])

                    return {it.name, it.count, data = it.data}
                end
            end
        end
    else
        for i,item in storageApi.getIterator() do
            local it = storageApi.returnItem(i)

            return {it.name, it.count, data = it.data}
        end
    end
    return nil
end

function beforeItemPull(filter, nodeId)
    if filter then
        for i,item in storageApi.getIterator() do
            if filter[item.name] then
                local amount = filter[item.name]

                if amount[1] < item.count then
                    return {item.name, math.min(amount[2], item.count), data = item.data}
                end 
            end
        end
    else
        for i,item in storageApi.getIterator() do
            return {item.name, item.count, data = item.data}
        end
    end

    return nil
end
