function init(args)
  entity.setInteractive(true)

  if storage.state == nil then
    output(false)
  else
    output(storage.state)
  end

  if storage.triggered == nil then
    storage.triggered = false
  end
end

function onInteraction(args)
  output(not storage.state)
end

function onInputNodeChange(args)
  checkInputNodes()
end

function onNodeConnectionChange(args)
  checkInputNodes()
end

function checkInputNodes()
  if entity.InputNodeCount() > 0 and entity.getInputNodeLevel(0) then
    output(not storage.state)
  end
end

function output(state)
  storage.state = state
  if state then
    entity.setAnimationState("switchState", "on")
    entity.playSound("onSounds");
    entity.setAllOutputNodes(true)
  else
    entity.setAnimationState("switchState", "off")
    entity.playSound("offSounds");
    entity.setAllOutputNodes(false)
  end
end
