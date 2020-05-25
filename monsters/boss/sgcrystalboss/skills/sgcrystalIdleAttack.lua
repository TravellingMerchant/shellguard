--Not really an attack, just some idle time between attacks
sgcrystalIdleAttack = {}

function sgcrystalIdleAttack.enter()
  if not hasTarget() then return nil end

  return {
    timer = 0,
    bobInterval = 0.5,
    bobHeight = 0.1,
    idleTime = config.getParameter("sgcrystalIdleAttack.idleTime", 2.5)
  }
end

function sgcrystalIdleAttack.enteringState(stateData)
end

function sgcrystalIdleAttack.update(dt, stateData)
  stateData.timer = stateData.timer + dt

  sgcrystalIdleAttack.bob(dt, stateData)

  if stateData.timer > stateData.idleTime then
    return true
  end
end

function sgcrystalIdleAttack.bob(dt, stateData)
  local bobOffset = math.sin(((stateData.timer % stateData.bobInterval) / stateData.bobInterval) * math.pi * 2) * stateData.bobHeight
  local targetPosition = {self.spawnPosition[1], self.spawnPosition[2] + bobOffset}
  local toTarget = world.distance(targetPosition, mcontroller.position())

  mcontroller.controlApproachVelocity(vec2.mul(toTarget, 1/dt), 30)
end
