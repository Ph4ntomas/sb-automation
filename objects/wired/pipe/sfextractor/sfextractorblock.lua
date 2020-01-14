function init()
    object.setInteractive(false)
    self.maxHealth = config.getParameter("health")
    if storage.health == nil then storage.health = self.maxHealth end
    local initState = config.getParameter("initState")
    if initState then animator.setAnimationState("blocktype", initState) end
end

function setBlockState(state)
  
end

function damageBlock(amount)
  storage.health = storage.health - amount
  local damage = self.maxHealth - storage.health
  local damageState = tostring(math.min(math.ceil((damage / self.maxHealth) * 5), 5))
  animator.setAnimationState("damage", damageState)
  
  if storage.health <= 0 then
    object.smash()
  end
end
