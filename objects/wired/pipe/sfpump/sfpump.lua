function init()
    object.setInteractive(true)

    pipes.init({liquidPipe})
    energy.init()

    animator.setAnimationState("pumping", "idle")

    self.pumping = false
    self.pumpRate = config.getParameter("pumpRate", 0)
    self.pumpAmount = config.getParameter("pumpAmount", 0)
    self.pumpTimer = 0

    self.capacity = self.pumpAmount
    self.capacity = self.pumpAmount
    storage.liquid = nil

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

function tryPull(nodeId)
    local liquid = storage.liquid
    local inStore = 0
    local canGetLiquid = false

    if liquid then
        filter = {liquid[1], {0, self.pumpAmount - liquid[2]}}
        canGetLiquid = peekPullLiquid(nodeId, filter)
        inStore = liquid[2]
    else
        filter = {nil, {0, self.pumpAmount}}
        canGetLiquid = peekPullLiquid(nodeId, filter)
    end

    if canGetLiquid then
        local pulledLiquid = pullLiquid(nodeId, canGetLiquid[1])
        if pulledLiquid then
            pulledLiquid[2][2] = pulledLiquid[2][2] + inStore
            storage.liquid = pulledLiquid[2]

            return true
        end
    end

    return false
end

function tryPush(nodeId)
    local liquid = storage.liquid
    
    if liquid then
        local canPutLiquid = peekPushLiquid(nodeId, liquid)

        if canPutLiquid then
            local pushedLiquid = pushLiquid(nodeId, canPutLiquid[1])

            if pushedLiquid then
                local amount = pushedLiquid[2][2]

                if amount >= storage.liquid[2] then
                    storage.liquid = nil
                else
                    storage.liquid[2] = storage.liquid[2] - amount
                end


                return true
            end
        end
    end

    return false
end

function pump(dt)
    local srcNode, tarNode = orderNode(object.direction())
    local filter = {}

    sb.logInfo("pumping from %s, to %s", srcNode, tarNode)

    if energy.consumeEnergy(dt, nil, true) then
        local resPull = tryPull(srcNode)
        local resPush = tryPush(tarNode)

        if (resPull or resPush) and energy.consumeEnergy(dt) then
            animator.setAnimationState("pumping", "pump")
            object.setAllOutputNodes(true)
        else
            object.setAllOutputNodes(false)
            animator.setAnimationState("pumping", "error")
        end
    else
        object.setAllOutputNodes(false)
        animator.setAnimationState("pumping", "error")
    end

    self.pumpTimer = 0
end

function orderNode(direction)
    if direction == 1 then
        return 1, 2
    else
        return 2, 1
    end
end

function update(dt)
    pipes.update(dt)
    energy.update(dt)

    if storage.state then
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
    local res = nil

    if nodeId == srcNode and storage.state and liquid then
        if storage.liquid and liquid[1] == storage.liquid[1] then
            if storage.liquid[2] == self.capacity then
                res = nil
            elseif storage.liquid[1] == liquid[1] then
                if liquid[2] >= (self.capacity - storage.liquid[2]) then
                    res = {liquid[1], self.capacity - storage.liquid[2]}
                else
                    res = liquid
                end
            end
        elseif not storage.liquid or not storage.liquid[1] then
            if liquid[2] > self.capacity then
                res = {liquid[1], self.capacity}
            else
                res = liquid
            end
        end
    end

    return res
end

function onLiquidPut(liquid, nodeId)
    local srcNode, tarNode = orderNode(object.direction())
    local res = nil

    if nodeId == srcNode and storage.state and liquid then
        if storage.liquid and storage.liquid[1] == liquid[1] then
            if storage.liquid[2] >= self.capacity then
                res = nil
            else
                if liquid[2] > (self.capacity - storage.liquid[2]) then
                    res = {liquid[1], self.capacity - storage.liquid[2]}
                else
                    res = liquid
                end

                storage.liquid[2] = min(storage.liquid[2] + liquid[2], self.capacity)
            end
        elseif not storage.liquid or not storage.liquid[1] then
            if liquid[2] > self.capacity then
                res = {liquid[1], self.capacity}
            else
                res = liquid
            end

            storage.liquid = res
        end
    end

    return nil
end
