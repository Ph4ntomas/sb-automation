function init(virtual)
  if not virtual then
    self.detectThresholdHigh = entity.configParameter("detectThresholdHigh")
    self.detectThresholdLow = entity.configParameter("detectThresholdLow")

    datawire.init()
  end
end

function onNodeConnectionChange()
  datawire.onNodeConnectionChange()
end

function getSample()
  --to be implemented by sensor
  return false
end

function main()
  datawire.update()
  
  local sample = getSample()
  datawire.sendData(sample, "number", "all")

  if sample >= self.detectThresholdLow then
    entity.setOutputNodeLevel(0, true)
    entity.setAnimationState("sensorState", "med")
  else
    entity.setOutputNodeLevel(0, false)
    entity.setAnimationState("sensorState", "min")
  end

  if sample >= self.detectThresholdHigh then
    entity.setOutputNodeLevel(1, true)
    entity.setAnimationState("sensorState", "max")
  else
    entity.setOutputNodeLevel(1, false)
  end
end
