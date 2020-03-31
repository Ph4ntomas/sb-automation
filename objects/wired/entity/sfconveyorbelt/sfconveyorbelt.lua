function init(v)
    energy.init()
    storage.active = storage.active or false
    setActive(storage.active)
    onNodeConnectionChange()
end

function die()
    energy.die()
end

function onNodeConnectionChange(args)
    if object.isInputNodeConnected(0) then
        object.setInteractive(false)
    else
        object.setInteractive(true)
    end
    onInputNodeChange(args)
end

function onInputNodeChange(args)
    if object.isInputNodeConnected(0) then
        setActive(object.getInputNodeLevel(0))
    end
end

function onInteraction(args)
    setActive(not storage.active)
end

function setActive(flag, dt)
    dt = dt or script.updateDt()

    if not flag or energy.consume(dt, nil, true) then
        storage.active = flag

        if flag then 
            animator.setAnimationState("workState", "work")
        else 
            animator.setAnimationState("workState", "idle")
        end

        physics.setForceEnabled(object.direction() > 0 and "right" or "left", flag)
    end
end

function update(dt)
    energy.update(dt)

    if storage.active then
        if not energy.consume(dt) then
            setActive(false, dt)
            return
        end
    end
end
