require "/scripts/poly.lua"

-- Coroutine

function initRoutine()
  object.setAnimationParameter("beams", {})
end

function fireRoutine()
  local level = math.max(1.0, world.threatLevel())
  local power = config.getParameter("power", 2)
  power = root.evalFunction("monsterLevelPowerMultiplier", level) * power
  
  local beamLength = config.getParameter("maxBeamLength", 24)
  local damageSource = config.getParameter("damageSource", {})
  local energyUsage = config.getParameter("energyUsage")
  
  damageSource.damage = power
  damageSource.damageRepeatTimeout = config.getParameter("fireTime", 0.1)
  
  animator.playSound("fire", -1)
  object.setAnimationParameter("requireProjectile", false)
  
  while true do
    while not consumeEnergy(energyUsage * damageSource.damageRepeatTimeout) do
      breakRoutine()
      util.wait(self.scanCooldown)
    end

    local rotation = animator.currentRotationAngle("gun")
    local aimVector = {object.direction() * math.cos(rotation), math.sin(rotation)}
    aimVector = vec2.rotate(aimVector, sb.nrand(self.inaccuracy, 0))
    
    local beamStart = firePosition(false)
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(aimVector), beamLength))
    
    local collidePoint = world.lineCollision(beamStart, beamEnd)
    
    if collidePoint then
      beamEnd = collidePoint
    end
    
    local line = {beamStart, beamEnd}
    line = poly.translate(line, vec2.mul(entity.position(), -1))
    
    damageSource.line = line
    
    object.setDamageSources({damageSource})
    object.setAnimationParameter("beams", {
      {
        startPosition = beamStart,
        endPosition = beamEnd
      }  
    })
    
    coroutine.yield()
  end
  
  breakRoutine()
end

function breakRoutine()
  object.setAnimationParameter("beams", {})
  object.setDamageSources()
  animator.stopAllSounds("fire")
end
