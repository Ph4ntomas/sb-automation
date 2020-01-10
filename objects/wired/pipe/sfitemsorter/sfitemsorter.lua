function init(virtual)
    pipes.init({liquidPipe,itemPipe})

    self.connectionMap = {}
    self.connectionMap[1] = {2, 3, 4}
    self.connectionMap[2] = {1, 3, 4}
    self.connectionMap[3] = {1, 2, 4}
    self.connectionMap[4] = {1, 2, 3}

    self.filtermap = {1, 2, 2, 3,
                      1, 2, 2, 3,
                      1, 4, 4, 3,
                      1, 4, 4, 3}

    filter = {}
    filter[1] = {}
    filter[2] = {}
    filter[3] = {}
    filter[4] = {}

    self.stateMap = {"right", "up", "left", "down"}

    self.filterCount = {}

    buildFilter()
end

--------------------------------------------------------------------------------
function update(dt)
  buildFilter()
  pipes.update(dt)
end

function showPass(direction)
  animator.setAnimationState("filterState", "pass." .. direction)
end

function showFail()
  animator.setAnimationState("filterState", "fail")
end

function beforeLiquidGet(filter, nodeId)
  --world.logInfo("passing liquid peek get from %s to %s", nodeId, self.connectionMap[nodeId])
  return peekPullLiquid(self.connectionMap[nodeId], filter)
end

function onLiquidGet(filter, nodeId)
  --world.logInfo("passing liquid get from %s to %s", nodeId, self.connectionMap[nodeId])
  return pullLiquid(self.connectionMap[nodeId], filter)
end

function beforeLiquidPut(liquid, nodeId)
  --world.logInfo("passing liquid peek from %s to %s", nodeId, self.connectionMap[nodeId])
  return peekPushLiquid(self.connectionMap[nodeId], liquid)
end

function onLiquidPut(liquid, nodeId)
  --world.logInfo("passing liquid from %s to %s", nodeId, self.connectionMap[nodeId])
  return pushLiquid(self.connectionMap[nodeId], liquid)
end

function beforeItemPut(item, nodeId)
    sb.logInfo("beforeItemPut(%s, %s)\n connectionMap = %s", item, nodeId, self.connectionMap )
  for _,node in ipairs(self.connectionMap[nodeId]) do
    if self.filterCount[node] > 0 then
      if self.filter[node][item.name] then
        return peekPushItem(self.connectionMap[nodeId], item)
      end
    end
  end
  return false
end

function onItemPut(item, nodeId)
  local pushResult = false
  local resultNode = 1

  if item.name == "coalore" or item.name == "dirtmaterial" then
      sb.logInfo("pipes.nodes %s", pipes.nodes["item"])
      sb.logInfo("onItemPut(%s, %s)", item, nodeId)
      sb.logInfo("item = %s", item)
      sb.logInfo("filter = %s",self.filter)
      sb.logInfo("filterCount = %s",self.filterCount)
      sb.logInfo("connectionMap = %s", self.connectionMap[nodeId])
  end

  for _,node in ipairs(self.connectionMap[nodeId]) do
      if item.name == "coalore" then
          sb.logInfo("node = %s, filter = %s", node, self.filter[node])
      end
    if self.filterCount[node] > 0 then
      if self.filter[node][item.name] then
        pushResult = pushItem(node, item)
        if item.name == "coalore" then
            sb.logInfo("pushItem result %s", pushResult)
        end
        if pushResult then resultNode = node end
      end
    end
  end

  if pushResult then
    showPass(self.stateMap[resultNode])
  else
    showFail()
  end

  return pushResult
end

function beforeItemGet(filter, nodeId)
    sb.logInfo("beforeItemGet(%s, %s)\n connectionMap = %s", item, nodeId, self.connectionMap )
  for _,node in ipairs(self.connectionMap[nodeId]) do
    if self.filterCount[node] > 0 then
      local pullFilter = {}
      local filterMatch = false
      for filterString, amount in pairs(filter) do
        if self.filter[node][filterString] then
          pullFilter[filterString] = amount
          filterMatch = true
        end
      end

      if filterMatch then
        return peekPullItem(self.connectionMap[nodeId], pullFilter)
      end
    end
  end

  return false
end

function onItemGet(filter, nodeId)
    sb.logInfo("onItemGet(%s, %s)\n connectionMap = %s", item, nodeId, self.connectionMap )
  local pullResult = false
  local resultNode = 1

  for _,node in ipairs(self.connectionMap[nodeId]) do
  if self.filterCount[node] > 0 then
    local pullFilter = {}
    local filterMatch = false
    for filterString, amount in pairs(filter) do
      if self.filter[filterString] then
        pullFilter[filterString] = amount
        filterMatch = true
      end
    end

    if filterMatch then
      pullResult = pullItem(self.connectionMap[nodeId], pullFilter)
      if pullResult then resultNode = node end
    end
  end
  end

  if pullResult then
    showPass(self.stateMap[resultNode])
  else
    showFail()
  end

  return pullResult
end

function buildFilter()
  self.filter = {{}, {}, {}, {}}
  self.filterCount = {0, 0, 0, 0}
  local totalCount = 0

  local contents = world.containerItems(entity.id())
  if contents then
    for key, item in pairs(contents) do
      if self.filter[self.filtermap[key]][item.name] then
        self.filter[self.filtermap[key]][item.name] = math.min(self.filter[self.filtermap[key]][item.name], item.count)
      else
        self.filter[self.filtermap[key]][item.name] = item.count
        self.filterCount[self.filtermap[key]] = self.filterCount[self.filtermap[key]] + 1
        totalCount = totalCount + 1
      end
    end
  end

  if totalCount > 0 and animator.animationState("filterState") == "off" then
    animator.setAnimationState("filterState", "on")
  elseif totalCount <= 0 then
    animator.setAnimationState("filterState", "off")
  end
end
