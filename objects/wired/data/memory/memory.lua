function init(virtual)
  if not virtual then
    if not storage.dataType then
      storage.dataType = "empty"
    end

    if storage.lockoutput == nil then
      storage.lockoutput = false
    end

    if storage.lockInput == nil then
      storage.lockInput = false
    end

    self.flipStr = ""
    if entity.direction() == -1 then
      self.flipStr = "flipped."
    end

    updateAnimationState()

    datawire.init()
  end
end

function onInteraction(args)
  reset()
end

function onNodeConnectionChange()
  datawire.onNodeConnectionChange()
end

function onInputNodeChange(args)
  storage.lockInput = entity.getInputNodeLevel(1)
  storage.lockoutput = entity.getInputNodeLevel(2)

  output()
  updateAnimationState()
end

function updateAnimationState()
  if entity.getInputNodeLevel(1) and entity.getInputNodeLevel(2) then
    entity.setAnimationState("lockState", self.flipStr.."both")
  elseif entity.getInputNodeLevel(1) then
    entity.setAnimationState("lockState", self.flipStr.."in")
  elseif entity.getInputNodeLevel(2) then
    entity.setAnimationState("lockState", self.flipStr.."out")
  else
    entity.setAnimationState("lockState", self.flipStr.."none")
  end
end

function validateData(data, dataType, nodeId, sourceEntityId)
  --only receive data on node 0
  return nodeId == 0
end

function onValidDataReceived(data, dataType, nodeId, sourceEntityId)
  if not storage.lockInput then
    storage.data = data
    storage.dataType = dataType
  end
end

function output()
  if not storage.lockoutput and storage.data then
    datawire.sendData(storage.data, storage.dataType, 0)
  end
end

function main()
  datawire.update()
  output()
end