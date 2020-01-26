function init()
    if storage.state == nil then
      storage.state = false
    end

    if storage.timer == nil then
      storage.timer = 0
    end

    self.detectCooldown = config.getParameter("detectCooldown")

    updateAnimationState()

    self.connectionMap = {}
    self.connectionMap[1] = 2
    self.connectionMap[2] = 1
    self.connectionMap[3] = 4
    self.connectionMap[4] = 3
  
    pipes.init({liquidPipe})
    datawire.init()
end

function onNodeConnectionChange()
  datawire.onNodeConnectionChange()
end

--------------------------------------------------------------------------------
function update(dt)
  datawire.update()
  pipes.update(dt)

  if storage.timer > 0 then
    storage.timer = storage.timer - dt

    if storage.timer <= 0 then
      deactivate()
    end
  end
end

function updateAnimationState()
  if storage.state then
    animator.setAnimationState("switchState", "on")
  else
    animator.setAnimationState("switchState", "off")
  end
end

function activate()
  storage.timer = self.detectCooldown
  storage.state = true
  object.setAllOutputNodes(true)
  updateAnimationState()
end

function deactivate()
  storage.state = false
  updateAnimationState()
  object.setAllOutputNodes(false)
end

function output(liquid)
  if liquid.count then
    datawire.sendData(liquid.count, "number", "all")
  end
end

function beforeLiquidGet(filter, nodeId)
    local ret = peekPullLiquid(self.connectionMap[nodeId], filter)

    if ret then return ret[2] end

    return nil
end

function onLiquidGet(filter, nodeId)
  local peek = peekPullLiquid(self.connectionMap[nodeId], filter)

  if peek then
      local result = pullLiquid(self.connectionMap[nodeId], peek[1])

      if result then
          activate()
          output(result)
      end

      return result[2]
  end

  return nil
end

function beforeLiquidPut(liquid, nodeId)
    local ret = peekPushLiquid(self.connectionMap[nodeId], liquid)

    if ret then return ret[2] end

    return nil
end

function onLiquidPut(liquid, nodeId)
  local peek = peekPushLiquid(self.connectionMap[nodeId], liquid)

  if peek then
      local result = pushLiquid(self.connectionMap[nodeId], peek[1])
      if result then
          activate()
          output(liquid)
      end
      return result[2]
  end
  return nil
end
