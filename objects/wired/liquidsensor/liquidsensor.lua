function getSample()
  return world.liquidAt(object.position())
end

function update(dt)
  datawire.update()

  local sample = getSample()
  if sample then
    datawire.sendData(sample[1], "number", "all")
    sb.setLogMap("sensor : " .. entity.id(), " value : %s; name : %s", sample[1], root.liquidName(sample[1]))
  else
    datawire.sendData(0, "number", "all")
  end

  if not sample then
    object.setOutputNodeLevel(0, false)
    animator.setAnimationState("sensorState", "off")
  else 
      local name = root.liquidName(sample[1])
      if name == "water" then
          object.setOutputNodeLevel(0, true)
          animator.setAnimationState("sensorState", "water")
      elseif name == "poison" then
          object.setOutputNodeLevel(0, true)
          animator.setAnimationState("sensorState", "poison")
      elseif name == "lava" then
          object.setOutputNodeLevel(0, true)
          animator.setAnimationState("sensorState", "lava")
      else
          object.setOutputNodeLevel(0, true)
          animator.setAnimationState("sensorState", "other")
      end
  end
end
