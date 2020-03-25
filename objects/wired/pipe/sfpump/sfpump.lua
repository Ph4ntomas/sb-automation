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
    local canGetLiquid = nil

    if liquid then
        if liquid.count >= self.pumpAmount then
            return false
        end

        filter = {
            {
                liquid = liquid, 
                amount = { 0, self.pumpAmount - liquid.count }
            }
        }

        canGetLiquid = peekPullLiquid(nodeId, filter)
        inStore = liquid.count
    else
        filter = {
            {
                { amount = {0, self.pumpAmount} } -- liquid = nil here
            }
        }
        canGetLiquid = peekPullLiquid(nodeId, filter)
    end

    if canGetLiquid then
        local pulledLiquid = pullLiquid(nodeId, canGetLiquid[1])

        if pulledLiquid then
            pulledLiquid[2].count = pulledLiquid[2].count + inStore
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
                local amount = pushedLiquid[2].count

                if amount >= storage.liquid.count then
                    storage.liquid = nil
                else
                    storage.liquid.count = storage.liquid.count - amount
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

    if energy.consume(dt, nil, true) then
        local resPull = tryPull(srcNode)
        local resPush = tryPush(tarNode)

        if (resPull or resPush) and energy.consume(dt) then
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

function beforeLiquidPush(liquid, nodeId)
    local srcNode, tarNode = orderNode(object.direction())
    local res = nil

    if nodeId == srcNode and storage.state and liquid then
        if storage.liquid and liquid.name == storage.liquid.name then
            if storage.liquid.count == self.capacity then
                res = nil
            elseif storage.liquid.name == liquid.name then
                if liquid.count >= (self.capacity - storage.liquid.count) then
                    res = {name = liquid.name, count = self.capacity - storage.liquid.count}
                else
                    res = liquid
                end
            end
        elseif not storage.liquid or not storage.liquid.name then
            if liquid.count > self.capacity then
                res = {name = liquid.name, count = self.capacity}
            else
                res = liquid
            end
        end
    end

    return res
end

function onLiquidPush(liquid, nodeId)
    local srcNode, tarNode = orderNode(object.direction())
    local res = nil

    if nodeId == srcNode and storage.state and liquid then
        if storage.liquid and storage.liquid.name == liquid.name then
            if storage.liquid.count >= self.capacity then
                res = nil
            else
                if liquid.count > (self.capacity - storage.liquid.count) then
                    res = {name = liquid.name, count = self.capacity - storage.liquid.count}
                else
                    res = liquid
                end

                storage.liquid.count = math.min(storage.liquid.count + liquid.count, self.capacity)
            end
        elseif not storage.liquid or not storage.liquid.name then
            if liquid.count > self.capacity then
                res = {name = liquid.name, count = self.capacity}
            else
                res = liquid
            end

            storage.liquid = res
        end
    end

    return res
end
