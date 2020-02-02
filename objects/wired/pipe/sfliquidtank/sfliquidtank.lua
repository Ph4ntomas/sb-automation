function init()  
    object.setInteractive(true)
    pipes.init({liquidPipe})
    local initInv = config.getParameter("initialInventory")
    if initInv and storage.liquid == nil then
        storage.liquid = initInv
    end

    self.capacity = config.getParameter("liquidCapacity")
    self.pushAmount = config.getParameter("liquidPushAmount")
    self.pushRate = config.getParameter("liquidPushRate")

    --TODO: set directives on Init

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
    local liquidName
    local count

    if storage.liquid and storage.liquid.name and storage.liquid.count then
        liquidName = sfliquidutil.getLiquidReadableName(root.liquidName(storage.liquid.name))
        count = storage.liquid.count
    end

    local popupMessage = "Tank is empty."
    if count and count >= 0 then
        popupMessage = string.format(
        "^white;Holding \
        ^green;%f\
        ^white; / \
        ^green;%d\
        ^white; units of ^green;%s", count, self.capacity, liquidName)
    end

    return { "ShowPopup", { message = popupMessage }}
end

function getDirective(liquid)
    local ret = ""
    local liquidName = root.liquidName(liquid)

    if liquidName then
        local hsvShift = sfliquidutil.getColorShift(liquidName)

        if hsvShift then
            local hueshift = "?hueshift=" .. tostring(hsvShift.hue)
            local saturation = "?saturation=" .. tostring(hsvShift.sat * 100)
            local brightness = "?brightness=" .. tostring(hsvShift.val * 100)

            ret = ret .. hueshift .. saturation .. brightness
        end
    end

    return ret
end

local function updateLiquidLevel()
    local liquidScale = storage.liquid.count / self.capacity

    animator.resetTransformationGroup("liquid")
    animator.setPartTag("liquid", "directives", getDirective(storage.liquid.name))
    animator.setAnimationState("liquid", "base", true)
    animator.transformTransformationGroup("liquid", 1, 0, 0, liquidScale, 0, -1)
    --animator.transformTransformationGroup("liquid", 1, 0, 0, liquidScale, 0, -2.2 * (1 - liquidScale))
end

function update(dt)
    pipes.update(dt)

    if storage.liquid.count then
        updateLiquidLevel()
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

function onLiquidPush(liquid, nodeId)
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
            sfliquidutil.setLiquid(root.liquidName(storage.liquid.name))

            --TODO: setup directives early

        end
    end

    return res
end

function beforeLiquidPush(liquid, nodeId)
    local res = nil

    if storage.liquid and liquid.name == storage.liquid.name then
        if storage.liquid.count >= self.capacity then
            res = nil
        else
            if liquid.count > (self.capacity - storage.liquid.count) then
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

    return res
end

function onLiquidPull(filter, nodeId)
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

function beforeLiquidPull(filter, nodeId)
    if storage.liquid.name ~= nil then
        local liquids = {{name = storage.liquid.name, count =  math.min(storage.liquid.count, self.pushAmount)}}

        local returnLiquid, _ = filterLiquids(filter, liquids)

        return returnLiquid
    end
    return nil
end
