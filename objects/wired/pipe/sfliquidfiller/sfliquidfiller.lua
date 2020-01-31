function init(args)
    energy.init()
    pipes.init({liquidPipe, itemPipe})

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
    if object.isInputNodeConnected(0) == false then
        storage.state = not storage.state
        if storage.state then animator.setAnimationState("fillstate", "on") end
    end
end

function createCapsule(dt, liquidId, amount, pushExcess)
    if amount >= self.liquidAmount then
        local capsule, peek = fillCapsule({name = liquidId, count = self.liquidAmount})

        if capsule and energy.consumeEnergy(dt, 10) then
            pushItem(1, peek[1])
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

function update(dt)
    pipes.update(dt)
    energy.update(dt)

    if storage.state then
        if self.fillTimer > self.fillInterval then
            local done = false

            sb.logInfo("filler storage = %s", storage.liquids)
            for i, v in pairs(storage.liquids) do
                done = createCapsule(dt, i, v, false)

                if done then
                    break
                end
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

local function buildData(liquidName, amount, hsvShift)
    local capsuleConfig = root.itemConfig({name = "sfcapsule", count = 1})["config"]
    local data = {
        image = capsuleConfig["image"],
        inventoryIcon = capsuleConfig["inventoryIcon"],
        projectileConfig = { actionOnReap = capsuleConfig["projectileConfig"]["actionOnReap"] }
    }

    local liqItConfig = sfliquidutil.getLiquidItemConfig()
    if liqItemConfig ~= nil then
        data["shortdescription"] = liqItConfig["shortdescription"] .. " " .. capsuleConfig["shortdescription"]
        data["description"] = capsuleConfig["description"]:gsub("liquid", liqItConfig["shortdescription"]:lower())
    end


    data["projectileConfig"]["actionOnReap"][1]["liquid"] = liquidName
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
    local liquidName = root.liquidName(liquid.name)

    if liquidName then
        if self.conversions[tostring(liquid.name)] ~= nil then
            liquid.name = self.conversions[tostring(liquid.name)]
        end

        --get  directive here
        local hsvShift = getColorShiftForLiquid(liquidName)
        local data = buildData(liquidName, self.liquidAmount, hsvShift)

        local capsule = {name = "sfcapsule", count = 1, data = data}
        local peek = peekPushItem(1, capsule) 

        if peek then
            return capsule, peek
        end
    end

    return nil, nil
end

function beforeLiquidPush(liquid, nodeId)
    local ret = nil

    if storage.state and liquid then
        local amount = liquid.count
        local inStore = 0

        if storage.liquids[liquid.name] then
            --amount = amount + storage.liquids[liquid[1]]
            inStore = storage.liquids[liquid.name]
        end

        if amount > (self.liquidAmount - inStore) then
            liquid.count = liquid.count - (self.liquidAmount - inStore)
        end

        ret = liquid
    end

    return liquid
end

function onLiquidPush(liquid, nodeId)
    if storage.state and liquid then
        local amount = liquid.count
        local inStore = 0

        if storage.liquids[liquid.name] then
            inStore = storage.liquids[liquid.name]
        end
        
        if amount <= (self.liquidAmount - inStore) then
            storage.liquids[liquid.name] = amount + inStore
        else
            local excess = (amount + inStore) - self.liquidAmount

            storage.liquids[liquid.name] = self.liquidAmount
            liquid.count = liquid.count - excess
        end
        return liquid
    end
    return nil
end

