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
        object.toAbsolutePosition({-0.7, 0}), 
        object.toAbsolutePosition({2, 0}),
        object.toAbsolutePosition({2, 2}),
        object.toAbsolutePosition({-0.7, 2})
    }

    world.debugPoly(poly, "red")
end

function update(dt)
    energy.update(dt)

    if self.jumpt > 0 then
        self.jumpt = self.jumpt - 1
    else
            physics.setForceEnabled("jumpForce", false)
    end

    debugRegion()

    local active = energy.get() >= self.energyPerJump  --and self.jumpt < 1

    if active and self.jumpt <= 0 then
        local p = object.toAbsolutePosition({ 0, 0 })
        local eids = world.entityQuery({p[1] - 0.7, p[2]}, { p[1] + 2, p[2] + 1 }, { includedTypes = {"mobile"}, order = "nearest" })

        eids = filterEids(eids)

        if not (next(eids) == nil) and energy.consume(dt, self.energyPerJump) then
            physics.setForceEnabled("jumpForce", active)
            animator.playSound("jump")
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
