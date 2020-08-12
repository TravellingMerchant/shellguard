function init()
  monster.setDeathParticleBurst("deathPoof")
  animator.setAnimationState("movement", "flying")

  self.masterId = config.getParameter("masterId")
  self.minionIndex = config.getParameter("minionIndex")
  self.minionTimer = 0

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end

  message.setHandler("despawn", despawn)

  rangedAttack.loadConfig()
end

function shouldDie()
  return not status.resourcePositive("health")
end

function update(dt)
  if self.timerSync then
    if self.timerSync:finished() then
      if self.timerSync:succeeded() then
        self.minionTimer = self.timerSync:result()
      else
        despawn()
      end
      self.timerSync = nil
    end
  else
    self.timerSync = world.sendEntityMessage(self.masterId, "minionTimer")
  end

  self.minionTimer = self.minionTimer + dt

  if world.entityExists(self.masterId) then
    local angle = ((self.minionIndex - 1) * math.pi / 2.0) + self.minionTimer
    local target = vec2.add(world.entityPosition(self.masterId), {
      20.0 * math.cos(angle),
      8.0 * math.sin(angle)
    })

    local targetVelocity = world.entityVelocity(self.masterId)
    local toTarget = vec2.norm(world.distance(target, mcontroller.position()))
    local parameters = mcontroller.baseParameters()
    local speed = parameters.flySpeed * math.min(1.0, world.magnitude(target, mcontroller.position()) / 4)
    mcontroller.controlApproachVelocity(vec2.add(targetVelocity, vec2.mul(toTarget, speed)), parameters.airForce)
  else
    mcontroller.controlFly({0,0})
  end

  util.trackTarget(30.0, 10.0)

  if self.targetPosition ~= nil then
    rangedAttack.aim({0,0}, world.distance(self.targetPosition, mcontroller.position()))
    rangedAttack.fireContinuous()
  else
    rangedAttack.stopFiring()
  end
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  status.addEphemeralEffect("monsterdespawn")
end
