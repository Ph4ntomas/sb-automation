function init()
    energy.init()
    pipes.init({liquidPipe})

    self.lavaCapacity = 200
    storage.lavaLevel = storage.lavaLevel or 0
    self.lavaConsumptionRate = 10 --this is per tile, so multiply by 3 to get maximum total consumption
    self.energyPerLava = 0.2
    self.waterPerLava = 0.4

    self.liquidId = root.liquidId("lava")

    setOrientation()

    updateAnimationState()
    object.setMaterialSpaces({
        {{0,0}, "sfinvisipipe"}
    })
end

function die()
    energy.die()
end

function setOrientation()
    local orientation = config.getParameter("orientation")
    local pos = entity.position()

    if orientation == "down" then
        self.checkArea = {{pos[1], pos[2] - 2}, {pos[1], pos[2] - 1}, {pos[1], pos[2]}}
        self.activeNode = 1
    else
        self.checkArea = {{pos[1], pos[2]}, {pos[1], pos[2] + 1}, {pos[1], pos[2] + 2}}
        self.activeNode = 2
    end

    animator.setAnimationState("orientState", orientation)
end

function updateAnimationState()
    if storage.lavaLevel > 0 then
        animator.setAnimationState("lavaState", "on")
    else
        animator.setAnimationState("lavaState", "off")
    end
end

function beforeLiquidPush(liquid, nodeId)
    local ret = nil
    local unusedCapacity = self.lavaCapacity - storage.lavaLevel

    if liquid.name == self.liquidId and unusedCapacity > 0 then
        if liquid.count > unusedCapacity then
            ret = {name = liquid.name, count = unusedCapacity}
        else
            ret = liquid
        end
    end
    return ret
end

function onLiquidPush(liquid, nodeId)
    local ret = nil
    local unusedCapacity = self.lavaCapacity - storage.lavaLevel

    if liquid.name == self.liquidId and unusedCapacity > 0 then
        if liquid.count > unusedCapacity then
            ret = {name = liquid.name, count = unusedCapacity}
        else
            ret = liquid
        end

        storage.lavaLevel = storage.lavaLevel + ret.count
    end

    return ret
end

function pullLava()
    local unusedCapacity = self.lavaCapacity - storage.lavaLevel

    if unusedCapacity > 0 then
        local filter = {{
            liquid = {name = self.liquidId, count = unusedCapacity},
            amount = {1, unusedCapacity}
        }}

        local peek = peekPullLiquid(self.activeNode, filter)
        if peek then
            local res = pullLiquid(self.activeNode, peek[1])
            storage.lavaLevel = storage.lavaLevel + res[2].count
        end
    end
end

--never accept energy from elsewhere
function onEnergyNeedsCheck(needDesc)
    needDesc.need[entity.id()] = 0
    return needDesc
end

function generate(dt)
    local lavaPerTile = self.lavaConsumptionRate * dt
    for i, pos in ipairs(self.checkArea) do
        if storage.lavaLevel > 0 then
            --check liquid at the given tile
            local liquidSample = world.liquidAt(pos)
            if liquidSample and liquidSample[1] == 1 and liquidSample[2] >= 0.4 then
                --destroy water in the tile
                local destroyed = world.destroyLiquid(pos)

                --evaporate some water
                local consumeLava = math.min(lavaPerTile, storage.lavaLevel)
                local consumeWater = consumeLava * self.waterPerLava
                if destroyed[2] > consumeWater then
                    world.spawnLiquid(pos, 1, destroyed[2] - consumeWater)
                else
                    consumeLava = destroyed[2] * (1 - self.waterPerLava)
                end

                --convert lava to energy
                storage.lavaLevel = storage.lavaLevel - consumeLava
                energy.add(self.energyPerLava * consumeLava)

                animator.setParticleEmitterActive("steam"..i, true)
            else
                animator.setParticleEmitterActive("steam"..i, false)
            end
        else
            animator.setParticleEmitterActive("steam"..i, false)
        end
    end
end

function update(dt)
    pipes.update(dt)

    pullLava()
    generate(dt)
    updateAnimationState()

    energy.update(dt)
end
