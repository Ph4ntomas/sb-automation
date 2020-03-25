require '/scripts/sfutil.lua'
require '/scripts/sfenergy/messages.lua'

energy = {}

-- Local functions
local function getFromArgOrParameter(args, key, default)
    arg = args[key]
    
    if arg == nil then
        arg = config.getParameter(key, default)
    end

    return arg
end

local function blockHash(pos)
    return sb.print("%s,%s", pos[1], pos[2])
end

local function setupIgnoredBlocks()
        local ignoredBlocks = config.getParameter("energyCollisionBlocks", nil)
        if ignoredBlocks then
            energy.ignoredBlocks = {}
            for i, block in pairs(ignoredBlocks) do
                local hash = blockHash(object.toAbsolutePosition(block))
                energy.ignoredBlocks[hash] = true
            end
        end
end

local function showTransferEffect(id)
    if not energy.transferShown[id] then
        local config = energy.connections[id]
        world.spawnProjectile("sfenergytransfer", config.src, entity.id(), config.aim, false, {speed=config.speed})
        energy.transferShown[id] = true
    end
end

local function ignoreCollision(pos, srcIgnoredBlocks, tarIgnoredBlocks)
    if not pos then return true end

    local posHash = blockHash(pos)

    return (srcIgnoredBlocks and srcIgnoredBlocks[blockHash]) or (tarIgnoredBlocks and tarIgnoredBlocks[blockHash])
end

local function checkLignOfSight(src, tar, id)
    local ptarIgnoredBlocks = sfutil.safe_await(world.sendEntityMessage(id, "energy.getIgnoredBlocks"))
    local srcIgnoredBlocks = energy.getIgnoredBlocks()
    local tarIgnoredBlocks = ptarIgnoredBlocks:succeeded() and ptarIgnoredBlocks:result()
    local collisions = world.collisionBlocksAlongLine(src, tar)

    for _, collision in ipairs(collisions) do
        if not ignoreCollision(collision, srcIgnoredBlocks, tarIgnoredBlocks) then
            local material = world.material(collision, "foreground")
            if material then
                local conf = root.materialConfig(material)

                if conf == nil or conf["config"]["renderParameters"] == nil or not conf["config"]["renderParameters"]["lightTransparent"] then
                    return true
                end
            end
        end
    end
    
    return false
end

local function searchConnections(dt)
    if energy.connectionSearchCooldown > 0 then
        energy.connectionSearchCooldown = energy.connectionSearchCooldown - dt
    else
        energy.connections = energy.connections or {}

        local ids = world.objectQuery(energy.nodePosition, energy.linkRange, {
            withoutEntityId = entity.id(),
            callScript = "energy.canConnect",
            order = nearest
        })

        for _, entityId in pairs(ids) do
            energy.connect(entityId)
        end

        energy.connectionSearchCooldown = energy.connectionSearchFreq
    end
end

local function refreshConnectionConfig(id, data, src, tar)
    data.src = src
    data.tar = tar
    data.aim = world.distance(tar, src)
    data.dist = world.magnitude(data.aim)
    data.speed = (data.dist / 1.2)

    return data
end

local function pruneConnections()
    local validConnections = {}

    for id, data in pairs(energy.connections) do
        if world.entityExists(id) then
            local ptarPos = sfutil.safe_await(world.sendEntityMessage(id, "energy.getNode"))
            local tarPos = (ptarPos:succeeded() and ptarPos:result()) or nil

            if tarPos then
                refreshConnectionConfig(id, data, energy.getNode(), tarPos)

                if data.dist <= energy.linkRange then
                    validConnections[id] = data
                else
                    energy.disconnect(id)
                end
            end
        end
    end

    return validConnections
end

local function checkConnections(dt)
    if energy.linkCheckCooldown > 0 then
        energy.linkCheckCooldown = energy.linkCheckCooldown - dt
    else
        energy.connections = pruneConnections()

        for id, data in pairs(energy.connections) do
            data.blocked = checkLignOfSight(energy.getNode(), data.tar, id)
        end

        energy.linkCheckCooldown = energy.linkCheckFreq
    end
end

local function addSortedConn(id)
    energy.sortedConn = energy.sortedConn or {}
    local conf = energy.connections[id]
    local idx = #energy.sortedConn + 1

    for i, id in ipairs(energy.sortedConn) do
        local conf2 = energy.connections[id]

        if conf.relay == conf2.relay then
            if conf.dist < conf2.dist then
                idx = i
                break
            end
        elseif conf2.relay and not conf.relay then
            idx = i
            break
        end
    end
    table.insert(energy.sortedConn, idx, id)
end

local function addConnection(id)
    energy.connections = energy.connections or {}
    local ret = false

    if energy.connections[id] == nil then
        local ptarPos = sfutil.safe_await(world.sendEntityMessage(id, "energy.getNode"))
        local prelay = sfutil.safe_await(world.sendEntityMessage(id, "energy.isRelay"))
        local tar = ptarPos:succeeded() and ptarPos:result() or nil

        local config = refreshConnectionConfig(id, {}, energy.getNode(), tar)
        config.relay = (prelay:succeeded() and prelay:result()) or false

        ret = config.dist <= energy.linkRange

        if ret then
            energy.connections[id] = config
            addSortedConn(id)
        end
    end

    return ret
end

local function removeSortedConn(id)
    for i, id in ipairs(energy.sortedConn) do
        table.remove(energy.sortedConn, i)
        break
    end
end

local function removeConnection(id)
    removeSortedConn(id)
    energy.connections[id] = nil
end

local function compareNeeds(lhs, rhs)
    return lhs.need < rhs.need
end

local function sortNeeds(needs)
    local sortedNeeds = {}

    for id, need in pairs(needs) do
        sortedNeeds[#sortedNeeds + 1] = {id = id, need = need}
    end
    table.sort(sortedNeeds, compareNeeds)

    return sortedNeeds
end


-- Debug functions
local function debugShowConnections()
    for id, conf in pairs(energy.connections) do
        world.debugLine(conf.src, conf.tar, not conf.blocked and "green" or "red")
    end
end

local function debugShowAvailable()
    sb.setLogMap(string.format("%s no%d energy", object.name(), entity.id()), "get : %s, available : %s", energy.get(), energy.getAvailable())
    sb.setLogMap(string.format("%s no%d capacity", object.name(), entity.id()), "unused : %s/%s", energy.getUnusedCapacity(), energy.getCapacity())
end

-- !Debug functions
-- !Local functions

-- Hooks Functions
local hooks = {}

function hooks.onEnergyChange(oldVal, newVal)
    return onEnergyChange and onEnergyChange(oldVal, newVal)
end

function hooks.onEnergyNeedsCheck(needDesc)
    return onEnergyNeedsCheck and onEnergyNeedsCheck(needDesc)
end

function hooks.onEnergySendCheck()
    return onEnergySendCheck and onEnergySendCheck()
end

function hooks.onEnergySent(amount)
    return onEnergySent and onEnergySent(amount)
end

function hooks.onEnergyReceived(amount)
    return onEnergyReceived and onEnergyReceived(amount)
end
-- !Hooks Functions

-- Standard functions
function energy.init(args)
    local pos = entity.position()

    if not args then
        args = {}
    end

    energy.fuelConversion = 100

    energy.allowConnection = getFromArgOrParameter(args, "energyAllowConnection", true)
    energy.capacity = getFromArgOrParameter(args, "energyCapacity", 0)
    energy.generationRate = getFromArgOrParameter(args, "energyGenerationRate", 0)
    energy.consumptionRate = getFromArgOrParameter(args, "energyConsumptionRate", 0)
    energy.sendRate = getFromArgOrParameter(args, "energySendRate", 0)
    energy.sendFreq = getFromArgOrParameter(args, "energySendFreq", 0.5)

    energy.linkRange = getFromArgOrParameter(args, "energyLinkRange", 10)
    energy.linkCheckFreq = getFromArgOrParameter(args, "energyLinkCheckFreq", 0.5)
    energy.linkCheckCooldown = energy.linkCheckFreq
    energy.connectionSearchFreq = getFromArgOrParameter(args, "connectionSearchFreq", energy.linkCheckFreq * 8)
    energy.connectionSearchCooldown = 0

    energy.connections = {}
    energy.sortedConn = {}

    local nodeOffset = getFromArgOrParameter(args, "energyNodeOffset", {0.5, 0.5})
    energy.nodePosition = {pos[1] + nodeOffset[1], pos[2] + nodeOffset[2]}

    energy.sendCooldown = energy.sendFreq

    energy.transferFreq = 0.45
    energy.transferCooldown = energy.transferFreq
    energy.transferShown = {}

    storage._sfenergy = {}
    storage._sfenergy.curEnergy = storage._sfenergy.curEnergy or getFromArgOrParameter(args, "savedEnergy", 0)

    setupIgnoredBlocks()

    sfMessageHooks.energy.init()
end

function energy.update(dt)
    if energy.allowConnection then
        searchConnections(dt)
        checkConnections(dt)
        debugShowConnections()
    end

    if energy.transferCooldown < 0 then
        energy.transferShown = {}
        energy.transferCooldown = energy.transferFreq
    else
        energy.transferCooldown = energy.transferCooldown - dt
    end

    --debugShowAvailable()

    if energy.sendRate > 0 then
        energy.sendCooldown = energy.sendCooldown - dt

        while energy.sendCooldown <= 0 do
            local toSend = math.min(energy.getAvailable(), energy.sendRate * energy.sendFreq)

            if toSend > 0 then
                energy.send(toSend)
            end
            energy.sendCooldown = energy.sendCooldown + energy.sendFreq
        end
    end
end

function energy.die()
    for id, _ in pairs(energy.connections) do
        energy.disconnect(id)
    end
end
-- !Standard functions

-- Primitives
function energy.get()
    return storage._sfenergy.curEnergy
end

function energy.set(amount)
    amount = amount or 0
    amount = (amount >= 0 and amount) or 0

    if amount ~= energy.get() then
        local old = storage._sfenergy.curEnergy
        storage._sfenergy.curEnergy = amount

        hooks.onEnergyChange(old, energy.get())
    end
end

function energy.add(amount)
    amount = math.min(amount, energy.getUnusedCapacity())

    energy.set(energy.get() + amount)

    return amount
end

function energy.remove(amount)
    amount = math.min(amount, energy.get())

    energy.set(energy.get() - amount)

    return amount
end
-- !Primitives

-- Capacity Management
function energy.getAvailable()
    return hooks.onEnergySendCheck() or energy.get()
end

function energy.getNeeds(needDesc)
    local nd = hooks.onEnergyNeedsCheck(needDesc)

    if not nd then
        local need = energy.getUnusedCapacity()
        nd = needDesc

        nd.total = nd.total + need
        nd.needs[tostring(entity.id())] = need
    end
    
    return nd
end

function energy.getCapacity()
    return energy.capacity
end

function energy.getUnusedCapacity()
    return energy.capacity - energy.get()
end
-- !Capacity managment

-- Energy Managment
function energy.queryNeeds(needDesc)
    for i, id in ipairs(energy.sortedConn) do
        local config = energy.connections[id]
        if not needDesc.needs[tostring(id)] and not config.blocked then
            local pneed = sfutil.safe_await(world.sendEntityMessage(id, "energy.getNeeds", needDesc))
            local newNeedDesc = (pneed:succeeded() and pneed:result()) or nil
            local prevTotal = needDesc.total

            needDesc = newNeedDesc or needDesc

            if prevTotal < needDesc.total then
                showTransferEffect(id)
            end
        end
    end
    return needDesc
end

function energy.send(amount)
    local needDesc = {total = 0, source = entity.id(), needs = {}}
    needDesc = energy.queryNeeds(needDesc)

    local needs = sortNeeds(needDesc.needs)
    local toSend = amount
    local remains = toSend

    while #needs > 0 do
        if needs[1].need > 0 then
            local amount = remains / #needs
            local paccepted = sfutil.safe_await(
                world.sendEntityMessage(tonumber(needs[1].id), "energy.receive", amount)
            )
            local accepted = (paccepted:succeeded() and paccepted:result()) or 0

            if accepted > 0 then
                remains = remains - accepted
            end
        end

        table.remove(needs, 1)
    end

    local sent = toSend - remains
    energy.remove(sent)

    hooks.onEnergySent(sent)
end

function energy.receive(amount)
    return hooks.onEnergyReceived(amount) or energy.add(amount)
end

function energy.generate(dt)
    local amount = energy.generationRate * (dt or 0)
    return energy.add(amount)
end

function energy.consume(dt, amount, test)
    amount = amount or (energy.consumptionRate * (dt or 0))

    if amount <= energy.get() then
        if not test then energy.remove(amount) end
        return true
    else
        return false
    end
end
-- !Energy Management

-- Connection Handling
-- Active end
function energy.connect(entityId)
    if addConnection(entityId) then
        world.sendEntityMessage(entityId, "energy.onConnect", entity.id())
    end
end

function energy.disconnect(entityId)
    world.sendEntityMessage(entityId, "energy.onDisconnect", entity.id())
    removeConnection(entityId)
end
-- Active end

-- Callback
function energy.onConnect(entityId)
    addConnection(entityId)
end

function energy.onDisconnect(entityId)
    removeConnection(entityId)
end
-- !Callback
-- !Connection Handling

-- Capabilities Chack
function energy.canReceive()
    return energy.getUnusedCapacity() > 0
end

function energy.canConnect()
    return energy.allowConnection
end
-- !Capabilities Check

-- Nodes & projectiles
function energy.getNode()
    return energy.nodePosition
end

function energy.getIgnoredBlocks()
    return energy.ignoredBlocks
end
-- !Nodes & projectiles
