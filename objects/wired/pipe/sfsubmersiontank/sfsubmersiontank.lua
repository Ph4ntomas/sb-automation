function init()  
    object.setInteractive(true)
    pipes.init({liquidPipe})

    local initInv = config.getParameter("initialInventory")
    if initInv and storage.liquid == nil then
        storage.liquid = initInv
    end

    if storage.liquid and storage.liquid.name then
        sfliquidutil.init(root.liquidName(storage.liquid.name))
    else
        sfliquidutil.init(nil)
    end

    self.capacity = config.getParameter("liquidCapacity")
    self.pushAmount = config.getParameter("liquidPushAmount")
    self.pushRate = config.getParameter("liquidPushRate")

    --self.previousState = world.loungeableOccupied(entity.id())

    if storage.liquid == nil then storage.liquid = {} end

    self.pushTimer = 0
end

function die()
    local position = entity.position()
    if storage.liquid.name ~= nil then
        world.spawnItem("sfsubmersiontank", {position[1] + 1.5, position[2] + 1}, 1, {initialInventory = storage.liquid, playerId = storage.playerId})
    else
        world.spawnItem("sfsubmersiontank", {position[1] + 1.5, position[2] + 1}, 1)
    end
end

function getLiquidReadableName(liquid)
    local ret = "unknown liquid"
    if liquid then
        local config = root.liquidConfig(liquid)

        if config then
            local item = config["config"]["itemDrop"]
            local iconf = root.itemConfig({name = item, 1})

            if iconf then
                ret = iconf["config"]["shortdescription"]
            end
        end
    end

    return ret
end

function onInteraction(args)
    local liquid = nil
    local liquidName = "unknown liquid"

    if storage.liquid.name ~= nil then
        liquid = root.liquidName(storage.liquid.name)
        liquidName = getLiquidReadableName(liquid)
    end

    local count = storage.liquid.count
    local capacity = self.capacity
    local itemList = ""

    if not world.loungeableOccupied(entity.id()) then
        if count ~= nil and count < capacity then 
            local popupMessage = string.format("^white;You manage to suppress the desire to climb into the tank... \
                for now.\n\n\
                ^white;Holding \
                ^green; %f\
                ^white; / ^green;%d \
                ^white; units of %s^green;", count, capacity, liquidName)

            return { "ShowPopup", { message = popupMessage }}
        elseif count ~= nil then
            storage.playerId = args.sourceId
            return { "SitDown", 0 }
        else
            return { "ShowPopup", { message = "Tank is empty."}}
        end
    else
        return { "ShowPopup", { message = "^white;The tank is occupied^white;Holding ^green;" .. count ..
            "^white; / ^green;" .. capacity ..
            "^white; units of liquid ^green;" .. liquid
        }}
    end
end

function cycleForeground(occupied)
    if occupied then
        animator.setAnimationState("foreground", "hidden")
    else
        if storage.playerId then
            storage.playerId = nil
        end
        animator.setAnimationState("foreground", "active")
    end
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

local function applyEffect()
    local config = sfliquidutil.getLiquidConfig(nil)

    if config then
        local effects = config["statusEffects"] 

        if not effects or #effects == 0 then
            effects = { "bed3" }
        end

        for _, effect in pairs(effects) do
            world.sendEntityMessage(storage.playerId, "applyStatusEffect", effect, 1, entity.id())
        end
    end
end

local function updateLiquidLevel()
    local liquidScale = storage.liquid.count / self.capacity

    animator.resetTransformationGroup("liquid")
    animator.setPartTag("liquid", "directives", getDirective(storage.liquid.name))
    animator.setAnimationState("liquid", "base", true)
    animator.transformTransformationGroup("liquid", 1, 0, 0, liquidScale, 0, -2.2 * (1 - liquidScale))
end

local function clearLiquid()
    if storage.liquid.count ~= nil and storage.liquid.count == 0 then
        storage.liquid = {}
    end
end

function update(dt)
    pipes.update(dt)

    local occupied = world.loungeableOccupied(entity.id())

    if storage.liquid.count then
        updateLiquidLevel()

        if storage.playerId then
            applyEffect(storage.liquid.name)
        end
    else
        animator.scaleTransformationGroup("liquid", {1, 0})
    end

    if self.previousState == nil then
        self.previousState = occupied
    end

    if occupied ~= self.previousState then
        cycleForeground(occupied)
        self.previousState = occupied
    end

    --TODO: Reactivate timer pushing
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

--- This function is called when another entity is calling push hook
function onLiquidPush(liquid, nodeId)
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
    end

    return res
end

function beforeLiquidPush(liquid, nodeId)
    local res = nil

    if liquid then
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
    end

    return res
end

function onLiquidPull(filter, nodeId)
    if storage.liquid.name ~= nil then
        local liquids = {{name = storage.liquid.name, count = math.min(storage.liquid.count, self.pushAmount)}}

        local returnLiquid, _ = filterLiquids(filter, liquids)
        if returnLiquid then
            storage.liquid.count = storage.liquid.count - returnLiquid.count
            if storage.liquid.count <= 0 then
                storage.liquid = {}
            end
            return returnLiquid
        end
    end
    return nil
end

function beforeLiquidPull(filter, nodeId)
    if storage.liquid.name ~= nil then
        local liquids = {{name = storage.liquid.name, count = math.min(storage.liquid.count, self.pushAmount)}}

        local returnLiquid, _ = filterLiquids(filter, liquids)

        return returnLiquid
    end

    return nil
end
