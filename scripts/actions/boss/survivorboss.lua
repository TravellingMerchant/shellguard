require "/scripts/rect.lua"

function cultistSphereDash(args, board)
  local targetPosition = world.entityPosition(args.target)
  local toTarget = world.distance(targetPosition, mcontroller.position())
  local curveDirection = util.toDirection(toTarget[1]) * util.toDirection(-toTarget[2])

  -- From the mid point in a line between the target and the sphere
  -- any point in a perpendicular line will be equidistant to the target and the sphere
  local mid = vec2.div(vec2.add(mcontroller.position(), targetPosition), 2)
  local perp = vec2.rotate(vec2.norm(toTarget), -curveDirection * math.pi/2)
  local anchorPosition = vec2.add(mid, vec2.mul(perp, world.magnitude(mcontroller.position(), targetPosition)))
  local preferredAnchorDistance = world.magnitude(mcontroller.position(), anchorPosition)

  repeat
    -- Circling around that equidistant point will always hit the target position
    local toAnchor = world.distance(anchorPosition, mcontroller.position())
    local tangential = vec2.rotate(vec2.norm(toAnchor), curveDirection)

    world.debugLine(mcontroller.position(), anchorPosition, "yellow")

    mcontroller.controlApproachVelocity(vec2.mul(tangential, args.speed), args.controlForce)
    local centripetalSpeed =  world.magnitude(anchorPosition, mcontroller.position()) - preferredAnchorDistance
    mcontroller.controlApproachVelocityAlongAngle(vec2.angle(toAnchor), centripetalSpeed, args.centripetalForce)

    coroutine.yield("running")

    -- Continue while going roughly in the target's direction or until hitting a wall or the floor
    local bounds = rect.pad(rect.translate(mcontroller.boundBox(), mcontroller.position()), 0.25)
    toTarget = world.distance(targetPosition, mcontroller.position())
  until vec2.dot(mcontroller.velocity(), toTarget) < 0

  return true
end
