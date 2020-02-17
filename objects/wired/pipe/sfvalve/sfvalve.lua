function init()
    object.setInteractive(true)

    if storage.state == nil then
        storage.state = true
    end
    updateAnimationState()

    self.connectionMap = {}
    self.connectionMap[1] = 2
    self.connectionMap[2] = 1
    self.connectionMap[3] = 4
    self.connectionMap[4] = 3

    pipes.init({liquidPipe,itemPipe})
end

--------------------------------------------------------------------------------

function onInteraction(args)
    if not object.isInputNodeConnected(0) then
        storage.state = not storage.state
        updateAnimationState()
    end
end

function onInputNodeChange(args)
    checkInputNodes()
end

function onNodeConnectionChange()
    checkInputNodes()
end

--------------------------------------------------------------------------------
function update(dt)
    pipes.update(dt)
end

function checkInputNodes()
    if object.isInputNodeConnected(0) then
        object.setInteractive(false)
        storage.state = object.getInputNodeLevel(0)
        updateAnimationState()
    else
        object.setInteractive(true)
    end
end

function updateAnimationState()
    if storage.state then
        animator.setAnimationState("switchState", "on")
    else
        animator.setAnimationState("switchState", "off")
    end
end

function beforeLiquidPull(filter, nodeId)
    if storage.state then
        local ret = peekPullLiquid(self.connectionMap[nodeId], filter)

        if ret then return ret[2] end
    end

    return nil
end

function onLiquidPull(liquid, nodeId)
    if storage.state then
        local peek = peekPullLiquid(self.connectionMap[nodeId], {{
            liquid = liquid,
            amount = {liquid.count, liquid.count}
        }})

        if peek then
            local ret = pullLiquid(self.connectionMap[nodeId], peek[1])

            if ret then return ret[2] end
        end
    end

    return nil
end

function beforeLiquidPush(liquid, nodeId)
    if storage.state then
        local ret = peekPushLiquid(self.connectionMap[nodeId], liquid)

        if ret then return ret[2] end
    end

    return nil
end

function onLiquidPush(liquid, nodeId)
    if storage.state then
        local peek = peekPushLiquid(self.connectionMap[nodeId], liquid)

        if peek then
            local ret = pushLiquid(self.connectionMap[nodeId], peek[1])

            if ret then return ret[2] end
        end
    end

    return nil
end

function beforeItemPush(item, nodeId)
    if storage.state then
        local ret = peekPushItem(self.connectionMap[nodeId], item)

        if ret then return ret[2] end
    end

    return nil
end

function onItemPush(item, nodeId)
    if storage.state then
        local peek = peekPushItem(self.connectionMap[nodeId], item)

        if peek then
            local ret = pushItem(self.connectionMap[nodeId], peek[1])

            return ret[2]
        end
    else
        return nil
    end
end

function beforeItemPull(filter, nodeId)
    if storage.state then
        local ret = peekPullItem(self.connectionMap[nodeId], filter)

        if ret then return ret[2] end
    end

    return nil
end

function onItemPull(filter, nodeId)
    if storage.state then
        local peek = peekPullItem(self.connectionMap[nodeId], filter)

        if peek then
            local ret = pullItem(self.connectionMap[nodeId], peek[1])

            if ret then return ret[2] end
        end
    end

    return nil
end
