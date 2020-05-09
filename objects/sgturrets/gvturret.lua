require "/scripts/poly.lua"
require "/scripts/interp.lua"

function init()
  -- Positions and angles
  self.baseOffset = config.getParameter("baseOffset")
  self.basePosition = vec2.add(object.position(), self.baseOffset)
  
  self.animateShutdown = config.getParameter("animateShutdown", false)
  self.offAngle = util.toRadians(config.getParameter("offAngle", -30))  
  self.offAngle = util.wrapAngle(self.offAngle + util.toRadians(config.getParameter("offAngleOffset", 0)))
  
  self.offVector = vec2.rotate(config.getParameter("offVector", {0, 0}), self.offAngle)
  self.offTime = config.getParameter("offTime", 1)
  self.offTimer = 0
  
  self.errorMargin = 0.0001
  
  self.weaponOffset = {0, 0}
  self.turretAngleOffset = util.toRadians(config.getParameter("turretAngleOffset", 0)) 

  -- Targeting
  self.targetQueryRange = config.getParameter("targetQueryRange")
  self.targetMinRange = config.getParameter("targetMinRange")
  self.targetMaxRange = config.getParameter("targetMaxRange")
  self.targetAngleRange = util.toRadians(config.getParameter("targetAngleRange"))
  
  self.scanTime = config.getParameter("scanTime", 1.0)
  self.scanCooldown = config.getParameter("scanCooldown", 1.0)
  
  self.projectileType = config.getParameter("projectileType", "bullet-1")
  self.inaccuracy = config.getParameter("inaccuracy")
  
  self.multiBarrel = config.getParameter("multiBarrel", false)
  self.firePoints = {}
  self.firePos = 0
  
  self.forceBurst = false --if true, the turret is forced to fire. Use responsibly.
  self.forceAngle = false --if true, the turret's angle is being held prisoner. Use responsibly.
  
  self.smartTracking = config.getParameter("smartTracking", false)
  
  self.powerOnly = config.getParameter("powerOnly", false)
  
  -- Energy
  self.regenBlockTimer = 0
  self.energyRegen = config.getParameter("energyRegen")
  self.maxEnergy = config.getParameter("maxEnergy")
  self.energyRegenBlock = config.getParameter("energyRegenBlock")
  self.energyUsage = config.getParameter("energyUsage")
  
  storage.energy = storage.energy or self.maxEnergy

  self.energyBarOffset = config.getParameter("energyBarOffset")
  self.energyBarSize = config.getParameter("energyBarSize", 11)
  self.verticalScaling = config.getParameter("verticalScaling")
  
  animator.translateTransformationGroup("energy", self.energyBarOffset)

  -- Initialize turret
  if self.multiBarrel then
    if type(animator.partProperty("gun", "projectileSource")[1]) ~= "table" then
      local arraySize = config.getParameter("arraySize")
      local arrayOffset = config.getParameter("arrayOffset")
      
      for i = 1, arraySize[1] do
        for j = 1, arraySize[2] do
          self.firePoints[(i-1)*arraySize[2]+j] = {arrayOffset[1] * (i-1), arrayOffset[2] * (j-1)}
        end
      end
    end
  end
  
  object.setInteractive(false)
  
  if initRoutine then initRoutine() end

  self.state = FSM:new()
  self.state:set(offState)
end

function update(dt)
  self.state:update(dt)

  if self.multiBarrel then
    local firePos = firePosition(true)
    world.debugPoint(firePos[1], "cyan")
    for i = 2, #firePos do
      world.debugPoint(firePos[i], "green")
    end
  else
    world.debugPoint(firePosition(true), "green")
  end

  if storage.energy < self.energyUsage then
    self.blockEnergyUsage = true
  elseif storage.energy >= self.maxEnergy then
    self.blockEnergyUsage = false
  end

  if self.regenBlockTimer > 0 then
    self.regenBlockTimer = math.max(0, self.regenBlockTimer - script.updateDt())
  else
    storage.energy = math.min(self.maxEnergy, storage.energy + self.energyRegen * script.updateDt())
  end

  local ratio = storage.energy / self.maxEnergy
  local animationState = "full"

  if ratio <= 0.75 then animationState = "high" end
  if ratio <= 0.5 then animationState = "medium" end
  if ratio <= 0.25 then animationState = "low" end
  if ratio <= 0 then animationState = "none" end

  local scale = self.verticalScaling and {1, ratio * self.energyBarSize} or {ratio * self.energyBarSize, 1}

  if self.animateShutdown then
    animator.resetTransformationGroup("weapon")
    animator.translateTransformationGroup("weapon", vec2.rotate(self.weaponOffset, self.turretAngleOffset))
    
    animator.resetTransformationGroup("stand")
    animator.translateTransformationGroup("stand", self.weaponOffset)
  end
  
  animator.resetTransformationGroup("energy")
  animator.scaleTransformationGroup("energy", scale)
  animator.translateTransformationGroup("energy", self.energyBarOffset)

  animator.setAnimationState("energy", animationState)
end

----------------------------------------------------------------------------------------------------------
-- States

function offState()
  if not self.animateShutdown then 
    animator.stopAllSounds("powerUp")
    animator.playSound("powerDown")
  end
  object.setAllOutputNodes(false)

  while true do
    animator.rotateGroup("gun", self.offAngle)
    
    if self.offTimer == 0 then return self.state:set(closeState) end --I give up.
    
    world.debugPoint(self.basePosition, "red")
    
    if active() then break end
    coroutine.yield()
  end

  animator.stopAllSounds("powerDown")
  animator.playSound("powerUp")

  if self.animateShutdown then
    self.state:set(openState)
  else
    self.state:set(scanState)
  end
end

function closeState()
  animator.stopAllSounds("powerUp")
  animator.playSound("powerDown")
  animator.setAnimationState("attack", "dead")

  while true do
    world.debugText("%s:%s:%s",  math.abs(util.angleDiff(animator.currentRotationAngle("gun"), self.offAngle)) > self.errorMargin, self.offTimer, self.offTime, vec2.add(object.position(), {0, 3}), "cyan")
    if math.abs(util.angleDiff(animator.currentRotationAngle("gun"), self.offAngle)) > self.errorMargin then
      animator.rotateGroup("gun", self.offAngle)
      self.offTimer = 0
    else
      self.offTimer = math.min(self.offTimer + script.updateDt(), self.offTime)
      
      if self.offTimer <= self.offTime then
        self.weaponOffset = vec2.mul(self.offVector, self.offTimer / self.offTime)
      end
    end

    world.debugPoint(self.basePosition, "cyan")
    
    if self.offTimer == self.offTime then break end
    coroutine.yield()
  end

  self.state:set(offState)
end

function openState()
  local scanAngle = util.toRadians(config.getParameter("scanBaseAngle", 0))
  
  while true do
    world.debugText("%s:%s", self.offTimer, self.offTime, vec2.add(object.position(), {0, 3}), "green")
    world.debugPoint(self.basePosition, "green")
    
    if self.offTimer ~= 0 then
      self.offTimer = math.max(self.offTimer - script.updateDt(), 0)
      self.weaponOffset = vec2.mul(self.offVector, self.offTimer / self.offTime)
    else
      self.weaponOffset = {0, 0}
      animator.rotateGroup("gun", scanAngle)
    end
    
    if (math.abs(util.angleDiff(animator.currentRotationAngle("gun"), scanAngle)) < self.targetAngleRange) and self.offTimer == 0 then break end
    coroutine.yield()
  end

  self.state:set(scanState)
end

function scanState()
  local scanInterval = config.getParameter("scanInterval")
  local scanAngle = util.toRadians(config.getParameter("scanAngle"))
  local scanBaseAngle = util.toRadians(config.getParameter("scanBaseAngle", 0))
  
  animator.setAnimationState("attack", "idle")
  util.wait(self.scanCooldown)
  animator.playSound("scan")
  object.setAllOutputNodes(false)

  local timer = 0

  local scan = coroutine.wrap(function()
    while true do
      local target
      if findTargetRoutine then
        target = findTargetRoutine()
      else
        target = findTarget()
      end
      
      if target then return self.state:set(fireState, target) end
      util.wait(self.scanCooldown)
    end
  end)

  while true do
    timer = timer + script.updateDt() / scanInterval
    if timer > 1 then timer = 0 end
    animator.rotateGroup("gun", scanBaseAngle + scanAngle * math.sin(timer * math.pi*2))

    scan()
    
    world.debugPoint(self.basePosition, "blue")

    if not active() then break end
    coroutine.yield()
  end

  if self.animateShutdown then
    self.state:set(closeState)
  else
    self.state:set(offState)
  end
end

function fireState(targetId)
  animator.setAnimationState("attack", "attack")
  animator.playSound("foundTarget")
  object.setAllOutputNodes(true)

  local maxFireAngle = util.toRadians(config.getParameter("maxFireAngle"))
  local fire = coroutine.wrap(fireRoutine)

  while true do
    if not active() and not self.forceBurst then
      if breakRoutine then breakRoutine() end
      if self.animateShutdown then
        return self.state:set(closeState)
      else
        return self.state:set(offState)
      end
    end

    if not world.entityExists(targetId) and not self.forceBurst then break end

    local targetPosition = targetCoords(targetId)
    local toTarget = world.distance(targetPosition, self.basePosition)
    local targetDistance = world.magnitude(toTarget)
    local targetAngle = math.atan(toTarget[2], object.direction() * toTarget[1])

    if (targetDistance > self.targetMaxRange or targetDistance < self.targetMinRange or world.lineTileCollision(self.basePosition, targetPosition)) and not self.forceBurst then break end
    if (math.abs(targetAngle) > self.targetAngleRange) and not self.forceBurst then break end
    targetAngle = util.clamp(targetAngle, -self.targetAngleRange, self.targetAngleRange)
    
    if self.forceAngle then
      animator.rotateGroup("gun", animator.currentRotationAngle("gun"))
    else
      animator.rotateGroup("gun", targetAngle)
    end
    
    world.debugPoint(self.basePosition, "orange")
    world.debugPoint(targetPosition, "orange")

    local rotation = animator.currentRotationAngle("gun")
    if (math.abs(util.angleDiff(targetAngle, rotation)) < maxFireAngle) or self.forceBurst then
      fire(targetId)
    end
    coroutine.yield()
  end
  
  if breakRoutine then breakRoutine() end
  
  util.wait(self.scanCooldown)

  self.state:set(scanState)
end

----------------------------------------------------------------------------------------------------------
-- Helping functions, not states

function consumeEnergy(amount)
  if storage.energy < amount or self.blockEnergyUsage then return false end
  storage.energy = storage.energy - amount
  self.regenBlockTimer = self.energyRegenBlock
  return true
end

function active()
  if object.isInputNodeConnected(0) then
    return object.getInputNodeLevel(0) ~= self.powerOnly
  end

  storage.active = storage.active ~= nil and storage.active or true
  return storage.active
end

function firePosition(simulate)
  local animationPosition = vec2.div(config.getParameter("animationPosition"), 8)
  local fireOffset = {0,0}
  
  if self.multiBarrel then
    if not simulate then
      local projectileSource = firePoints() or animator.partPoly("gun", "projectileSource")
      
      self.firePos = (self.firePos - 1) % #projectileSource
      
      --sb.logInfo("%s", self.firePos)
      
      local firePos = projectileSource[self.firePos+1]
      fireOffset = vec2.add(animationPosition, firePos)
    else return poly.translate(poly.translate(firePoints() or animator.partPoly("gun", "projectileSource"), object.position()), animationPosition)
    end
  else
    fireOffset = vec2.add(animationPosition, animator.partPoint("gun", "projectileSource"))
  end
  return vec2.add(object.position(), fireOffset)
end

function firePoints()
  --sb.logInfo("%s", self.firePoints)
  if next(self.firePoints) == nil then return nil end
  
  local firePoints = poly.scale(self.firePoints, {object.direction(), object.direction()})
  firePoints = poly.rotate(firePoints, animator.currentRotationAngle("gun"))
  firePoints = poly.scale(firePoints, {1, object.direction()})
  firePoints = poly.translate(firePoints, animator.partPoint("gun", "projectileSource"))
  
  return firePoints
end

function targetCoords(targetId)
  if world.entityPosition(targetId) == nil then return vec2.add(object.position(), {self.targetMaxRange * object.direction(), 0}) end
  local targetPosition = world.entityPosition(targetId)
  if self.smartTracking then
    local flightTime = world.magnitude(targetPosition, self.basePosition) / projectileSpeed()
    local vel = world.entityVelocity(targetId)
    vel = vec2.mul(vel, flightTime)
    targetPosition = vec2.add(targetPosition, vel)
  end
  return targetPosition
end

function projectileSpeed()
  local projectileParameters = config.getParameter("projectileParameters", {})
  if projectileParameters and projectileParameters.speed then return projectileParameters.speed
  else
    local config = root.projectileConfig(self.projectileType)
    return config.speed
  end
end

-- Coroutine
function findTarget()
  local nearEntities = world.entityQuery(self.basePosition, self.targetQueryRange, { includedTypes = { "monster", "npc", "player" } })
  
  
  return util.find(nearEntities, function(entityId)
    local targetPosition = world.entityPosition(entityId)
    local toTarget = world.distance(targetPosition, self.basePosition)
	local targetAngle = math.atan(toTarget[2], object.direction() * toTarget[1])
	
	if (not entity.isValidTarget(entityId)) or (math.abs(targetAngle) > self.targetAngleRange) or (world.magnitude(toTarget) < self.targetMinRange) or (world.lineTileCollision(self.basePosition, targetPosition)) then
		return false
	end

    return true
  end)
end
