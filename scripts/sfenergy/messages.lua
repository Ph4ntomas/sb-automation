sfMessageHooks = sfMessageHook or {}
sfMessageHooks.energy = {}


local function getNodeHndl(_, _)
    return energy.getNode()
end

local function isRelayHndl(_, _)
    return (energy.isRelay and energy.isRelay()) or false
end

local function isChargerHndl(_, _)
    return (energy.isCharger and energy.isCharger()) or false
end

local function getIgnoredBlocksHndl(_, _)
    return energy.getIgnoredBlocks()
end

local function onConnectHndl(_, _, id)
    return energy.onConnect(id)
end

local function onDisconnectHndl(_, _, id)
    return energy.onDisconnect(id)
end

local function getNeedsHndl(_, _, needDesc)
    return energy.getNeeds(needDesc)
end

local function receiveHndl(_, _, amount)
    return energy.receive(amount)
end

local function removeHndl(_,_, amount)
    return energy.remove(amount)
end

function sfMessageHooks.energy.init()
  message.setHandler("energy.getNode", getNodeHndl)
  message.setHandler("energy.isRelay", isRelayHndl)
  message.setHandler("energy.isCharger", isChargerHndl)
  message.setHandler("energy.getIgnoredBlocks", getIgnoredBlocksHndl)
  message.setHandler("energy.onConnect", onConnectHndl)
  message.setHandler("energy.onDisconnect", onDisconnectHndl)
  message.setHandler("energy.getNeeds", getNeedsHndl)
  message.setHandler("energy.receive", receiveHndl)
  message.setHandler("energy.remove", removeHndl)
end
