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
    if storage.liquid[1] ~= nil then
        world.spawnItem("sfliquidtank", {position[1] + 1.5, position[2] + 1}, 1, {initialInventory = storage.liquid})
    else
        world.spawnItem("sfliquidtank", {position[1] + 1.5, position[2] + 1}, 1)
    end
end


function onInteraction(args)
    local liquid = self.liquidMap[storage.liquid[1]]
    local count = storage.liquid[2]
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

    local liquidState = self.liquidMap[storage.liquid[1]]
    if liquidState then
        animator.setAnimationState("liquid", liquidState)
    else
        animator.setAnimationState("liquid", "other")
    end

    if storage.liquid[2] then
        local liquidScale = storage.liquid[2] / self.capacity
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
    if storage.liquid[2] ~= nil and storage.liquid[2] == 0 then
        storage.liquid = {}
    end
end

function onLiquidPut(liquid, nodeId)
    local res = nil

    if liquid then
        if storage.liquid and liquid[1] == storage.liquid[1] then
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

            storage.liquid[2] = res
        end
    end

    return res
end

function beforeLiquidPut(liquid, nodeId)
    local res = nil

    if liquid then
        if storage.liquid and liquid[1] == storage.liquid[1] then
            if storage.liquid[2] >= self.capacity then
                res = nil
            else
                if liquid[2] > (self.capacity - storage.liquid[2]) then
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

function onLiquidGet(filter, nodeId)
    if storage.liquid[1] ~= nil then
        local liquids = {{storage.liquid[1], storage.liquid[2]}}
        local returnLiquid, _ = filterLiquids(filter, liquids)

        if returnLiquid then
            if filter == nil and returnLiquid[2] > self.pushAmount then 
                returnLiquid[2] = self.pushAmount 
            end

            storage.liquid[2] = storage.liquid[2] - returnLiquid[2]

            if storage.liquid[2] == 0 then
                storage.liquid = {}
            end

            return returnLiquid
        end
    end
    return nil
end

function beforeLiquidGet(filter, nodeId)
    if storage.liquid[1] ~= nil then
        local liquids = {{storage.liquid[1], storage.liquid[2]}}
        local returnLiquid, _ = filterLiquids(filter, liquids)

        if filter == nil and returnLiquid[2] > self.pushAmount then 
            returnLiquid[2] = self.pushAmount 
        end

        return returnLiquid
    end
    return nil
end
