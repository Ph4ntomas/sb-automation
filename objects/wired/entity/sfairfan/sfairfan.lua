function init()
    energy.init()

    storage.active = storage.active or false

    self.flipStr = ""
    if object.direction() == -1 then
        self.flipStr = "flip"
    end

    animator.setParticleEmitterActive("fanwind", false)
    animator.setParticleEmitterActive("fanwindflip", false)

    setActive(storage.active)

    physics.setForceEnabled("blowLeft", false)
    physics.setForceEnabled("blowRight", false)
    
    self.timer = 0

    onNodeConnectionChange(nil)
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
        animator.setParticleEmitterActive("fanwind" .. self.flipStr, flag)

        if flag then
            animator.setAnimationState("fanState", "work")
        elseif storage.active then
            animator.setAnimationState("fanState", "slow")
            self.timer = 20
        else
            animator.setAnimationState("fanState", "idle")
        end

        physics.setForceEnabled("blow".. ((object.direction() > 0 and "Right") or "Left"), flag)
        storage.active = flag
    end
end


function update(dt)
    energy.update(dt)

    if storage.active then
        if not energy.consume(dt) then
            setActive(false)
            return
        end
    elseif self.timer > 0 then
        self.timer = self.timer - 1
        if self.timer == 1 then 
            animator.setAnimationState("fanState", "idle") 
        end
    end
end
