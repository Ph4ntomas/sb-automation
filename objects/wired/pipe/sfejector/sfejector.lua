local function rotate()
    local position = entity.position()
    local checkDirs = {}
    checkDirs[1] = {-1, 0}
    checkDirs[2] = {0, -1}
    checkDirs[3] = {1, 0}
    checkDirs[4] = {0, 1}

    local angles = {}
    for i = 0, 3 do
        angles[i + 1] = (math.pi / 2) * i
    end

    if next(pipes.nodeEntities["item"]) then
        for i = 1, 4 do
            if next(pipes.nodeEntities["item"][i]) then
                animator.rotateGroup("ejector", angles[i])
                self.usedNode = i
                return
            end
        end
    end

    -- No entity were found, or pipes.nodeEntities was not properlu set up. Fallback on pipes
    for i = 1, 4 do
        local tilePos = {position[1] + checkDirs[i][1], position[2] + checkDirs[i][2]}
        local pipeDirections = pipes.getPipeTileData("item", tilePos, "foreground")

        if pipeDirections then
            animator.rotateGroup("ejector", angles[i])
            self.usedNode = i
            return
        end
    end
end

function init(virtual)
    pipes.init({itemPipe})

    self.dropPoint = {entity.position()[1] + 0.5, entity.position()[2] + 0.5} --TODO: Temporarily spawn inside until someone bothers adding several drop points based on orientation

    self.usedNode = 0
    rotate()
end

--------------------------------------------------------------------------------
function update(dt)
    pipes.update(dt)

    rotate()
end

function beforeItemPush(item, nodeId)
    if nodeId == self.usedNode then
        return item
    end
end

function onItemPush(item, nodeId)
    if item and nodeId == self.usedNode then
        local position = entity.position()

        if not item.parameters or next(item.parameters) == nil then 
            world.spawnItem(item.name, self.dropPoint, item.count)
        else
            world.spawnItem(item.name, self.dropPoint, item.count, item.parameters)
        end

        return item
    end

    return nil
end
