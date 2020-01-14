function init()
    object.setInteractive(true)

    pipes.init({liquidPipe})
    energy.init()

    animator.setAnimationState("pumping", "idle")

    self.pumping = false
    self.pumpRate = config.getParameter("pumpRate", 0)
    self.pumpTimer = 0

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

function update(dt)
    pipes.update(dt)
    energy.update(dt)

    if storage.state then
        local srcNode
        local tarNode
        if object.direction() == 1 then
            srcNode = 1
            tarNode = 2
        else
            srcNode = 2
            tarNode = 1
        end

        if self.pumpTimer > self.pumpRate then
            local liquid = peekPullLiquid(srcNode)
            local canGetLiquid = false

            if liquid then
                local filter = {}
                filter[tostring(liquid[1])] = {1, self.pumpAmount}
                canGetLiquid = peekPullLiquid(srcNode, filter)
            end
            local canPutLiquid = peekPushLiquid(tarNode, canGetLiquid)

            if canGetLiquid and canPutLiquid and energy.consumeEnergy(dt) then
                filter[liquid[1]][2] = max(filter[liquid[1]][2], canPutLiquid[2])

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
        self.pumpTimer = self.pumpTimer + dt
    else
        animator.setAnimationState("pumping", "idle")
        object.setAllOutputNodes(false)
    end
end
