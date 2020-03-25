function init()
    energy.init()
    self.jumpt = 0
    self.jumpSound = config.getParameter("jumpSound")
    self.energyPerJump = config.getParameter("energyPerJump")
    self.lastTickEids = {}
end

function die()
    energy.die()
end

local function filterEids(eids)
    local ret = {}
    local tickEids = {}

    for _, id in pairs(eids) do 
        if world.entityType(id) ~= "projectile" then
            if self.lastTickEids[id] == nil then
                ret[id] = id
            end

            tickEids[id] = id
        end
    end

    self.lastTickEids = tickEids
    return ret
end

function debugRegion() 
    local poly = {
        object.toAbsolutePosition({-1, 0}), 
        object.toAbsolutePosition({2, 0}),
        object.toAbsolutePosition({2, 4}),
        object.toAbsolutePosition({-1, 4})
    }

    world.debugPoly(poly, "red")
end

function update(dt)
    energy.update(dt)

    if self.jumpt > 0 then
        self.jumpt = self.jumpt - 1
    end

    local active = energy.get() >= self.energyPerJump  --and self.jumpt < 1
    physics.setForceEnabled("jumpForce", active)

    if active then
        local p = object.toAbsolutePosition({ -1, 1 })
        local eids = world.entityQuery(p, { p[1] + 2, p[2] + 4 }, { includedTypes = {"mobile"}, order = "nearest" })

        eids = filterEids(eids)

        if not (next(eids) == nil) and energy.consume(dt, self.energyPerJump) then
            self.jumpt = 7
        end
    end

    local state = animator.animationState("jumpState")

    if self.jumpt > 0 then
        animator.setAnimationState("jumpState", "jump")
    elseif active then
        animator.setAnimationState("jumpState", "idle")
    else
        animator.setAnimationState("jumpState", "error")
    end
end
