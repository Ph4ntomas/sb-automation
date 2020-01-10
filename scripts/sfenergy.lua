require '/scripts/sfutil.lua'

function getProjectileSourcePositionHndl(_, _)
    return energy.getProjectileSourcePosition()
end

function isRelayHndl(_, _)
    if not energy.isRelay then
        return false
    end
    return energy.isRelay()
end

function getCollisionBlocksHndl(_, _)
    return energy.getCollisionBlocks()
end

function onConnectHndl(_, _, id)
    return energy.onConnect(id)
end

function onDisconnectHndl(_, _, id)
    return energy.onDisconnect(id)
end

function getEnergyNeedsHndl(_, _, amount)
    return energy.getEnergyNeeds(amount)
end

function receiveEnergyHndl(_, _, amount)
    return energy.receiveEnergy(amount)
end

function removeEnergyHndl(_,_, amount)
    return energy.removeEnergy(amount)
end

energy = {}

function getFromArgOrParameter(args, key, default)
    arg = args[key] 
    param = config.getParameter(key, default)
    return arg or param or default
end

-- Initializes the energy module (MUST BE CALLED IN OBJECT init() FUNCTION)
function energy.init(args)
  if not args then
    args = {}
  end

  --energy per unit of fuel for automated conversions
  energy.fuelEnergyConversion = 100

  --can be used to disallow direct connection (e.g. for battery)
  if not args["energyAllowConnection"] == nil then
      energy.allowConnection = args["energyAllowConnection"]
  else
      energy.allowConnection = config.getParameter("energyAllowConnection", true)
  end

  --capacity of internal energy storage
  energy.capacity = getFromArgOrParameter(args, "energyCapacity", 0)

  --amount of energy generated per second when active
  energy.generationRate = getFromArgOrParameter(args, "energyGenerationRate", 0)

  --amount of energy consumed per second when active
  energy.consumptionRate = getFromArgOrParameter(args, "energyConsumptionRate", 0)

  --current energy storage
  storage.curEnergy = storage.curEnergy or getFromArgOrParameter(args, "savedEnergy", 0)

  --maximum amount of energy transmitted per second
  energy.sendRate = getFromArgOrParameter(args, "energySendRate", 0)

  --frequency (in seconds) to push energy (maybe make this hard coded)
  energy.sendFreq = getFromArgOrParameter(args, "energySendFreq", 0.5)

  --timer variable that tracks the cooldown until next transmission pulse
  energy.sendTimer = energy.sendFreq

  --prevent projectile spam with multiple generators
  energy.transferInterval = 0.45
  energy.transferCooldown = energy.transferInterval
  energy.transferShown = {}

  --define custom source position for energy projectiles and LoS checks
  --NOTE: making this too far from the object's position will result in strange behavior (as it is not used in the initial queries for nearby objects)
  local nodeOffset = getFromArgOrParameter(args, "energyNodeOffset", {0.5, 0.5})
  energy.nodePosition = {entity.position()[1] + nodeOffset[1], entity.position()[2] + nodeOffset[2]}

  --maximum range (in blocks) that this device will search for entities to connect to
  --NOTE: we may not want to make this configurable, since it will result in strange behavior if asymmetrical
  energy.linkRange = getFromArgOrParameter(args, "energyLinkRange", 10)

  --frequency (in seconds) to perform LoS checks on connected entities
  energy.connectCheckFreq = 0.5

  --timer variable that tracks cooldown until next connection LoS check
  energy.connectCheckTimer = energy.connectCheckFreq

  --table to hold id's of connected entities (no point storing this since id's change on reload)
  --  keys are entity id's, values are tables of connection parameters
  energy.connections = {}

  --helper table for energy.connections that sorts the id's in order of proximity/precedence
  energy.sortedConnections = {}

  --flag used to run more initialization the first time main() is called (in energy.update())
  self.energyInitialized = false

  message.setHandler("energy.getProjectileSourcePosition", getProjectileSourcePositionHndl)
  message.setHandler("energy.isRelay", isRelayHndl)
  message.setHandler("energy.getCollisionBlocks", getCollisionBlocksHndl)
  message.setHandler("energy.onConnect", onConnectHndl)
  message.setHandler("energy.onDisconnect", onDisconnectHndl)
  message.setHandler("energy.getEnergyNeeds", getEnergyNeedsHndl)
  message.setHandler("energy.receiveEnergy", receiveEnergyHndl)
  message.setHandler("energy.removeEnergy", removeEnergyHndl)
end

-- Performs per-tick updates for energy module (MUST BE CALLED IN OBJECT main() FUNCTION)
function energy.update(dt)
  if self.energyInitialized then
    --periodically reset projectile anti-spam list
    if energy.transferCooldown > 0 then
      energy.transferCooldown = energy.transferCooldown - dt
      if energy.transferCooldown <= 0 then
        energy.transferShown = {}
        energy.transferCooldown = energy.transferInterval
      end
    end

    --periodic energy transmission pulses
    if energy.sendRate > 0 then
      energy.sendTimer = energy.sendTimer - dt
      while energy.sendTimer <= 0 do
        local energyToSend = math.min(energy.getAvailableEnergy(), energy.sendRate * energy.sendFreq)
        if energyToSend > 0 then
          energy.sendEnergy(energyToSend)
        end
        energy.sendTimer = energy.sendTimer + energy.sendFreq
      end
    end

    --periodic connection checks
    energy.connectCheckTimer = energy.connectCheckTimer - dt
    if energy.connectCheckTimer <= 0 then
      energy.checkConnections()
      energy.connectCheckTimer = energy.connectCheckFreq
    end
  else
    -- create table of locations this object occupies, which will be ignored in LoS checks
    local collisionBlocks = config.getParameter("energyCollisionBlocks", nil)
    if collisionBlocks then
      energy.collisionBlocks = {}
      local pos = entity.position()
      for i, block in ipairs(collisionBlocks) do
        local blockHash = energy.blockHash({block[1] + pos[1], block[2] + pos[2]})
        energy.collisionBlocks[blockHash] = true
      end
    end

    if energy.allowConnection then
      energy.findConnections()
      energy.checkConnections()
    end
    self.energyInitialized = true
  end
end

-- performs any unloading necessary when the object is removed (MUST BE CALLED IN OBJECT die() FUNCTION)
function energy.die()
  for entityId, v in pairs(energy.connections) do
    energy.disconnect(entityId)
  end
end

-------------------------------------------------

-- Returns how much energy the object currently holds
function energy.getEnergy()
  return storage.curEnergy
end

-- sets the current energy pool (and provides a place to update animations, etc.)
function energy.setEnergy(amount)
  if amount ~= energy.getEnergy() then
    storage.curEnergy = amount
    if onEnergyChange then
      onEnergyChange(amount)
    end
  end
end

-- gets the available energy to send
function energy.getAvailableEnergy()
  if onEnergySendCheck then
    return onEnergySendCheck()
  else
    return energy.getEnergy()
  end
end

-- returns the total amount of space in the object's energy storage
function energy.getCapacity()
  return energy.capacity
end

-- returns the amount of free space in the object's energy storage
function energy.getUnusedCapacity()
  return energy.capacity - energy.getEnergy()
end

-- adds the appropriate periodic energy generation based on energyGenerationRate and scriptDelta
-- @returns amount of energy generated
function energy.generateEnergy(dt)
  local amount = energy.generationRate * dt
  --sb.logInfo("generating %f energy", amount)
  return energy.addEnergy(amount)
end

-- Adds the specified amount of energy to the storage pool, to a maximum of <energy.capacity> 
-- @returns the amount added
function energy.addEnergy(amount)
  local newEnergy = energy.getEnergy() + amount
  if newEnergy <= energy.getCapacity() then
    energy.setEnergy(newEnergy)
    return amount
  else
    local addedEnergy = energy.getUnusedCapacity()
    energy.setEnergy(energy.getCapacity())
    return addedEnergy
  end
end

-- reduces the current energy pool by the specified amount, to a minimum of 0
-- @returns the amount of energy removed
function energy.removeEnergy(amount)
  local newEnergy = energy.getEnergy() - amount
  if newEnergy <= 0 then
    energy.setEnergy(0)
    return amount + newEnergy
  else
    energy.setEnergy(newEnergy)
    return amount
  end
end

-- attempt to remove the specified amount of energy
-- @param amount is the amount to consume, or nil to consume the periodic amount
--     as determined by energyConsumptionRate and scriptDelta
-- @param testConsume (optional) if true, will not actually consume energy
-- @returns false if there is insufficient energy stored (and does not remove energy)
function energy.consumeEnergy(dt, amount, testConsume)
  if amount == nil then
    amount = energy.consumptionRate * dt
  end
  if amount <= energy.getEnergy() then
    if not testConsume then energy.removeEnergy(amount) end
    return true
  else
    return false
  end
end

-------------------------------------------------

--Used to determine if device can connect directly to other nodes
function energy.canConnect()
  return energy.allowConnection
end

-- returns true if object is a valid energy receiver
function energy.canReceiveEnergy()
  return energy.getUnusedCapacity() > 0
end

-- compute all the configuration stuff for the connection and projectile effect
-- TODO: divide rather than duplicate this work between connecting objects
function energy.makeConnectionConfig(entityId)
  local config = {}
  local srcPos = energy.getProjectileSourcePosition()
  local ptarPos = sfutil.safe_await(world.sendEntityMessage(entityId, "energy.getProjectileSourcePosition"))
  local tarPos = nil

  if ptarPos:succeeded() then
      tarPos = ptarPos:result()
  end

  config.aimVector = world.distance(tarPos, srcPos) --{tarPos[1] - srcPos[1], tarPos[2] - srcPos[2]}
  config.srcPos = srcPos
  config.tarPos = tarPos
  
  config.distance = world.magnitude(srcPos, tarPos)
  config.speed = (config.distance / 1.2) -- denominator must == projectile's timeToLive
  -- Just leaving the code for solid collision checking there, not not using it for now
  config.blocked = energy.checkLoS(srcPos, tarPos, entityId)
  --config.blocked = world.lineCollision(srcPos, tarPos) -- world.lineCollision is marginally faster
  local prelay = sfutil.safe_await(world.sendEntityMessage(entityId, "energy.isRelay"))
  
  if prelay:succeeded() then
      config.isRelay = prelay:result()
  else
      config.isRelay = false
  end

  -- if config.isRelay then
  --   sb.logInfo("%s %d thinks %d is a relay", config.getParameter("objectName"), entity.id(), entityId)
  --
  -- else
  --   sb.logInfo("%s %d thinks %d is NOT a relay", config.getParameter("objectName"), entity.id(), entityId)
  -- end
  return config
end

-- Check line of sight from one position to another
function energy.checkLoS(srcPos, tarPos, entityId)
  local ignoreBlocksSrc = energy.getCollisionBlocks()
  local pignoreBlocksTar = sfutil.safe_await(world.sendEntityMessage(entityId, "energy.getCollisionBlocks"))
  local ignoreBlocksTar = nil

  if pignoreBlocksTar:succeeded() then
      ignoreBlocksTar = pignoreBlocksTar:result()
  end

  if ignoreBlocksSrc or ignoreBlocksTar or srcPos[1] < energy.linkRange or tarPos[1] < energy.linkRange then
    local collisionBlocks = world.collisionBlocksAlongLine(srcPos, tarPos)
    return energy.checkCollisionBlocks(collisionBlocks, ignoreBlocksSrc, ignoreBlocksTar)
  else
      local collisions = world.collisionBlocksAlongLine(srcPos, tarPos)

      for _, collision in ipairs(collisions) do
          local material = world.material(collision, "foreground")
          local materialConfig = root.materialConfig(material)

          if materialConfig["config"] == nil 
              or materialConfig["config"]["renderParameters"] == nil 
              or not materialConfig["config"]["renderParameters"]["lightTransparent"] then
              return collision
          end
      end
    return false
  end
end

-- Check collision with collision blocks filtered out
function energy.checkCollisionBlocks(collisionBlocks, ignoreBlocksSrc, ignoreBlocksTar)
  for i, colBlock in ipairs(collisionBlocks) do
    local colBlockHash = energy.blockHash(colBlock)
    if not ((ignoreBlocksSrc and ignoreBlocksSrc[colBlockHash]) or (ignoreBlocksTar and ignoreBlocksTar[colBlockHash])) then
      --this block is not ignored by either side
      return true
    end
  end

  --default to false if all blocks are ignored
  return false
end

-- Get collision blocks of this entity
function energy.getCollisionBlocks()
  return energy.collisionBlocks
end

-- Get a stringified representation of a block
function energy.blockHash(blockPos)
  return string.format("%d,%d", blockPos[1], blockPos[2])
end

-- get the source position for the visual effect (TODO: replace with something better)
function energy.getProjectileSourcePosition()
  return energy.nodePosition
end

--adds appropriate entries into energy.connections and energy.sortedConnections
function energy.addToConnectionTable(entityId)
    --sb.logInfo("addToConnectionTable : " .. sb.print(energy.connections))
  if energy.connections[entityId] == nil then
    local cConfig = energy.makeConnectionConfig(entityId)
    energy.connections[entityId] = cConfig

    --insert into the proper place in sortedConnections (ordered by distance, with receivers before relays)
    local insertIndex = false
    for i, cId in ipairs(energy.sortedConnections) do
      local cConfig2 = energy.connections[cId]
      if cConfig.isRelay == cConfig2.isRelay then
        -- sb.logInfo("comparing distance %f to %f", cConfig.distance, cConfig2.distance)
        if cConfig.distance < cConfig2.distance then
          -- if cConfig.isRelay then
          --   sb.logInfo("inserting relays in order of distance")
          -- else
          --   sb.logInfo("inserting non-relays in order of distance")
          -- end
          insertIndex = i
          break
        end
      elseif cConfig2.isRelay and not cConfig.isRelay then
        -- sb.logInfo("inserting after relay")
        insertIndex = i
        break
      end
    end
    if not insertIndex then
      -- sb.logInfo("inserting at end")
      insertIndex = #energy.sortedConnections + 1
    end
    table.insert(energy.sortedConnections, tonumber(insertIndex), entityId)
  end
end

-- connects to the specified entity id
function energy.connect(entityId)
  energy.addToConnectionTable(entityId)
  world.sendEntityMessage(entityId, "energy.onConnect", entity.id())
end

-- callback for energy.connect
function energy.onConnect(entityId)
  -- if self.energyInitialized then
    energy.addToConnectionTable(entityId)
  -- else
  --   sb.logInfo("%s %d wasn't initialized at connection time! hopefully we'll connect later...", config.getParameter("objectName"), entity.id())
  -- end
end

-- removes the appropriate entries from energy.connections and energy.sortedConnections
function energy.removeFromConnectionTable(entityId)
  energy.connections[entityId] = nil
  for i, cId in ipairs(energy.sortedConnections) do
    if cId == entityId then
      table.remove(energy.sortedConnections, i)
      break
    end
  end
  -- sb.logInfo("%s %d disconnected from %d:", config.getParameter("objectName"), entity.id(), entityId)
  -- sb.logInfo(energy.sortedConnections)
end

-- disconnects from the specified entity id
function energy.disconnect(entityId)
  world.sendEntityMessage(entityId, "energy.onDisconnect", entity.id())
  energy.removeFromConnectionTable(entityId)
end

-- callback for energy.disconnect
function energy.onDisconnect(entityId)
  energy.removeFromConnectionTable(entityId)
end

-- Returns a list of connected entity id's
function energy.getConnections()
  return self.energyConnections
end

-- finds and connects to entities within <energy.linkRange> blocks
function energy.findConnections()
  energy.connections = {}
  energy.sortedConnections = {}

  --find nearby energy devices within LoS
  local entityIds = world.objectQuery(entity.position(), energy.linkRange, { 
      withoutEntityId = entity.id(),
      callScript = "energy.canConnect",
      order = "nearest"
    })

    --sb.logInfo("found connections : " .. sb.print(entityIds))

  --connect
  for i, entityId in ipairs(entityIds) do
    energy.connect(entityId)
  end

  -- sb.logInfo("%s %d found %d entities within range:", config.getParameter("objectName"), entity.id(), #entityIds)
  -- sb.logInfo(entityIds)
  -- sb.logInfo(energy.sortedConnections)
end

-- performs periodic LoS checks on connected entities
function energy.checkConnections()
  --sb.logInfo("checking connections ...")
  for entityId, pConfig in pairs(energy.connections) do
    energy.connections[entityId].blocked = energy.checkLoS(pConfig.srcPos, pConfig.tarPos, entityId)
  end
end

-- returns the empty capacity (for consumers) or a Very Large Number TM for relays
function energy.getEnergyNeeds(energyNeeds)
  if onEnergyNeedsCheck then
    return onEnergyNeedsCheck(energyNeeds)
  else
    energyNeeds["total"] = energyNeeds["total"] + energy.getUnusedCapacity()
    energyNeeds[tostring(entity.id())] = energy.getUnusedCapacity()
    return energyNeeds
  end
end

-- comparator function for table sorting
function energy.compareNeeds(a, b)
  if a == -1 then
    return false -- used to move relays to the end of the list
  else
    return a[2] < b[2]
  end
end

-- traverse the tree and build a list of receivers requesting energy
function energy.energyNeedsQuery(energyNeeds)
  -- check energy needs for all connected entities
  for i, entityId in ipairs(energy.sortedConnections) do
    if not energyNeeds[tostring(entityId)] and not energy.connections[entityId].blocked then
      local prevTotal = energyNeeds["total"]

      local pnewEnergyNeeds = sfutil.safe_await(world.sendEntityMessage(entityId, "energy.getEnergyNeeds", energyNeeds))
      local newEnergyNeeds = nil

      if pnewEnergyNeeds:succeeded() then
          newEnergyNeeds = pnewEnergyNeeds:result()
      end

      if newEnergyNeeds then
        energyNeeds = newEnergyNeeds
      end
      
      -- if energyNeeds[tostring(entityId)] == nil then
      --   sb.logInfo("%s %d failed to add itself to energyNeeds table", world.callScriptedEntity(entityId, "config.getParameter", "objectName"), entityId)
      -- end
      
      if energyNeeds["total"] > prevTotal then
        energy.showTransferEffect(entityId)
      end
    end
  end

  return energyNeeds
end

-- callback for receiving incoming energy pulses
function energy.receiveEnergy(amount)
  --sb.logInfo("%s %d receiving %d energy...", config.getParameter("objectName"), entity.id(), amount)
  if onEnergyReceived then
    return onEnergyReceived(amount)
  else
    return energy.addEnergy(amount)
  end
end

-- pushes energy to connected entities. amount is divided "fairly" between the valid receivers
function energy.sendEnergy(amount)
  if config.getParameter("objectName") ~= "sfrelay" then
    --sb.logInfo("%s %s sending %s energy...", config.getParameter("objectName"), entity.id(), amount)
  end

  -- get the network's energy needs
  local energyNeeds = {total=0, sourceId=entity.id()}
  energyNeeds[tostring(entity.id())] = 0
  energyNeeds = energy.energyNeedsQuery(energyNeeds)
  energyNeeds["total"] = nil
  energyNeeds["sourceId"] = nil

  -- build and sort a table from least to most energy requested
  local sortedEnergyNeeds = {}
  for entityId, thisNeed in pairs(energyNeeds) do
    sortedEnergyNeeds[#sortedEnergyNeeds + 1] = {entityId, thisNeed}
  end
  table.sort(sortedEnergyNeeds, energy.compareNeeds)

  -- process list and distribute remainder evenly at each step
  local totalEnergyToSend = amount
  local remainingEnergyToSend = totalEnergyToSend
  while #sortedEnergyNeeds > 0 do
    if sortedEnergyNeeds[1][2] > 0 then
      local sendAmt = remainingEnergyToSend / #sortedEnergyNeeds
      local pacceptedEnergy = sfutil.safe_await(world.sendEntityMessage(tonumber(sortedEnergyNeeds[1][1]), "energy.receiveEnergy", sendAmt))
      local acceptedEnergy = -1

      if pacceptedEnergy:succeeded() then
          acceptedEnergy = pacceptedEnergy:result()
      end


      if acceptedEnergy > 0 then
        remainingEnergyToSend = remainingEnergyToSend - acceptedEnergy
      end
    end
    table.remove(sortedEnergyNeeds, 1)
  end

  --remove the total amount of energy sent
  local totalSent = totalEnergyToSend - remainingEnergyToSend
  energy.removeEnergy(totalSent)

  --call hook for objects to update animations, etc
  if onEnergySend then onEnergySend(totalSent) end
end

-- display a visual indicator of the energy transfer
function energy.showTransferEffect(entityId)
  if not energy.transferShown[entityId] then
    local config = energy.connections[entityId]
    world.spawnProjectile("sfenergytransfer", config.srcPos, entity.id(), config.aimVector, false, { speed=config.speed })
    energy.transferShown[entityId] = true
  end
end
