require "/scripts/vec2.lua"

function init()
  self.returning = config.getParameter("returning", false)
  self.returnOnHit = config.getParameter("returnOnHit", false)
  self.pickupDistance = config.getParameter("pickupDistance")
  self.timeToLive = config.getParameter("timeToLive")
  self.speed = config.getParameter("speed")
  self.ownerId = projectile.sourceEntity()

  self.maxDistance = config.getParameter("maxDistance")
  self.stickTime = config.getParameter("stickTime", 0)

  self.initialPosition = mcontroller.position()
end

function update(dt)
  if self.ownerId and world.entityExists(self.ownerId) then
    if not self.returning then
      if self.stickTimer then
        self.stickTimer = math.max(0, self.stickTimer - dt)
        if self.stickTimer == 0 then
          self.returning = true
        end
      elseif mcontroller.stickingDirection() then
        self.stickTimer = self.stickTime
      elseif mcontroller.isColliding() then
        self.returning = true
      else
        local distanceTraveled = world.magnitude(mcontroller.position(), self.initialPosition)
        if distanceTraveled > self.maxDistance then
          self.returning = true
        end
      end
    else
      mcontroller.applyParameters({collisionEnabled=false})
      local toTarget = world.distance(world.entityPosition(self.ownerId), mcontroller.position())
      if vec2.mag(toTarget) < self.pickupDistance then
        projectile.die()
      else
        mcontroller.setVelocity(vec2.mul(vec2.norm(toTarget), self.speed))
      end
    end
  else
    projectile.die()
  end
end

function hit(entityId)
  if self.returnOnHit then self.returning = true end
end

function projectileIds()
  return {entity.id()}
end
