function init()
    object.setInteractive(true)

    pipes.init({liquidPipe})
    energy.init()

    animator.setAnimationState("pumping", "idle")

    self.pumping = false
    self.pumpRate = config.getParameter("pumpRate", 0)
    self.pumpTimer = 0

    self.pushedSinceUpdate = 0

    if storage.state == nil then storage.state = false end
end

function onInputNodeChange(args)
    storage.state = args.level
end

function onNodeConnectionChange()
    storage.state = object.getInputNodeLevel(0)
end

function onInteraction(args)
    --pump liquid
    if object.isInputNodeConnected(0) == false then
        storage.state = not storage.state
    end
end

function die()
    energy.die()
end

function pump(dt)
    local srcNode, tarNode = orderNode(object.direction())

    local liquid = peekPullLiquid(srcNode)
    local canGetLiquid = false

    if liquid then
        local filter = {}
        filter[tostring(liquid[1])] = {0, self.pumpAmount}
        canGetLiquid = peekPullLiquid(srcNode, filter)
    end

    local canPutLiquid = peekPushLiquid(tarNode, canGetLiquid)

    if canGetLiquid and canPutLiquid and energy.consumeEnergy(dt) then
        filter[liquid[1]][2] = min(filter[liquid[1]][2], canPutLiquid[2])

        animator.setAnimationState("pumping", "pump")
        object.setAllOutputNodes(true)

        local liquid = pullLiquid(srcNode, filter)
        pushLiquid(tarNode, liquid)
    else
        object.setAllOutputNodes(false)
        animator.setAnimationState("pumping", "error")
    end

    self.pumpTimer = 0
end

function orderNode(direction)
    if direction == 1 then
        return { 1, 2 }
    else
        return { 2, 1 }
    end
end

function update(dt)
    pipes.update(dt)
    energy.update(dt)

    if storage.state then
        -- consume for passive mode
        self.pushedSinceUpdate = 0

        if self.pumpTimer > self.pumpRate then
            pump(dt)
        end
        self.pumpTimer = self.pumpTimer + dt
    else
        animator.setAnimationState("pumping", "idle")
        object.setAllOutputNodes(false)
    end
end

function beforeLiquidPut(liquid, nodeId)
    local srcNode, tarNode = orderNode(object.direction())

    if nodeId == srcNode then
        return peekPushLiquid(tarNode, liquid)
    end

    return nil
end

function onLiquidPut(liquid, nodeId)
    local srcNode, tarNode = orderNode(object.direction())

    if nodeId == srcNode and storage.state then
        animator.setAnimationState("pumping", "pump")
        object.setAllOutputNodes(true)
        self.pushedSinceUpdate = self.pushedSinceUpdate + 1
        return pushLiquid(tarNode, liquid)
    end

    return nil
end
