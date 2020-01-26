function init(args)
    pipes.init({liquidPipe, itemPipe})
    energy.init()

    if object.direction() < 0 then
        pipes.nodes["liquid"] = config.getParameter("flippedLiquidNodes")
        pipes.nodes["item"] = config.getParameter("flippedItemNodes")
    end

    local dir = root.itemConfig(object.name())["directory"]
    sb.logInfo("conversions = %s", root.assetJson(dir .. config.getParameter("conversions"))["snow"] )

    object.setInteractive(true)

    self.conversions = root.assetJson(dir .. config.getParameter("conversions"))

    self.damageRate = config.getParameter("damageRate")
    self.damageAmount = config.getParameter("damageAmount")
    self.blockOffset = config.getParameter("blockOffset")

    self.energyRate = config.getParameter("energyConsumptionRate")

    self.damageTimer = 0

    if storage.block == nil then storage.block = {} end
    if storage.placedBlock == nil then storage.placedBlock = {} end
    if storage.state == nil then storage.state = false end
end

function die()
    energy.die()

    local placePosition = blockPosition()
    local extractorBlock = world.objectQuery(placePosition, 1, {name = "sfextractorblock"})
    if extractorBlock and #extractorBlock > 0 then
        world.logInfo("%s", extractorBlock)
        world.callScriptedEntity(extractorBlock[1], "damageBlock", 999999) --Really Big Number
    end

    if storage.block[1] then
        local position = entity.position()
        if next(storage.block[3]) == nil then
            world.spawnItem(storage.block[1], {position[1] + 1.5, position[2] + 1.5}, storage.block[2])
        else
            world.spawnItem(storage.block[1], {position[1] + 1.5, position[2] + 1.5}, storage.block[2], storage.block[3])
        end
    end
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

function beforeItemPut(item, nodeId)
    if storage.block.name == nil or storage.block.count <= 0 then
        local acceptItem = false
        local pullFilter = {}

        if self.conversions[item.name] then
            item.count = math.min(item.count, self.conversions[item.name].input)
            return item
        end
    end

    return nil
end

function onItemPut(item, nodeId)
    if storage.block.name == nil or storage.block.count <= 0 then
        local acceptItem = false
        local pullFilter = {}

        if self.conversions[item.name] then
            item.count = math.min(item.count self.conversions[item.name].input)
        end

        storage.block = item
        return item
    end

    return nil
end

local function tryPullItem()
    local pullFilter = {}

    for matitem,conversion in pairs(self.conversions) do
        pullFilter[matitem] = {1, conversion.input}
    end

    local peek = peekPullItem(1, pullFilter)

    if peek then
        local pulledItem = pullItem(1, peek[1])

        if pulledItem then
            storage.block = pulledItem
        end
    end
end

function update(dt)
    pipes.update(dt)
    energy.update(dt)

    if storage.state then
        --Pull item if we don't have any
        if storage.block.name == nil or storage.block.count <= 0 then
            storage.block = {}
            tryPullItem()
        end

        if storage.block.name == nil then turnOff() end


        if self.damageTimer > self.damageRate then
            if storage.placedBlock[1] == nil then
                if placeBlock() then
                    animator.setAnimationState("extractState", "open")
                end
            else
                local blockConversion = self.conversions[storage.placedBlock[1]]
                local liquidOut = {name = blockConversion.liquid, count = storage.placedBlock[3]}
                local peek = peekPushLiquid(1, liquidOut)

                if peek and peek[2].count > 0 and energy.consumeEnergy(self.energyRate * self.damageRate) then
                    animator.setAnimationState("extractState", "work")
                    if checkBlock() then
                        local placePosition = blockPosition()
                        world.callScriptedEntity(storage.blockId, "damageBlock", self.damageAmount)
                    else
                        pushLiquid(1, peek[1])
                        storage.block.count = storage.block.count - storage.placedBlock[2]
                        storage.placedBlock = {}
                    end
                else
                    turnOff()
                end
            end
            self.damageTimer = 0
        end
        self.damageTimer = self.damageTimer + dt
    else
        turnOff()
    end
end

function turnOff()
    if checkBlock() then
        animator.setAnimationState("extractState", "error")
    else
        animator.setAnimationState("extractState", "off")
    end
end

function blockPosition()
    local position = entity.position()
    return {position[1] + self.blockOffset[1], position[2] + self.blockOffset[2]}
end


function placeBlock()
    if storage.block.name then
        local blockConversion = self.conversions[storage.block.name]
        if blockConversion then
            local placePosition = blockPosition()
            local placedObject = world.placeObject("sfextractorblock", placePosition, object.direction(), {initState = storage.block.name})
            if placedObject then
                local placedBlock = {}
                placedBlock[1] = storage.block.name
                placedBlock[2] = blockConversion.input
                placedBlock[3] = blockConversion.output
                if placedBlock[2] > storage.block.count then
                    placedBlock[3] = blockConversion.output * (storage.block.count / placedBlock[2])
                    placedBlock[2] = storage.block.count
                end
                storage.placedBlock = placedBlock

                storage.blockId = placedObject
                return true
            end
        end
    end
    return false
end

function checkBlock()
    if storage.placedBlock[1] then
        local placePosition = blockPosition()
        local extractorBlock = world.objectQuery(placePosition, 1, {name = "sfextractorblock"})
        if extractorBlock and #extractorBlock == 1 then
            storage.blockId = extractorBlock[1]
            return storage.blockId
        end
    end
    storage.blockId = nil
    return false
end
