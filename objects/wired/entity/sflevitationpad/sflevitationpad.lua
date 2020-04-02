function init()
    energy.init()

    storage.active = storage.active or false
    onNodeConnectionChange(nil)
    self.states = {"mid", "high", "mid",  "low" }
    self.cur_state = 1
    self.switch_max = 10
    self.switch = self.switch_max

    setActive(storage.active)
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

function setActive(flag)
    if not flag or energy.consume(script.updateDt(), nil, true) then
        storage.active = flag

        if flag then
            animator.setAnimationState("jumpState", "jump")
            self.cur_state = 1
            self.switch = self.switch_max
        else
            animator.setAnimationState("jumpState", "idle")
            physics.setForceEnabled(self.states[self.cur_state], false)
        end
    end
end

function update(dt)
    energy.update(dt)
    
    if storage.active then
        if not energy.consume(dt) then
            setActive(false)
        else
            if self.switch == 0 then
                physics.setForceEnabled(self.states[self.cur_state], false)
                self.cur_state = self.cur_state == #self.states and 1 or (self.cur_state + 1) 
                physics.setForceEnabled(self.states[self.cur_state], true)
                self.switch = self.switch_max
            else
                self.switch = self.switch - 1
            end
        end
    end
end
