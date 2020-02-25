prepareState = {}

function prepareState.enterWith(args)
    if args.returnPosition or args.run then return nil end
    return {}
end

function prepareState.update(dt, data)
    if storage.quarry.build then
        if storage.quarry.fakePos == nil then
            if not prepareState.findMarker() then
                return true, 2
            end
        elseif storage.quarry.fakeId == nil then
            if not prepareState.placeStand() then
                return true, 2
            end
        elseif not storage.quarry.holders then
            if not quarryHolders() then
                return true, 2
            end
        else
            if not storage.quarry.id then
                spawnQuarry()
            else
                if not world.entityExists(storage.quarry.id) then
                    storage.quarry.id = false
                end
                
                if storage.quarry.id and storage.quarry.active then
                    self.ishome = false
                    local pos = false

                    if storage.quarry.returnPosition then
                        pos = storage.quarry.returnPosition
                    else
                        pos = toAbsolutePosition(storage.quarry.homePos, {
                            storage.quarry.curX*storage.quarry.dir, storage.quarry.curY
                        })
                    end

                    if  not inPosition(world.distance(pos, world.entityPosition(storage.quarry.id))) then
                        if storage.curEnergy < 1 or self.stuck > 5 then
                            storage.quarry.active = false
                            storage.quarry.returnPosition, storage.quarry.returnDirection, storage.quarry.run = storage.quarry.homePos, 1,nil
                        else
                            storage.quarry.returnPosition, storage.quarry.returnDirection, storage.quarry.run = pos,-1,nil
                        end

                        self.state.pickState( storage.quarry )
                    else
                        storage.quarry.returnDirection, storage.quarry.returnPosition, storage.quarry.run = nil, nil, 1
                        self.state.pickState(storage.quarry)
                    end
                end
            end
        end
    end

    return false
end

function prepareState.findMarker()
    local quarryPos, markerId, dir = object.toAbsolutePosition({0,-1}), false, object.direction()

    for i = 2, self.range, 1 do
        local pos = toAbsolutePosition(quarryPos, {dir*i,0})
        local entityIds = world.entityQuery(pos, 0, {name = "sfquarrymarker"})

        if #entityIds > 0 and world.entityName(entityIds[1]) == "sfquarrymarker" then
            markerId = { entityIds[1], pos}
        end
    end

    local pos, collisionPos = nil, {}

    if markerId then
        pos = markerId[2], object.direction()
    else
        pos = toAbsolutePosition(quarryPos, {dir*self.range,0})
    end

    if dir < 0 then
        collisionPos = { pos[1] - dir*2, pos[2], quarryPos[1] + dir*2, quarryPos[2] + 1 }
    else
        collisionPos = { quarryPos[1] + dir*2, quarryPos[2], pos[1] - dir*2, pos[2] + 1 }
    end

    if not world.rectCollision(collisionPos) then
        if markerId == false or world.breakObject(markerId[1], false) then
            storage.quarry.pos, storage.quarry.fakePos = quarryPos, toAbsolutePosition(pos, {0,1})
            storage.quarry.width = math.ceil(math.abs(world.distance(pos, quarryPos)[1]))-3
            return true
        end
    else
        for _, h in ipairs({0,1}) do
            for i = 2, math.abs(pos[1]-quarryPos[1]), 1 do
                local pos = toAbsolutePosition(quarryPos, {dir*i,h+0.5})

                if not world.pointCollision(pos) then
                    world.spawnProjectile("beam", pos, entity.id(), {0,0}, false, {})
                else
                    break
                end
            end
        end

        storage.quarry.active = false
    end

    return false
end

function prepareState.placeStand()
    local fakeQuarryId = world.placeObject("sfquarry_fake", storage.quarry.fakePos, -object.direction() )
    if fakeQuarryId then
        storage.quarry.fakeId = fakeQuarryId
        return quarryHolders()
    end
    return false
end

