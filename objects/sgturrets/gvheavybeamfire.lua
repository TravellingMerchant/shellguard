require "/scripts/poly.lua"

-- Coroutine

function initRoutine()
  object.setAnimationParameter("beams", {})
end

--the beginning is the config - there are no values that suddenly load in the middle of the routine, since the object never moves.
function fireRoutine()
  local level = math.max(1.0, world.threatLevel())
  local power = config.getParameter("power", 2)
  power = root.evalFunction("monsterLevelPowerMultiplier", level) * power
  
  local beamLength = config.getParameter("maxBeamLength", 24)
  local damageSource = config.getParameter("damageSource", {})
  local energyUsage = config.getParameter("energyUsage")
  
  damageSource.damage = power
  damageSource.damageRepeatTimeout = config.getParameter("fireTime", 0.1)
  local chargeTime = config.getParameter("chargeTime", false)
  local beamTime = config.getParameter("beamTime", 0.05)
  local beamCooldownTime = config.getParameter("beamCooldownTime", 0.025)
  
  local beamWeakImages = config.getParameter("beamWeakImages")
  
  object.setAnimationParameter("requireProjectile", false)
  
  while true do
    while not consumeEnergy(energyUsage) do
      breakRoutine()
      util.wait(damageSource.damageRepeatTimeout)
    end
    
    --force the gun to do the entire animation
    self.forceBurst = true
    self.forceAngle = true
    
    --ready up the turret
    local rotation = animator.currentRotationAngle("gun")
    local aimVector = {object.direction() * math.cos(rotation), math.sin(rotation)}
    aimVector = vec2.rotate(aimVector, sb.nrand(self.inaccuracy, 0))
    
    local beamStart = firePosition(false)
    local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(aimVector), beamLength))
      
    if chargeTime then
      animator.playSound("charge")
      util.wait(chargeTime)
      animator.stopAllSounds("charge")
    end
    
    animator.playSound("fire")
    
    util.wait(beamTime, function()
      local collidePoint = world.lineCollision(beamStart, beamEnd)
      
      if not collidePoint then
         collidePoint = beamEnd
      end 
      
      local line = {beamStart, collidePoint}
      line = poly.translate(line, vec2.mul(entity.position(), -1))
      damageSource.line = line
      
      object.setAnimationParameter("beams", {
        {
          startPosition = beamStart,
          endPosition = collidePoint
        }  
      })
      object.setDamageSources({damageSource})
    end)
    
    object.setAnimationParameter("beams", {})
    object.setDamageSources()
    
    util.wait(beamCooldownTime, function()
      local collidePoint = world.lineCollision(beamStart, beamEnd)
      
      if not collidePoint then
         collidePoint = beamEnd
      end
      
      object.setAnimationParameter("beams", {
        {
          startPosition = beamStart,
          endPosition = collidePoint,
          first = beamWeakImages.first,
          body = beamWeakImages.body,
          last = beamWeakImages.last
        }  
      })
    end)
    
    self.forceAngle = false
    self.forceBurst = false
    object.setAnimationParameter("beams", {})
    
    util.wait(damageSource.damageRepeatTimeout - (chargeTime or 0) - beamTime - beamCooldownTime)
  end
  
  breakRoutine()
end

function breakRoutine()
  self.forceAngle = false
  self.forceBurst = false
  object.setAnimationParameter("beams", {})
  object.setDamageSources()
end
