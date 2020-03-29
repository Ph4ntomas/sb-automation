datawire = {}

--- this should be called by the implementing object in its own init()
function datawire.init()
  datawire.inputConnections = {}
  datawire.outputConnections = {}

  datawire.initialized = false
end

--- this should be called by the implementing object in its own onNodeConnectionChange()
function datawire.onNodeConnectionChange()
  datawire.createConnectionTable()
end

--- any datawire operations that need to be run when main() is first called
function datawire.update()
  if datawire.initialized then
    -- nothing for now
  else
    datawire.initAfterLoading()
    if initAfterLoading then initAfterLoading() end
  end
end

-------------------------------------------

--- this will be called internally, to build connection tables once the world has fully loaded
function datawire.initAfterLoading()
  datawire.createConnectionTable()
  datawire.initialized = true
end

--- Creates connection tables for input and output nodes
function datawire.createConnectionTable()
  datawire.outputConnections = {}
  local i = 0
  while i < object.outputNodeCount() do
    local connInfo = object.getOutputNodeIds(i)
    local entityIds = {}
    for k, v in pairs(connInfo) do
      entityIds[#entityIds + 1] = k
    end
    datawire.outputConnections[i] = entityIds
    i = i + 1
  end

  datawire.inputConnections = {}
  local connInfos
  i = 0
  while i < object.inputNodeCount() do
    connInfos = object.getInputNodeIds(i)
    for j, connInfo in ipairs(connInfos) do
      datawire.inputConnections[connInfo[1]] = i
    end
    i = i + 1
  end

  --sb.logInfo(string.format("%s (id %d) created connection tables for %d output and %d input nodes", config.getParameter("objectName"), entity.id(), object.outputNodeCount(), object.inputNodeCount()))
  --sb.logInfo("output: %s", datawire.outputConnections)
  --sb.logInfo("input: %s", datawire.inputConnections)
end

--- determine whether there is a valid recipient on the specified output node
-- @param nodeId the node to be queried
-- @returns true if there is a recipient connected to the node
function datawire.isOutputNodeConnected(nodeId)
  return datawire.outputConnections and datawire.outputConnections[nodeId] and #datawire.outputConnections[nodeId] > 0
end

--- Sends data to another datawire object
-- @param data the data to be sent
-- @param dataType the data type to be sent ("boolean", "number", "string", "area", etc.)
-- @param nodeId the output node id to send to, or "all" for all output nodes
-- @returns true if at least one object successfully received the data
function datawire.sendData(data, dataType, nodeId)
  -- don't transmit if connection tables haven't been built
  if not datawire.initialized then
    return false
  end

  local transmitSuccess = false

  if nodeId == "all" then
    for k, v in pairs(datawire.outputConnections) do
      transmitSuccess = datawire.sendData(data, dataType, k) or transmitSuccess
    end
  else
    if datawire.outputConnections[nodeId] and #datawire.outputConnections[nodeId] > 0 then 
      for i, entityId in ipairs(datawire.outputConnections[nodeId]) do
        if entityId ~= entity.id() then
          transmitSuccess = world.callScriptedEntity(entityId, "datawire.receiveData", { data, dataType, entity.id() }) or transmitSuccess
        end
      end
    --else
        --sb.logInfo("wtf : " .. sb.print(datawire))
    end
  end

  --if not transmitSuccess then
    --sb.logInfo(string.format("DataWire: %s (id %d) FAILED to send data of type %s", config.getParameter("objectName"), entity.id(), dataType))
    --sb.logInfo(data)
  --end

  return transmitSuccess
end

--- Receives data from another datawire object
-- @param data (args[1]) the data received
-- @param dataType (args[2]) the data type received ("boolean", "number", "string", "area", etc.)
-- @param sourceEntityId (args[3]) the id of the sending entity, which can be use for an imperfect node association
-- @returns true if valid data was received
function datawire.receiveData(args)
  --unpack args
  local data = args[1]
  local dataType = args[2]
  local sourceEntityId = args[3]

  --sb.logInfo("%s %d sent me this %s %s", world.callScriptedEntity(sourceEntityId, "config.getParameter", "objectName"), sourceEntityId, dataType, data)

  --convert entityId to nodeId
  local nodeId = datawire.inputConnections[sourceEntityId]

  if nodeId == nil then
    if datawire.initialized then
      sb.logWarning("DataWire: %s received data of type %s from UNRECOGNIZED %s %d, not in table:", object.name(), dataType, world.callScriptedEntity(sourceEntityId, "object.name()"), sourceEntityId)
      sb.logWarning("%s", datawire.inputConnections)
    end

    return false
  elseif validateData and validateData(data, dataType, nodeId, sourceEntityId) then
    if onValidDataReceived then
      onValidDataReceived(data, dataType, nodeId, sourceEntityId)
    end

    --sb.logInfo(string.format("DataWire: %s received data of type %s from %d", object.name(), dataType, sourceEntityId))

    return true
  else
    --sb.logWarning("DataWire: %s received INVALID data of type %s from entity %d: %s", object.name(), dataType, sourceEntityId, data)
    
    return false
  end
end
