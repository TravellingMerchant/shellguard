-- Coroutine
function fireRoutine()
  local burstCount = config.getParameter("burstCount")
  if burstCount == nil then
    if self.multiBarrel then
      local arraySize = config.getParameter("arraySize")
      burstCount = arraySize[1] * arraySize[2]
    else
      burstCount = 4 --Chosen by a fair dice roll.
    end
  end
  
  local fireTime = config.getParameter("fireTime", 0.1)
  local burstTime = config.getParameter("burstTime", fireTime)
  local energyUsage = config.getParameter("energyUsage") * burstCount

  local level = math.max(1.0, world.threatLevel())
  local projectileParameters = config.getParameter("projectileParameters", {})
  local power = config.getParameter("power", 2)
  power = root.evalFunction("monsterLevelPowerMultiplier", level) * power
  projectileParameters.power = power

  while true do
    while not consumeEnergy(energyUsage) do coroutine.yield() end
    local shots = burstCount
    self.forceBurst = true
    
    while shots > 0 do
      shots = shots - 1
      
      local rotation = animator.currentRotationAngle("gun")
      local aimVector = {object.direction() * math.cos(rotation), math.sin(rotation)}
      aimVector = vec2.rotate(aimVector, sb.nrand(self.inaccuracy, 0))
      
      world.spawnProjectile(self.projectileType, firePosition(false), entity.id(), aimVector, false, projectileParameters)
      animator.playSound("fire")
      
      util.wait(burstTime)
    end
    
    self.forceBurst = false
    util.wait((fireTime - burstTime) * burstCount)
  end
end