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
  self.hasStuck = false
  
  self.actionOnHold = config.getParameter("actionOnHold")

  self.initialPosition = mcontroller.position()
  self.gunPosition = vec2.sub(self.initialPosition, world.entityPosition(self.ownerId))
end

function update(dt)
  if self.ownerId and world.entityExists(self.ownerId) then	
	--Actions during inital being shot
    if not self.returning then
      if self.stickTimer then
		mcontroller.setVelocity({0,0})
        self.stickTimer = math.max(0, self.stickTimer - dt)
        if self.stickTimer == 0 then
          self.returning = true
        end
      elseif mcontroller.stickingDirection() then
        self.stickTimer = self.stickTime
      elseif mcontroller.isColliding() then
		--Manually stick on collide
        self.stickTimer = self.stickTime
		--Manually cause actions rather than on collision because it repeats with this method
		if self.actionOnHold then
		  for _, action in pairs(self.actionOnHold) do
		    projectile.processAction(action)
		  end
	    end
      else
        local distanceTraveled = world.magnitude(mcontroller.position(), self.initialPosition)
        if distanceTraveled > self.maxDistance then
          self.waitTime = self.waitTimer
		  self.returning = true
        end
      end
	--Returning actions
    else
      mcontroller.applyParameters({collisionEnabled=false})
      local toTarget = world.distance(vec2.add(self.gunPosition, world.entityPosition(self.ownerId)), mcontroller.position())
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
