function init()  
  object.setInteractive(true)
    pipes.init({liquidPipe})
    local initInv = config.getParameter("initialInventory")
    if initInv and storage.liquid == nil then
      storage.liquid = initInv
    end
    
    animator.resetTransformationGroup("liquid")
    animator.scaleTransformationGroup("liquid", {1, 0})

    --TODO use root function to get this
    self.liquidMap = {}
    self.liquidMap[1] = "water"
    self.liquidMap[2] = "lava"
    self.liquidMap[4] = "poison"
    self.liquidMap[6] = "juice"
    self.liquidMap[7] = "tar"
    
    self.capacity = config.getParameter("liquidCapacity")
    self.pushAmount = config.getParameter("liquidPushAmount")
    self.pushRate = config.getParameter("liquidPushRate")
    
    if storage.liquid == nil then storage.liquid = {} end
    
    self.pushTimer = 0
    self.occupied = false
end

function die()
  local position = entity.position()
  if storage.liquid.name ~= nil then
    world.spawnItem("sfsubmersiontank", {position[1] + 1.5, position[2] + 1}, 1, {initialInventory = storage.liquid})
  else
    world.spawnItem("sfsubmersiontank", {position[1] + 1.5, position[2] + 1}, 1)
  end
end

-- legacy function, soon to be removed
--function onInteraction(args)
  --local liquid = self.liquidMap[storage.liquid.name]
  --local count = storage.liquid.count
  --local capacity = self.capacity
  --local itemList = ""
  
  --if liquid == nil then liquid = "other" end
  --if count ~= nil then 
    --return { "ShowPopup", { message = "^white;You manage to suppress the desire to climb into the tank... for now.\n\n^white;Holding ^green;" .. count ..
      --"^white; / ^green;" .. capacity ..
      --"^white; units of liquid ^green;" .. liquid
    --}}
  --else
      --return { "ShowPopup", { message = "Tank is empty."}}
  --end
--end

function onInteraction(args)
    local liquid = self.liquidMap[storage.liquid.name]
    local count = storage.liquid.count
    local capacity = self.capacity
    local itemList = ""

    if liquid == nil then liquid = "other" end

    if not world.loungeableOccupied(entity.id()) then
        if count ~= nil and count < capacity then 
            return { "ShowPopup", { message = "^white;You manage to suppress the desire to climb into the tank... for now.\n\n^white;Holding ^green;" .. count ..
                "^white; / ^green;" .. capacity ..
                "^white; units of liquid ^green;" .. liquid
            }}
        elseif count ~= nil then
            return { "SitDown", 0} --,{config={
            --["sitFlipDirection"] = false,
            --["sitPosition"] = {20,20},
            --["sitOrientation"] = "lay",
            --["sitAngle"] = 0,
            --["sitCoverImage"] = "/objects/wired/pipe/sfsubmersiontank.png:foreground",
            --["sitEmote"] = "sleep",
            --["sitStatusEffects"] =  {
            --["kind"] = "Nude",
            --},
            --}}}
        else
            return { "ShowPopup", { message = "Tank is empty."}}
        end
    else
        return { "ShowPopup", { message = "^white;The tank is occupied^white;Holding ^green;" .. count ..
            "^white; / ^green;" .. capacity ..
            "^white; units of liquid ^green;" .. liquid
        }}
    end
end

function cycleForeground(occupied)
    if occupied then
        animator.setAnimationState("foreground", "hidden")
    else
        animator.setAnimationState("foreground", "active")
    end
end


function update(dt)
  pipes.update(dt)
  
  --TODO: use root functions, and get a hue on color (see capsule)
  local liquidState = self.liquidMap[storage.liquid.name]
  if liquidState then
    animator.setAnimationState("liquid", liquidState)
  else
    animator.setAnimationState("liquid", "other")
  end
  
  if storage.liquid.count then
    local liquidScale = storage.liquid.count / self.capacity
    animator.resetTransformationGroup("liquid")
    animator.transformTransformationGroup("liquid", 1, 0, 0, liquidScale, 0, -2.2 * (1 - liquidScale))
  else
    animator.scaleTransformationGroup("liquid", {1, 0})
  end


  cycleForeground(world.loungeableOccupied(entity.id()))

  --TODO: Reactivate timer pushing
  --if self.pushTimer > self.pushRate and storage.liquid[2] ~= nil then
    --local pushedLiquid = {storage.liquid[1], storage.liquid[2]}
    --if storage.liquid[2] > self.pushAmount then pushedLiquid[2] = self.pushAmount end
    --for i=1,2 do
      --if object.getInputNodeLevel(i-1) and pushLiquid(i, pushedLiquid) then
        --storage.liquid[2] = storage.liquid[2] - pushedLiquid[2]
        --break;
      --end
    --end
    --self.pushTimer = 0
  --end
  self.pushTimer = self.pushTimer + dt
  
  clearLiquid()
end

function clearLiquid()
  if storage.liquid.count ~= nil and storage.liquid.count == 0 then
    storage.liquid = {}
  end
end

function onLiquidPut(liquid, nodeId)
    local res = nil

    sb.logInfo("onPut %s", liquid)
    sb.logInfo("liquids = %s", storage.liquid)

    if liquid then
        if storage.liquid and liquid.name == storage.liquid.name then
            if storage.liquid.count >= self.capacity then
                res = nil
            else
                if liquid.count > (self.capacity - storage.liquid.count) then
                    res = {name = liquid.name, count = self.capacity - storage.liquid.count}
                else
                    res = liquid
                end

                storage.liquid.count = math.min(storage.liquid.count + liquid.count, self.capacity)
            end
        elseif not storage.liquid or not storage.liquid.name then
            if liquid.count > self.capacity then
                res = {name = liquid.name, count = self.capacity}
            else
                res = liquid
            end

            storage.liquid = res
        end
    end

    sb.logInfo("Tool %s", res)

    return res
end

function beforeLiquidPut(liquid, nodeId)
    local res = nil

    sb.logInfo("beforePut %s", liquid)

    if liquid then
        if storage.liquid and liquid.name == storage.liquid.name then
            if storage.liquid.count >= self.capacity then
                res = nil
            else
                if liquid.count > (self.capacity - storage.liquid.count) then
                    res = {name = liquid.name, count = self.capacity - storage.liquid.count}
                else
                    res = liquid
                end
            end
        elseif not storage.liquid or not storage.liquid.name then
            if liquid.count > self.capacity then
                res = {name = liquid.name, count = self.capacity}
            else
                res = liquid
            end
        end
    end

    sb.logInfo("canTake %s", res)

    return res
end

function onLiquidGet(filter, nodeId)
  if storage.liquid.name ~= nil then
    local liquids = {{name = storage.liquid.name, count = math.min(storage.liquid.count, self.pushAmount)}}

    local returnLiquid, _ = filterLiquids(filter, liquids)
    if returnLiquid then
      storage.liquid.count = storage.liquid.count - returnLiquid.count
      if storage.liquid.count <= 0 then
        storage.liquid = {}
      end
      return returnLiquid
    end
  end
  return nil
end

function beforeLiquidGet(filter, nodeId)
  if storage.liquid.name ~= nil then
    local liquids = {{name = storage.liquid.name, count = math.min(storage.liquid.count, self.pushAmount)}}

    local returnLiquid, _ = filterLiquids(filter, liquids)

    return returnLiquid
  end

  return nil
end
