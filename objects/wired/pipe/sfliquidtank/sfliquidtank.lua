function init()  
    object.setInteractive(true)
    pipes.init({liquidPipe})
    local initInv = config.getParameter("initialInventory")
    if initInv and storage.liquid == nil then
        storage.liquid = initInv
    end

    animator.resetTransformationGroup("liquid")
    animator.scaleTransformationGroup("liquid", {1, 0})

    -- TODO: We can do the same thing by using root.getLiquidName(id) when needed
    self.liquidMap = {}
    self.liquidMap[1] = "water"
    self.liquidMap[2] = "lava"
    self.liquidMap[4] = "poison"
    self.liquidMap[6] = "tentacle juice"
    self.liquidMap[7] = "tar"

    self.capacity = config.getParameter("liquidCapacity")
    self.pushAmount = config.getParameter("liquidPushAmount")
    self.pushRate = config.getParameter("liquidPushRate")

    if storage.liquid == nil then storage.liquid = {} end

    self.pushTimer = 0
end

function die()
    local position = entity.position()

    if storage.liquid.name ~= nil then
        world.spawnItem("sfliquidtank", {position[1] + 1.5, position[2] + 1}, 1, {initialInventory = storage.liquid})
    else
        world.spawnItem("sfliquidtank", {position[1] + 1.5, position[2] + 1}, 1)
    end
end

function onInteraction(args)
    --TODO: Get liquid name from root functions.
    local liquid = self.liquidMap[storage.liquid.name]
    local count = storage.liquid.count
    local capacity = self.capacity
    local itemList = ""

    if liquid == nil then liquid = "other" end

    local popupMessage
    if count ~= nil then
        popupMessage = string.format("^white;Holding ^green;%f^white; / ^green;%d^white; units of liquid ^green;%s", count, capacity, liquid)
    else
        popupMessage = "Tank is empty."
    end
    return { "ShowPopup", { message = popupMessage }}
end

function update(dt)
    pipes.update(dt)

    --TODO: change the liquid state by hue shifting a base color (CF capsules)
    local liquidState = self.liquidMap[storage.liquid.name]
    if liquidState then
        animator.setAnimationState("liquid", liquidState)
    else
        animator.setAnimationState("liquid", "other")
    end

    if storage.liquid.count then
        local liquidScale = storage.liquid.count / self.capacity
        animator.resetTransformationGroup("liquid")
        animator.transformTransformationGroup("liquid", 1, 0, 0, liquidScale, 0, -1)
    else
        animator.scaleTransformationGroup("liquid", {1, 0})
    end

    -- TODO: reactivate pushing
    --if self.pushTimer > self.pushRate and storage.liquid[2] ~= nil then
    --local pushedLiquid = {storage.liquid[1], storage.liquid[2]}
    --if storage.liquid[2] > self.pushAmount then pushedLiquid[2] = self.pushAmount end
    --for i=1,2 do
    --if object.getInputNodeLevel(i-1) and pushLiquid(i, pushedLiquid) then
    --storage.liquid[2] = storage.liquid[2] - pushedLiquid[2]
    --break;
    --end
    --end
    --self.pushTimer = 0
    --end
    self.pushTimer = self.pushTimer + dt

    clearLiquid()
end

function clearLiquid()
    if storage.liquid.count ~= nil and storage.liquid.count == 0 then
        storage.liquid = {}
    end
end

function onLiquidPut(liquid, nodeId)
    local res = nil

    if liquid then
        if storage.liquid.name and liquid.name == storage.liquid.name then
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

function beforeLiquidPut(liquid, nodeId)
    local res = nil

    if liquid then
        if storage.liquid and liquid.name == storage.liquid.name then
            if storage.liquid.count >= self.capacity then
                res = nil
            else
                if liquid.count > (self.capacity - storage.liquid.count) then
                    res = {name = liquid.count, count = self.capacity - storage.liquid.count}
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

function onLiquidGet(filter, nodeId)
    if storage.liquid.name ~= nil then
        local liquids = {{name = storage.liquid.name, count =  math.min(storage.liquid.count, pushAmount)}}
        local returnLiquid, _ = filterLiquids(filter, liquids)

        if returnLiquid then
            storage.liquid.count = storage.liquid.count - returnLiquid.count

            if storage.liquid.count == 0 then
                storage.liquid = {}
            end

            return returnLiquid
        end
    end
    return nil
end

function beforeLiquidGet(filter, nodeId)
    if storage.liquid.name ~= nil then
        local liquids = {{name = storage.liquid.name, count =  math.min(storage.liquid.count, self.pushAmount)}}

        local returnLiquid, _ = filterLiquids(filter, liquids)

        return returnLiquid
    end
    return nil
end
