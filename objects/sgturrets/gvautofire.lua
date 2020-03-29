-- Coroutine
function fireRoutine()
  local level = math.max(1.0, world.threatLevel())
  local power = config.getParameter("power", 2)
  power = root.evalFunction("monsterLevelPowerMultiplier", level) * power
  local fireTime = config.getParameter("fireTime", 0.1)
  local projectileParameters = config.getParameter("projectileParameters", {})
  local energyUsage = config.getParameter("energyUsage")
  projectileParameters.power = power

  while true do
    while not consumeEnergy(energyUsage) do coroutine.yield() end

    local rotation = animator.currentRotationAngle("gun")
    local aimVector = {object.direction() * math.cos(rotation), math.sin(rotation)}
    aimVector = vec2.rotate(aimVector, sb.nrand(self.inaccuracy, 0))
    
    world.spawnProjectile(self.projectileType, firePosition(false), entity.id(), aimVector, false, projectileParameters)
    animator.playSound("fire")
    util.wait(fireTime)
  end
end