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
  
    pipes.init({itemPipe})
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
  object.setAlloutputNodes(true)
  updateAnimationState()
end

function deactivate()
  storage.state = false
  updateAnimationState()
  object.setAlloutputNodes(false)
end

function output(item)
  if item.count then
    datawire.sendData(item.count, "number", "all")
  end
end

function beforeItemPut(item, nodeId)
  --world.logInfo("passing item peek from %s to %s", nodeId, self.connectionMap[nodeId])
  return peekPushItem(self.connectionMap[nodeId], item)
end

function onItemPut(item, nodeId)
  --world.logInfo("passing item from %s to %s", nodeId, self.connectionMap[nodeId])
  local peek = peekPushItem(self.connectionMap[nodeId], item)

  if peek then
      local result = pushItem(self.connectionMap[nodeId], peek[1])
      if result then
          activate()
          output(item)
      end
      return result
  end
  return nil
end

function beforeItemGet(filter, nodeId)
  --world.logInfo("passing item peek get from %s to %s", nodeId, self.connectionMap[nodeId])
  return peekPullItem(self.connectionMap[nodeId], filter)
end

function onItemGet(filter, nodeId)
  --world.logInfo("passing item get from %s to %s", nodeId, self.connectionMap[nodeId])
  local result = pullItem(self.connectionMap[nodeId], filter)
  if result then
    activate()
    output(result)
  end
  return result
end
