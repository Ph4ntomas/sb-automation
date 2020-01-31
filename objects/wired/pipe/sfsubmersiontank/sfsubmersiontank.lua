function init()  
  object.setInteractive(true)
    pipes.init({liquidPipe})
    local initInv = config.getParameter("initialInventory")
    if initInv and storage.liquid == nil then
      storage.liquid = initInv
    end
    
    --animator.setGlobalTag("liquidDirectives", getDirective(storage.liquid.name))
    --animator.setAnimationState("liquid", "base")
    --animator.resetTransformationGroup("liquid")
    --animator.scaleTransformationGroup("liquid", {1, 0})

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
--

function getLiquidReadableName(liquid)
    local ret = "unknown liquid"
    if liquid then
        local config = root.liquidConfig(liquid)
        sb.logInfo("liquidConfig : %s", config)

        if config then
            local item = config["config"]["itemDrop"]
            local iconf = root.itemConfig({name = item, 1})

            if iconf then
                ret = iconf["config"]["shortdescription"]
            end
        end
    end

    return ret
end

function onInteraction(args)
    sb.logInfo("players = %s",world.players())

    local liquid = nil
    local liquidName = "unknown liquid"

    if storage.liquid.name ~= nil then
        liquid = root.liquidName(storage.liquid.name)
        liquidName = getLiquidReadableName(liquid)
    end

    local count = storage.liquid.count
    local capacity = self.capacity
    local itemList = ""

    if not world.loungeableOccupied(entity.id()) then
        if count ~= nil and count < capacity then 
            return { "ShowPopup", { message = "^white;You manage to suppress the desire to climb into the tank... for now.\n\n^white;Holding ^green;" .. count ..
                "^white; / ^green;" .. capacity ..
                "^white; units of ^green;" .. liquidName
            }}
        elseif count ~= nil then
            return { "SitDown", 0} --, {
            --["sitFlipDirection"] = false,
                    -- sitPosition = {20,200}}}
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
        if self.player then
            --world.loadUniqueEntity("TankPlayer"..self.player)
            --world.setUniqueId(self.player)
            self.player = nil
        end
        animator.setAnimationState("foreground", "active")
    end
end

local function getColorShiftForLiquid(name)
    local waterconfig = root.liquidConfig("water")
    local config = root.liquidConfig(name)

    if config and waterconfig then
        local waterRgb = waterconfig["config"]["color"]
        local rgb = config["config"]["color"]
        local lrgb = config["config"]["radiantLight"]
        local brgb = config["config"]["bottomLightMix"]

        if waterRgb and rgb then
            local waterHsv = sfutil.rgb2hsv(waterRgb)
            local liquidHsv = sfutil.rgb2hsv(rgb)

            if lrgb then
                local lHsv = sfutil.rgb2hsv(lrgb)

                if brgb then
                    local bHsv = sfutil.rgb2hsv(lrgb)

                    liquidHsv.hue = (liquidHsv.hue + lHsv.hue + bHsv.hue) / 3
                    liquidHsv.sat = (liquidHsv.sat + lHsv.sat + bHsv.sat) / 3
                    liquidHsv.val = (liquidHsv.val + lHsv.val + bHsv.val) / 3
                else
                    liquidHsv.hue = (liquidHsv.hue + lHsv.hue) / 2
                    liquidHsv.sat = (liquidHsv.sat + lHsv.sat) / 2
                    liquidHsv.val = (liquidHsv.val + lHsv.val) / 2
                end
            end

            return {
                hue = liquidHsv.hue - waterHsv.hue,
                sat = liquidHsv.sat - waterHsv.sat,
                val = liquidHsv.val - waterHsv.val,
                rgb[4]
            }
        end
    end
    return nil
end

function getDirective(liquid)
    local ret = ""
    local liquidName = root.liquidName(liquid)

    if liquidName then
        local hsvShift = getColorShiftForLiquid(liquidName)

        if hsvShift then
            local hueshift = "?hueshift=" .. tostring(hsvShift.hue)
            local saturation = "?saturation=" .. tostring(hsvShift.sat * 100)
            local brightness = "?brightness=" .. tostring(hsvShift.val * 100)

            ret = ret .. hueshift .. saturation .. brightness
        end
    end


    return ret
end

function applyEffect(liquid)
    local liquidName = root.liquidName(liquid)
    local config = root.liquidConfig(liquidName)

    if world.loungeableOccupied(entity.id()) then
        world.spawnLiquid(object.toAbsolutePosition({100, 10}), liquidName, 1)
    end

end

function test()
    return "test"
end

function update(dt)
  pipes.update(dt)

  --TODO: use root functions, and get a hue on color (see capsule)
  --local liquidState = self.liquidMap[storage.liquid.name]
  --if liquidState then
    --animator.setAnimationState("liquid", liquidState)
  --else
    --animator.setAnimationState("liquid", "other")
  --end
  
  if storage.liquid.count then
    local liquidScale = storage.liquid.count / self.capacity
    animator.resetTransformationGroup("liquid")
    animator.setPartTag("liquid", "directives", getDirective(storage.liquid.name))
    animator.setAnimationState("liquid", "base", true)
    animator.transformTransformationGroup("liquid", 1, 0, 0, liquidScale, 0, -2.2 * (1 - liquidScale))

    if world.loungeableOccupied(entity.id()) then
        players = world.playerQuery(object.toAbsolutePosition({-1, 0}), object.toAbsolutePosition({2, 5}))

        for _, v in pairs(players) do
            world.sendEntityMessage(v, "applyStatusEffect", "melting", 1, entity.id())
        end
    end
    --sb.logInfo("res = %s", 
        --world.playerQuery(
            --object.toAbsolutePosition({-1,0}), 
            --object.toAbsolutePosition({1, 5}), 
            --{callScript= test}
        --)
    --)
    --if storage.liquid.name then
        --applyEffect(storage.liquid.name)
    --end
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

    return res
end

function beforeLiquidPut(liquid, nodeId)
    local res = nil

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
