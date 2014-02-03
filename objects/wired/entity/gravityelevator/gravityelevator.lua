function init(virtual)
   if not self.number and not virtual then
      energy.init()
      self.gravityForce, self.countdown, self.number = entity.configParameter("gravityForce"), 15, -1
      if self.direction == nil then
         storage.state, self.direction, self.animation = false, 0, "back"
         if entity.configParameter("anchors")[1] == "top" then
            self.direction = -1
            self.animation = "top"
         elseif entity.configParameter("anchors")[1] == "bottom" then
            self.direction = 1
            self.animation = "bottom"
         end
      end
      entity.setInteractive(true)
      entity.setAnimationState("beamState", "off")
      onEnergyChange(storage.curEnergy)
   end
end

function onInteraction()
   startGravityShaft({direction = self.direction, number = -1})
end

function onEnergyChange(amount)
   if amount < energy.consumptionRate then
      entity.setGlobalTag("modePart", "energy")
   else
      entity.setGlobalTag("modePart", "default")
   end
   entity.setAnimationState("gravelevatorState", self.animation)
end

function consumeEnergy()
   if self.number == 0 then
      local energyn = energy.consumptionRate
      if self.checkedForPlayer then
         energyn = energyn * 5
      end
      if not energy.consumeEnergy(energyn) then
         entity.setGlobalTag("modePart", "energy")
         storage.state = false
         return false
      end
   end
   return true
end

function main()
   energy.update()
   if storage.state and consumeEnergy() then
      local force = self.forceRegion or checkForceRegion()
      setForce()
      if self.countdown == 0 then
         if isConnected() then
            self.checkedForPlayer, self.countdown = nil, 5
         else
            storage.state = false
            self.connectedShaft, self.setDirection, self.countdown = nil, nil, 15
         end
      else
         self.countdown = self.countdown - 1
      end
      if not self.checkedForPlayer and self.connectedShaft and checkForPlayer() then
         world.callScriptedEntity(self.connectedShaft, "startGravityShaft", { direction = getDirection(), number = self.number })
         self.checkedForPlayer, self.countdown = true, 5
      end
   elseif self.lastProj then
      if not world.entityExists(self.lastProj) then
         self.lastProj, self.proj = nil, nil
         entity.setAnimationState("beamState", "off")
      end
   end
end

function canConnectGravityShaft(direction)
   --world.logInfo("canConnectGravityShaft %s own %s", direction, self.direction)
   local con = false
   if self.direction == 0 or self.direction == direction then
      self.setDirection, con = direction, true
   end
   return {con, entity.position()[2]}
end

function startGravityShaft(args)
   self.number = args.number + 1
   storage.state = true
   self.forceRegion, self.checkedForPlayer, self.setDirection = false, nil, args.direction or self.direction
   return true
end

function checkForPlayer()
   local dir = getDirection()
   if #world.playerQuery(entity.toAbsolutePosition({2, (self.size)*dir-dir}), 2) > 0 then
      return true
   end
   return false
end

function checkForceRegion()
   local gravityRange, dir, pos = entity.configParameter("gravityRange"), getDirection(), entity.position()
   if dir == -1 then
      gravityRange[2] = -gravityRange[2]
   end
   local endPos = entity.toAbsolutePosition({gravityRange[1], gravityRange[2]})

   local entities  = world.entityLineQuery(
      pos,
      {pos[1], endPos[2] + dir },
      {
         callScript = "isGravityShaft",
         withoutEntityId = entity.id()
      }
   )
   --world.logInfo("checkForceRegion entities %s (%s - %s)", entities, pos, endPos)
   if #entities > 0 then
      local entity, distance = entities[1], 100
      if #entities > 1 then
         for _, entityId in ipairs(entities) do
            local entPos = world.entityPosition(entityId)
            if (dir > -1 and pos[2] < entPos[2]) or (dir == -1 and pos[2] > entPos[2]) then
               local dis = math.abs(world.distance(pos, entPos)[2])
               if dis < distance then
                  distance = dis
                  entity = entityId
               end
            end
         end
      end
      local canConnect = world.callScriptedEntity(entity, "canConnectGravityShaft", dir)
      if canConnect and canConnect[1] then
         self.connectedShaft = entity
      end
      if canConnect and canConnect[2] then
         endPos[2] = canConnect[2] - dir
      end
   end
   if dir == -1 then
      self.forceRegion = { pos[1], endPos[2]+1, endPos[1], pos[2] }
   else
      self.forceRegion = { pos[1], pos[2]+dir, endPos[1], endPos[2] }
   end
   self.size = math.abs(self.forceRegion[4] - self.forceRegion[2]+1)
   return self.forceRegion
end

function getDirection()
   local dir = self.setDirection or self.direction or 1
   if dir == 0 then dir = 1 end
   return dir
end

function setForce(force)
   force = force or self.gravityForce
   local dir, regio = getDirection(), {}
   if dir > 0 then
      force = math.max(force[1][1] - self.number*force[1][2], force[1][3])
      regio = {self.forceRegion[1]+2, self.forceRegion[2]}
      entity.setAnimationState("beamState", "up")
      entity.scaleGroup("beam", {1, (self.size+1)*8})
   else
      force = math.min(force[2][1] + self.number*force[2][2], force[2][3])
      regio = { self.forceRegion[1]+2, self.forceRegion[4] }
      entity.setAnimationState("beamState", "down")
      entity.scaleGroup("beam", {-1, -(self.size+1)*8})
   end

   if not self.proj or self.proj >= self.size/2 then
      self.proj = 0
      self.lastProj = world.spawnProjectile("gravityelevator", regio, entity.id(), {0, dir}, false, { timeToLive = self.size/5 })
   else
      self.proj = self.proj + 1
   end

   force = force * (world.gravity({self.forceRegion[1],self.forceRegion[2]})/100)
   entity.setForceRegion(self.forceRegion, {0, force})
end

function onNodeConnectionChange()
   checkNodes()
end

function onInboundNodeChange()
   checkNodes()
end

function isConnected()
   return entity.getInboundNodeLevel(0) or entity.getInboundNodeLevel(1)
end

function checkNodes()
   if entity.getInboundNodeLevel(0) then
      --world.logInfo("getInboundNodeLevel %s", 1)
      local dir = self.direction
      if dir == 0 then dir = 1 end
      return startGravityShaft({direction = dir, number = -1})
   end
   if entity.getInboundNodeLevel(1) then
      --world.logInfo("getInboundNodeLevel %s", 2)
      local dir = self.direction
      if dir == 0 then dir = -1 end
      return startGravityShaft({direction = dir, number = -1})
   end
end

function isGravityShaft()
   return true
end

function die()
   energy.die()
end