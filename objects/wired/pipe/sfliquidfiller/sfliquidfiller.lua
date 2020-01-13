function init(args)
    pipes.init({liquidPipe, itemPipe})
    energy.init()

    if object.direction() < 0 then
        pipes.nodes["liquid"] = config.getParameter("flippedLiquidNodes")
        pipes.nodes["item"] = config.getParameter("flippedItemNodes")
    end

    object.setInteractive(true)

    self.conversions = config.getParameter("liquidConversions")
    sb.logInfo("conversion = %s", self.conversions)
    self.liquidAmount = config.getParameter("liquidAmount")
    self.energyRate = config.getParameter("energyConsumptionRate")

    self.fillInterval = config.getParameter("fillInterval")
    self.fillTimer = 0

    if storage.state == nil then storage.state = false end
    storage.liquids = {}
end

function die()
    energy.die()
end

function onInputNodeChange(args)
    storage.state = args.level
    if storage.state then animator.setAnimationState("fillstate", "on") end
end

function onNodeConnectionChange()
    storage.state = object.getInputNodeLevel(0)
    if storage.state then animator.setAnimationState("fillstate", "on") end
end

function onInteraction(args)
    --pump liquid
    if object.isInputNodeConnected(0) == false then
        storage.state = not storage.state
        if storage.state then animator.setAnimationState("fillstate", "on") end
    end
end

function beforeItemPut(item, nodeId)
    if storage.block.name == nil or storage.block.count <= 0 then
        local acceptItem = false
        local pullFilter = {}
        for matitem,_ in pairs(self.conversions) do
            if item.name == matitem then return true end
        end
    end
    return false
end

function onItemPut(item, nodeId)
    if storage.block.name == nil or storage.block.count <= 0 then
        local acceptItem = false
        local pullFilter = {}
        for matitem,conversion in pairs(self.conversions) do
            if item.name == matitem then
                if item.count <= conversion.input then
                    storage.block = item
                    return true --used whole stack
                else
                    item.count = conversion.input
                    storage.block = item
                    return conversion.input --return amount used
                end
            end
        end
    end
    return false
end

function update(dt)
    pipes.update(dt)
    energy.update(dt)

    if storage.state then
        --Pull item if we don't have any
        if self.fillTimer > self.fillInterval then
            local done = false
            sb.logInfo("update :storage = %s", storage.liquids)

            for i, v in pairs(storage.liquids) do
                if v >= self.liquidAmount then
                    local capsule = fillCapsule({i, v})
                    sb.logInfo("capsule %s", capsule)
                    if capsule and energy.consumeEnergy(dt, 10) then
                        pushItem(1, capsule)
                        storage.liquids[i] = 0
                        animator.setAnimationState("fillstate", "work")
                        done = true
                    end
                end
            end

            if not done then
                local pulledLiquid = peekPullLiquid(1)
                if pulledLiquid and pulledLiquid >= self.liquidAmoun then
                    local newCapsule = fillCapsule(pulledLiquid)
                    if newCapsule and energy.consumeEnergy(dt, 10) then
                        local pullFilter = {}
                        pullFilter[tostring(liquid[1])] = {self.liquidAmount, self.liquidAmount}
                        pullLiquid(1, pullFilter)
                        pushItem(1, newCapsule)
                        animator.setAnimationState("fillstate", "work")
                    else
                        animator.setAnimationState("fillstate", "on")
                    end
                elseif pulledLiquid then

                else
                    animator.setAnimationState("fillstate", "on")
                end
            end
            self.fillTimer = 0
        end
        self.fillTimer = self.fillTimer + dt
    else
        animator.setAnimationState("fillstate", "off")
    end
end

function fillCapsuleOld(liquid)
    if self.conversions[liquid[1]] and liquid[2] == liquid[1][2] then
        local capsule = {name = self.conversions[liquid[1]], count = 1, data = {}}
        if peekPushItem(1, capsule) == true then return capsule end
    end
    return false
end

function fillCapsule(liquid)
    local liquidName = root.liquidName(liquid[1])
    sb.logInfo("fillingCapsule with %s %s", liquid, liquidName)

    if liquidName then
        if self.conversions[tostring(liquid[1])] ~= nil then
            liquid[1] = self.conversions[tostring(liquid[1])]
        end

        --get  directive here

        local data = {
            projectileConfig = {
                actionOnReap = {
                    {
                        action = "liquid",
                        quantity = self.liquidAmount,
                        liquid = liquidName
                    }
                }
            }
    }
        local capsule = {name = "sfcapsule", count = 1, data = data}

        if peekPushItem(1, capsule) then return capsule end
    end
    return nil
end

function beforeLiquidPut(liquid, nodeId)
    sb.logInfo("Beforeputting %s", liquid)
    sb.logInfo("storage %s", storage.liquids)
    if storage.state and liquid then
        amount = liquid[2]
        if storage.liquids[liquid[1]] then
            amount = amount + storage.liquids[liquid[1]]
        end

        if amount <= self.liquidAmount then
            return liquid
        else
            return liquid[1], self.liquidAmount
        end

    end
    return false
end

function onLiquidPut(liquid, nodeId)
    sb.logInfo("putting %s", liquid)
    sb.logInfo("storage %s", storage.liquids)

    if storage.state and liquid then
        local amount = liquid[2]

        if storage.liquids[liquid[1]] then
            amount = amount + storage.liquids[liquid[1]]
        end
        
        if amount <= self.liquidAmount then
            storage.liquids[liquid[1]] = amount
        else
            local excess = amount - self.liquidAmount
            storage.liquids[liquid[1]] = self.liquidAmount
            pushLiquid(1, {liquid[1], excess})
        end
    end
    return false
end

