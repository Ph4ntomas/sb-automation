function init()
    self.convertLiquid = config.getParameter("liquidConversions")
    pipes.init({liquidPipe})
    self.usedNode = 0
end

--------------------------------------------------------------------------------
function update(dt)
    pipes.update(dt)

    local position = entity.position()
    local checkDirs = {}

    checkDirs[0] = {-1, 0}
    checkDirs[1] = {0, -1}
    checkDirs[2] = {1, 0}
    checkDirs[3] = {0, 1}

    if #pipes.nodeEntities["liquid"] > 0 then
        for i=0,3 do 
            local angle = (math.pi / 2) * i

            if #pipes.nodeEntities["liquid"][i+1] > 0 then
                animator.rotateGroup("pipe", angle)
                self.dir = {checkDirs[i][1] * -1, checkDirs[i][2] * -1}
            elseif i == 3 then --Not connected to an object, check for pipes instead
                for i=0,3 do 
                    local angle = (math.pi / 2) * i
                    local tilePos = {position[1] + checkDirs[i][1], position[2] + checkDirs[i][2]}
                    local pipeDirections = pipes.getPipeTileData("liquid", tilePos, "foreground")

                    if pipeDirections then
                        animator.rotateGroup("pipe", angle)
                        self.dir = {checkDirs[i][1] * -1, checkDirs[i][2] * -1}
                    end
                end
            end
        end
    end
end

function convertEndlessLiquid(liquid)
    local endless = false

    if self.convertLiquid[liquid.name] ~= nil then
        liquid.name = self.convertLiquid[liquid.name]
        endless = true
    end

    return liquid, endless
end

function canGetLiquid(filter, nodeId)
    local position = entity.position()
    local liquidPos = { position[1] + 0.5, position[2] + 0.5 }
    local availableLiquid = world.liquidAt(liquidPos)

    if availableLiquid then
        local liquid = {name = availableLiquid[1], count = availableLiquid[2]}
        local convertedLiquid = convertEndlessLiquid(liquid)

        return convertedLiquid
    end

    return nil, nil
end

function beforeLiquidGet(filter, nodeId)
    local liquid, _ = canGetLiquid(filter, nodeId)
    return liquid
end

function onLiquidGet(filter, nodeId)
    local position = entity.position()
    local liquidPos = {position[1] + 0.5, position[2] + 0.5}
    local getLiquid, endless = canGetLiquid(filter, nodeId)

    if getLiquid then
        if not endless then
            local destroyed = world.destroyLiquid(liquidPos)

            if destroyed[2] > getLiquid.count then
                world.spawnLiquid(liquidPos, destroyed[1], destroyed[2] - getLiquid.count)
            end
        end

        return getLiquid
    end

    return nil
end

function canPutLiquid(liquid, nodeId)
    return liquid
end

function beforeLiquidPut(liquid, nodeId)
    return canPutLiquid(liquid, nodeId)
end

function onLiquidPut(liquid, nodeId)
    local position = entity.position()
    local liquidPos = {position[1] + 0.5, position[2] + 0.5}

    if canPutLiquid(liquid, nodeId) then
        local curLiquid = world.liquidAt(liquidPos)

        if curLiquid then 
            liquid.count = liquid.count + curLiquid[2]
        end

        world.spawnLiquid(liquidPos, liquid.name, liquid.count)
        return liquid
    else
        return nil
    end
end

