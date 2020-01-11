function collideHndl(_, _, args)
    return collide(args)
end

function damageHndl(_, _)
    return damage()
end

function digHndl(_, _, args)
    return dig(args)
end

function moveHndl(_, _, args)
    return move(args)
end

function init(args)
    --entity.setGravityEnabled(false)
    monster.setDamageOnTouch(false)
    monster.setDeathParticleBurst(config.getParameter("deathParticles"))
    --monster.setDeathSound(entity.randomizeParameter("deathNoise"))
    self.dead = false

    message.setHandler("collide", collideHndl)
    message.setHandler("damage", damageHndl)
    message.setHandler("dig", digHndl)
    message.setHandler("move", moveHndl)
end

function damage()
    self.dead = true
end

function shouldDie()
    return self.dead
end

function collide(args)
    mcontroller.setVelocity({0,0})
    --entity.setAnimationState("movement", "idle")
end

function dig(args)
    mcontroller.setVelocity({0,0})
    --entity.setAnimationState("movement", "idle")
end

function move(args)
    mcontroller.setVelocity(args.velocity)
end

function burstParticleEmitter()
    if self.emitter then
        self.emitter = self.emitter - 1
        if self.emitter == 0 then
            animator.setParticleEmitterActive("dig", false)
            self.emitter = false
        end
    end
end
