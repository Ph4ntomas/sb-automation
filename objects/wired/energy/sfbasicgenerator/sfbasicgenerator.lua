function init()
    energy.init()

    self.fuelValues = config.getParameter("fuelValues") or {
      coalore=2,
      uraniumore=4,
      uraniumrod=4,
      plutoniumore=6,
      plutoniumrod=6,
      solariumore=8,
      solariumrod=8
    }

    self.fuelMax = 50

    if storage.fuel == nil then
      if config.getParameter("initialFuel") then
        storage.fuel = config.getParameter("initialFuel")
      else
        storage.fuel = 0
      end
    end

    self.fuelUseRate = 0.2

    local pos = entity.position()
    self.itemPickupArea = {
      {pos[1] - 1, pos[2] - 1},
      {pos[1] + 1, pos[2]}
    }
    self.dropPoint = {pos[1] + 2, pos[2] + 1}

    --used to track items we spit back out
    self.ignoreDropIds = {}

    object.setInteractive(not object.isInputNodeConnected(0))

    -- profilerApi.init()
end

function die()
  local position = entity.position()
  if storage.fuel == 0 then
    world.spawnItem("sfbasicgenerator", {position[1] + 2, position[2] + 1}, 1)
  else
    world.spawnItem("sfbasicgenerator", {position[1] + 2, position[2] + 1}, 1, {initialFuel=storage.fuel})
  end

  energy.die()
end

function onNodeConnectionChange()
  checkNodes()
end

function onInputNodeChange(args)
  checkNodes()
end

function onInteraction(args)
  -- if world.entityHandItem(args.sourceId, "primary") == "profilertool" then
  --   profilerApi.logData()
  --   return
  -- end
  if not object.isInputNodeConnected(0) then
    if storage.state then
      storage.state = false
    else
      storage.state = true
    end

    updateAnimationState()
  end
end

function updateAnimationState()
  if storage.state and storage.fuel > 0 then
    animator.setAnimationState("generatorState", "on")
  elseif storage.state then
    animator.setAnimationState("generatorState", "error")
  else
    animator.setAnimationState("generatorState", "off")
  end

  animator.resetTransformationGroup("fuelbar")
  animator.transformTransformationGroup("fuelbar", math.min(1, storage.fuel / self.fuelMax), 0, 0, 1, -1.6, 0)
end

function checkNodes()
  local isWired = object.isInputNodeConnected(0)
  if isWired then
    storage.state = object.getInputNodeLevel(0)
    updateAnimationState()
  end
  object.setInteractive(not isWired)
end

--never accept energy from elsewhere
function onEnergyNeedsCheck(needDesc)
    needDesc.needs[entity.id()] = 0
    return needDesc
end

--only send energy while generating (even if it's in the pool... could try revamping this later)
function onEnergySendCheck()
  if storage.state then
    return energy.get()
  else
    return 0
  end
end

function getFuelItems()
  local dropIds = world.itemDropQuery(self.itemPickupArea[1], self.itemPickupArea[2])
  for i, entityId in ipairs(dropIds) do
    if not self.ignoreDropIds[entityId] then
      local itemName = world.entityName(entityId)
      if self.fuelValues[itemName] then
        local item = world.takeItemDrop(entityId, entity.id())
        if item then
          if self.fuelValues[item.name] then
            while item.count > 0 and storage.fuel < self.fuelMax do
              storage.fuel = storage.fuel + self.fuelValues[item.name]
              item.count = item.count - 1
            end
          end

          if item.count > 0 then
            ejectItem(item)
          end
        end
      else
        self.ignoreDropIds[entityId] = true
      end
    end
  end
  updateAnimationState()
end

function ejectItem(item)
  local itemDropId
  if item.parameters == nil or next(item.parameters) == nil then
    itemDropId = world.spawnItem(item.name, self.dropPoint, item.count)
  else
    itemDropId = world.spawnItem(item.name, self.dropPoint, item.count, item.parameters)
  end
  self.ignoreDropIds[itemDropId] = true
end

function generate(dt)
  local tickFuel = self.fuelUseRate * dt

  if storage.fuel >= tickFuel then
    storage.fuel = storage.fuel - tickFuel
    energy.add(tickFuel * energy.fuelConversion)
    return true
  elseif storage.fuel > 0 then
    energy.add(storage.fuel * energy.fuelConversion)
    storage.fuel = 0
    return true
  else
    --storage.state = false
    return false
  end
end 

function update(dt)
  if storage.state then
    generate(dt)
    updateAnimationState()
  end

  if storage.fuel < self.fuelMax then
    getFuelItems()
  end

  energy.update(dt)
end
