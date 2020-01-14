function init(args)
    pipes.init({liquidPipe, itemPipe})
    energy.init()

    if object.direction() < 0 then
        pipes.nodes["liquid"] = config.getParameter("flippedLiquidNodes")
        pipes.nodes["item"] = config.getParameter("flippedItemNodes")
    end

    object.setInteractive(true)

    self.conversions = config.getParameter("liquidConversions")
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

function createCapsule(dt, liquidId, amount, pushExcess)
    if amount >= self.liquidAmount then
        local capsule = fillCapsule({liquidId, self.liquidAmount})

        if capsule and energy.consumeEnergy(dt, 10) then
            pushItem(1, capsule)
            storage.liquids[liquidId] = amount - self.liquidAmount

            if storage.liquids[liquidId] > self.liquidAmount then 
                local excess = storage.liquids[liquidId] - self.liquidAmount
                storage.liquids[liquidId] = self.liquidAmount

                if excess and pushExcess then
                    pushLiquid(1, {liquidId, excess})
                end
            end

            animator.setAnimationState("fillstate", "work")
            return true
        end
    end

    return false
end

function tryPullingLiquid(dt)
    local pulledLiquid = peekPullLiquid(1)

    if pulledLiquid then
        local amount = pulledLiquid[2]
        local toPull = amount

        if storage.liquids[liquid[1]] then
            amount = liquid[2] + storage.liquids[liquid[1]] -- checking total amount available
            toPull = liquid[2] - storage.liquids[liquid[1]] -- if we have enough, we'll only pull the necessary amount
        end

        if amount >= self.liquidAmount then
            if createCapsule(dt, pulledLiquid[1], self.liquidAmount, true) then
                local pullFilter = {}
                pullFilter[tostring(liquid[1])] = {toPull, toPull}
                pullLiquid(1, pullFilter)
            end
        else
            pullLiquid(1) -- pulling everything available
            storage.liquids[pulledLiquid[1]] = amount
        end
    end

    animator.setAnimationState("fillstate", "on")
end

function update(dt)
    pipes.update(dt)
    energy.update(dt)

    if storage.state then
        if self.fillTimer > self.fillInterval then
            local done = false

            for i, v in pairs(storage.liquids) do
                done = createCapsule(dt, i, v, false)

                if done then
                    break
                end
            end

            if not done then
                tryPullingLiquid(dt)
            end
            self.fillTimer = 0
        end
        self.fillTimer = self.fillTimer + dt
    else
        animator.setAnimationState("fillstate", "off")
    end
end

local function getColorShiftForLiquid(name)
    local waterconfig = root.liquidConfig("water")
    local config = root.liquidConfig(name)

    if config and waterconfig then
        local waterRgb = waterconfig["config"]["color"]
        local rgb = config["config"]["color"]
        local lrgb = config["config"]["radiantLight"]
        local brgb = config["config"]["bottomLightMix"]

        if waterRgb and rgb then
            local waterHsv = sfutil.rgb2hsv(waterRgb)
            local liquidHsv = sfutil.rgb2hsv(rgb)

            if lrgb then
                local lHsv = sfutil.rgb2hsv(lrgb)

                if brgb then
                    local bHsv = sfutil.rgb2hsv(lrgb)

                    liquidHsv.hue = (liquidHsv.hue + lHsv.hue + bHsv.hue) / 3
                    liquidHsv.sat = (liquidHsv.sat + lHsv.sat + bHsv.sat) / 3
                    liquidHsv.val = (liquidHsv.val + lHsv.val + bHsv.val) / 3
                else
                    liquidHsv.hue = (liquidHsv.hue + lHsv.hue) / 2
                    liquidHsv.sat = (liquidHsv.sat + lHsv.sat) / 2
                    liquidHsv.val = (liquidHsv.val + lHsv.val) / 2
                end
            end

            return {
                hue = liquidHsv.hue - waterHsv.hue,
                sat = liquidHsv.sat - waterHsv.sat,
                val = liquidHsv.val - waterHsv.val,
                rgb[4]
            }
        end
    end
    return nil
end

function getLiquidName(name)
    local liquidConfig = root.liquidConfig(name)
    if liquidConfig then
        local liquidConfig = liquidConfig["config"]

        if liquidConfig["itemDrop"] then
            local config = root.itemConfig({name = liquidConfig["itemDrop"], count = 1})

            if config then
                local config = config["config"]
                return config["shortdescription"]
            end
        end
    end

    return nil
end

local function buildData(name, amount, hsvShift)
    local config = root.itemConfig({name = "sfcapsule", count = 1})["config"]
    local data = {
        image = config["image"],
        inventoryIcon = config["inventoryIcon"],
        projectileConfig = { actionOnReap = config["projectileConfig"]["actionOnReap"] }
    }

    local liquidName = getLiquidName(name)
    if liquidName ~= nil then
        data["shortdescription"] = liquidName .. " " .. config["shortdescription"]
        data["description"] = config["description"]:gsub("liquid", liquidName:lower())
    end


    data["projectileConfig"]["actionOnReap"][1]["liquid"] = name
    if amount then
        data["projectileConfig"]["actionOnReap"][1]["quantity"] = amount
    end

    if hsvShift then
        local hueshift = "?hueshift=" .. tostring(hsvShift.hue)
        local saturation = "?saturation=" .. tostring(hsvShift.sat * 100)
        local brightness = "?brightness=" .. tostring(hsvShift.val * 100)

        local directives = hueshift .. saturation .. brightness

        data["image"] = data["image"] .. directives
        data["inventoryIcon"] = data["image"]
        data["projectileConfig"]["processing"] = directives
    end

    return data
end

function fillCapsule(liquid)
    local liquidName = root.liquidName(liquid[1])

    if liquidName then
        if self.conversions[tostring(liquid[1])] ~= nil then
            liquid[1] = self.conversions[tostring(liquid[1])]
        end

        --get  directive here
        local hsvShift = getColorShiftForLiquid(liquidName)
        local data = buildData(liquidName, self.liquidAmount, hsvShift)

        local capsule = {name = "sfcapsule", count = 1, data = data}

        if peekPushItem(1, capsule) then 
            return capsule 
        end
    end

    return nil
end

function beforeLiquidPut(liquid, nodeId)
    if storage.state and liquid then
        local amount = liquid[2]
        local inStore = 0

        if storage.liquids[liquid[1]] then
            amount = amount + storage.liquids[liquid[1]]
            inStore = storage.liquids[liquid[1]]
        end

        if amount <= self.liquidAmount then
            return liquid
        else
            return liquid[1], self.liquidAmount - inStore
        end
    end
    return false
end

function onLiquidPut(liquid, nodeId)
    if storage.state and liquid then
        local amount = liquid[2]

        if storage.liquids[liquid[1]] then
            amount = amount + storage.liquids[liquid[1]]
        end
        
        if amount <= self.liquidAmount then
            storage.liquids[liquid[1]] = amount
        else -- should not happen, yet did
            local excess = amount - self.liquidAmount

            storage.liquids[liquid[1]] = self.liquidAmount
            pushLiquid(1, {liquid[1], excess})
        end
        return true
    end
    return false
end

