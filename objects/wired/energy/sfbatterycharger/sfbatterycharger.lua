require '/scripts/sfutil.lua'

function init()
    energy.init()
    datawire.init()

    self.interactive = true
    object.setInteractive(true)

    --table of batteries in the charger
    self.batteries = {}

    -- will be updated when batteries are checked
    self.totalUnusedCapacity = 0
    self.totalStoredEnergy = 0

    --maximum energy to request for batteries from a single pulse
    self.batteryChargeAmount = 5

    --flag to allow/disallow energy output
    if storage.discharging == nil then
        storage.discharging = true
    end

    --frequency (in seconds) to check for batteries present
    self.batteryCheckFreq = 1
    self.batteryCheckTimer = self.batteryCheckFreq

    --store this so that we don't have to compute it repeatedly
    local pos = entity.position()
    -- for some weird reason, at least on linux, this detect waaaay further than it should, and is enough to detect all batteries
    self.batteryCheckArea = {
        {pos[1] + 0.5, pos[2] + 1}, 
        {pos[1] + 0.5, pos[2] + 2}
    }

    updateAnimationState()
end

-- this hook is called by the first datawire.update()
function initAfterLoading()
    checkBatteries()
end

function onNodeConnectionChange()
    datawire.onNodeConnectionChange()
end

function die()
    local batPos = {}

    for i, batteryStatus in ipairs(self.batteries) do
        batPos[#batPos + 1] = batteryStatus.position
        --world.callScriptedEntity(batteryStatus.id, "die")
    end
    world.damageTiles(batPos, "foreground", entity.position(), "blockish", 25000, 0)
    energy.die()
end

function onInteraction(args)
    storage.discharging = not storage.discharging
    updateAnimationState()
end

function isBatteryCharger()
    return true
end

function battCompare(a, b)
    return a.position[1] < b.position[1]
end

function checkBatteries()
    self.batteries = {}
    self.totalUnusedCapacity = 0
    self.totalStoredEnergy = 0

    local entityIds = world.objectQuery(self.batteryCheckArea[1], self.batteryCheckArea[2], { withoutEntityId = entity.id(), callScript = "isBattery" })


    for i, entityId in ipairs(entityIds) do
        local batteryStatus = world.callScriptedEntity(entityId, "getBatteryStatus")
        self.batteries[#self.batteries + 1] = batteryStatus

        if batteryStatus.acceptCharge then
            self.totalUnusedCapacity = self.totalUnusedCapacity + batteryStatus.unusedCapacity
        end

        self.totalStoredEnergy = self.totalStoredEnergy + batteryStatus.energy
    end

    --order batteries left -> right
    table.sort(self.batteries, battCompare)

    updateAnimationState()
    self.batteryCheckTimer = self.batteryCheckFreq --reset this here so we don't perform periodic checks right after a pulse
end

function updateAnimationState()
    if not self.batteries then
        animator.setAnimationState("chargeState", "error")
    elseif #self.batteries == 0 then
        animator.setAnimationState("chargeState", "off")
    elseif storage.discharging then
        animator.setAnimationState("chargeState", "on")
    else
        animator.setAnimationState("chargeState", "charge")
    end
end

function onEnergyNeedsCheck(needDesc)
    if not storage.discharging or not world.callScriptedEntity(needDesc.source, "isBatteryCharger") then
        local thisNeed = math.min(self.batteryChargeAmount, self.totalUnusedCapacity)
        needDesc.total = needDesc.total + thisNeed
        needDesc.needs[tostring(entity.id())] = thisNeed
    else
        needDesc.needs[tostring(entity.id())] = 0
    end

    return needDesc
end

--only send energy while discharging (even if it's in the pool... could try revamping this later)
function onEnergySendCheck()
    if storage.discharging then
        return energy.get()
    elseif self.totalUnusedCapacity <= 0 then
        return 0
    end
end

function onEnergyReceived(amount)
    checkBatteries()
    local acceptedEnergy = chargeBatteries(amount)

    return acceptedEnergy
end

function chargeBatteries(amount)
    local amountRemaining = amount
    for i, bStatus in ipairs(self.batteries) do
        if bStatus.acceptCharge then
            local amountAccepted = world.callScriptedEntity(bStatus.id, "energy.add", amountRemaining)
            if amountAccepted then --this check probably isn't necessary, but just in case a battery explodes or something
                if amountAccepted > 0 then
                    world.callScriptedEntity(bStatus.id, "showChargeEffect")
                end
                amountRemaining = amountRemaining - amountAccepted
            end
        end
    end

    return amount - amountRemaining
end

--fills the charger's energy pool from the contained batteries
function dischargeBatteries()
    local sourceBatt = #self.batteries
    local energyNeeded = energy.getUnusedCapacity()
    while sourceBatt >= 1 and energyNeeded > 0 do
        local pdischarge = sfutil.safe_await(world.sendEntityMessage(self.batteries[sourceBatt].id, "energy.remove", energyNeeded))

        if pdischarge:succeeded() then
            local discharge = pdischarge:result()
            if discharge and discharge > 0 then
                energy.add(discharge)
                energyNeeded = energyNeeded - discharge
            end
        end
        sourceBatt = sourceBatt - 1
    end
end

--updates output nodes and sends datawire data
function setWireStates()
    datawire.sendData(self.totalStoredEnergy, "number", 0)
    datawire.sendData(self.totalUnusedCapacity, "number", 1)
    object.setOutputNodeLevel(0, self.totalUnusedCapacity == 0)
    object.setOutputNodeLevel(1, self.totalStoredEnergy == 0)
end

function update(dt)
    area = self.batteryCheckArea

    self.batteryCheckTimer = self.batteryCheckTimer - dt
    if self.batteryCheckTimer <= 0 then
        checkBatteries()
    end

    if storage.discharging then
        dischargeBatteries()
    end

    setWireStates()

    datawire.update()
    energy.update(dt)
end
