require "/scripts/poly.lua"

-- Coroutine

function initRoutine()
  object.setAnimationParameter("beams", {})
  self.minHP = config.getParameter("minHP", 100) * root.evalFunction("monsterLevelHealthMultiplier", math.max(1.0, world.threatLevel()))
end

--the beginning is the config - there are no values that suddenly load in the middle of the routine, since the object never moves.
function fireRoutine()
  local level = math.max(1.0, world.threatLevel())
  local power = config.getParameter("power", 2)
  power = root.evalFunction("monsterLevelPowerMultiplier", level) * power
  
  local beamLength = config.getParameter("maxBeamLength", 24)
  local beamWidth = config.getParameter("beamWidth", 5)
  local beamWidthOffset = config.getParameter("beamWidthOffset", 0.5)
  local damageSource = config.getParameter("damageSource", {})
  local energyUsage = config.getParameter("energyUsage")
  
  damageSource.damage = power
  damageSource.damageRepeatTimeout = config.getParameter("fireTime", 4)
  local chargeTime = config.getParameter("chargeTime", 0.5)
  local beamTime = config.getParameter("beamTime", 0.5)
  local beamCooldownTime = config.getParameter("beamCooldownTime", 0.0625)
  
  local beamStreamImages = config.getParameter("beamStreamImages")
  
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
      local beams = {}
      local damageSources = {}
      
      for i = 0, beamWidth - 1 do
        local localStart = beamStart
        local localEnd = beamEnd
        
        local offsetVector = vec2.mul({0, beamWidthOffset}, math.ceil(i / 2) * ((-1) ^ i))
        offsetVector = vec2.rotate(offsetVector, vec2.angle(aimVector))
        
        localStart = vec2.add(localStart, offsetVector)
        localEnd = vec2.add(localEnd, offsetVector)
        
        local collidePoint = world.lineCollision(localStart, localEnd)
        
        if not collidePoint then
           collidePoint = localEnd
        end
          
        local line = {localStart, collidePoint}
        line = poly.translate(line, vec2.mul(entity.position(), -1))
        damageSource.line = line
        table.insert(damageSources, copy(damageSource))
        
        local beam
        if (beamWidth - i) > 2 then
          beam = {
            startPosition = localStart,
            endPosition = collidePoint,
            first = beamStreamImages.middle.first,
            body = beamStreamImages.middle.body,
            last = beamStreamImages.middle.last
          }
        elseif (beamWidth - i) == 1 then
          beam = {
            startPosition = localStart,
            endPosition = collidePoint,
            first = beamStreamImages.top.first,
            body = beamStreamImages.top.body,
            last = beamStreamImages.top.last
          }
        else
          beam = {
            startPosition = localStart,
            endPosition = collidePoint,
            first = beamStreamImages.bottom.first,
            body = beamStreamImages.bottom.body,
            last = beamStreamImages.bottom.last
          }
        end
        table.insert(beams, beam)
      end
      
      object.setAnimationParameter("beams", beams)
      object.setDamageSources(damageSources)
    end)
    
    object.setAnimationParameter("beams", {})
    object.setDamageSources()
    
    util.wait(beamCooldownTime, function()
      local beams = {}
      
      for i = 0, beamWidth - 1 do
        local localStart = beamStart
        local localEnd = beamEnd
        
        local offsetVector = vec2.mul({0, beamWidthOffset}, math.ceil(i / 2) * ((-1) ^ i))
        offsetVector = vec2.rotate(offsetVector, vec2.angle(aimVector))
        
        localStart = vec2.add(localStart, offsetVector)
        localEnd = vec2.add(localEnd, offsetVector)
        
        local collidePoint = world.lineCollision(localStart, localEnd)
        
        if not collidePoint then
           collidePoint = localEnd
        end
        
        local beam
        if (beamWidth - i) > 2 then
          beam = {
            startPosition = localStart,
            endPosition = collidePoint,
            first = beamStreamImages.middleWeak.first,
            body = beamStreamImages.middleWeak.body,
            last = beamStreamImages.middleWeak.last
          }
        elseif (beamWidth - i) == 1 then
          beam = {
            startPosition = localStart,
            endPosition = collidePoint,
            first = beamStreamImages.topWeak.first,
            body = beamStreamImages.topWeak.body,
            last = beamStreamImages.topWeak.last
          }
        else
          beam = {
            startPosition = localStart,
            endPosition = collidePoint,
            first = beamStreamImages.bottomWeak.first,
            body = beamStreamImages.bottomWeak.body,
            last = beamStreamImages.bottomWeak.last
          }
        end
        table.insert(beams, beam)
      end
      object.setAnimationParameter("beams", beams)
    end)
    
    self.forceAngle = false
    self.forceBurst = false
    object.setAnimationParameter("beams", {})
    
    util.wait(damageSource.damageRepeatTimeout - chargeTime - beamTime - beamCooldownTime)
  end
  
  breakRoutine()
end

function breakRoutine()
  self.forceAngle = false
  self.forceBurst = false
  object.setAnimationParameter("beams", {})
  object.setDamageSources()
end

function findTargetRoutine()
  local nearEntities = world.entityQuery(self.basePosition, self.targetQueryRange, { includedTypes = { "monster", "npc", "player" } })
  return util.find(nearEntities, function(entityId)
    local targetPosition = world.entityPosition(entityId)
    if not entity.isValidTarget(entityId) or world.lineTileCollision(self.basePosition, targetPosition) then return false end
    
    if world.entityHealth(entityId)[2] < self.minHP and (world.entityType(entityId) ~= "npc")  then return false end

    local toTarget = world.distance(targetPosition, self.basePosition)
    local targetAngle = math.atan(toTarget[2], object.direction() * toTarget[1])
    return world.magnitude(toTarget) > self.targetMinRange and math.abs(targetAngle) < self.targetAngleRange
  end)
end