function init(virtual)
  if not virtual then
    storage.variant = storage.variant or "default"
    animator.setAnimationState("relayState", config.getParameter("relayType").."."..storage.variant)
    energy.init()
  end
end

function die()
  energy.die()
end

function energy.isRelay()
  return true
end

function onEnergyNeedsCheck(energyNeeds)
  energyNeeds[tostring(entity.id())] = -1 -- -1 is just a hack to mark relays for ordering
  return energy.energyNeedsQuery(energyNeeds)
end

function update(dt)
  energy.update(dt)
end

function setRelayVariant(newTag)
  storage.variant = newTag
  animator.setAnimationState("relayState", config.getParameter("relayType").."."..storage.variant)
end

-- this will have to wait until setGlobalTag works properly
-- function setRelayVariant(newTag)
--   --entity.setGlobalTag("variant", "default") --thrashin it like Tony Hawk's Pro Skater
--   entity.setGlobalTag("variant", newTag)
--   return true
-- end
