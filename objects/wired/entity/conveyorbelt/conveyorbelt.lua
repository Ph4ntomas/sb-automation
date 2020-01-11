function init(v)
  energy.init()
  if storage.active == nil then storage.active = false end
  setActive(storage.active)
  self.workSound = entity.configParameter("workSound")
  self.moveSpeed = entity.configParameter("moveSpeed")
  self.st = 0
  onNodeConnectionChange(nil)
end

function die()
  energy.die()
end

function onNodeConnectionChange(args)
  if entity.isInputNodeConnected(0) then
    entity.setInteractive(false)
  else
    entity.setInteractive(true)
  end
  onInputNodeChange(args)
end

function onInputNodeChange(args)
  if entity.isInputNodeConnected(0) then
    setActive(entity.getInputNodeLevel(0))
  end
end

function onInteraction(args)
  setActive(not storage.active)
end

function setActive(flag)
  if not flag or energy.consumeEnergy(nil, true) then
    storage.active = flag
    if flag then entity.setAnimationState("workState", "work")
    else entity.setAnimationState("workState", "idle") end
  end
end

function main()
  energy.update(dt)
  if storage.active then
    if not energy.consumeEnergy() then
      setActive(false)
      return
    end

    self.st = self.st + 1
    if self.st > 7 then 
      self.st = 0
    elseif self.st == 3 then
      entity.playImmediateSound(self.workSound)
    end
    local p = object.toAbsolutePosition({ -1.8, 1 })
    entity.setForceRegion({ p[1], p[2], p[1] + 3.6, p[2] }, { self.moveSpeed * entity.direction(), 0})
  end
end
