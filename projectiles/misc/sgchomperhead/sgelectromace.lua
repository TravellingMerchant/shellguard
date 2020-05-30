boomerangExtra = {}

function boomerangExtra:init()
  self.targetPosition = nil
end

function setTargetPosition(position)
  boomerangExtra.targetPosition = position
end

function boomerangExtra:update(dt)
  if self.targetPosition then
    local toTarget = world.distance(self.targetPosition, mcontroller.position())
    mcontroller.approachVelocity(vec2.mul(vec2.norm(toTarget), config.getParameter("speed")), config.getParameter("targetTrackingForce"))
  end
end

function boomerangExtra:projectileIds()
  return { entity.id() }
end
