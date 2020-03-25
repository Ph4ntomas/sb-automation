function init(virtual)
    storage.variant = storage.variant or "default"
    animator.setAnimationState("relayState", config.getParameter("relayType").."."..storage.variant)
    energy.init()
end

function die()
    energy.die()
end

function energy.isRelay()
    return true
end

function onEnergyNeedsCheck(needDesc)
    needDesc.needs[tostring(entity.id())] = -1 -- -1 is just a hack to mark relays for ordering
    return energy.queryNeeds(needDesc)
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
