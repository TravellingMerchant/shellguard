sgApexbossRockets = {}

function sgApexbossRockets.enter()
  self.headRotationCenter = config.getParameter("sgApexbossRockets.headRotationCenter", {0, 0})
  self.projectileSpawnOffset = config.getParameter("sgApexbossRockets.projectileSpawnOffset", {0, 0})
  self.headAngleOffset = config.getParameter("sgApexbossRockets.headAngleOffset", 1)
  self.chargeUpTime = config.getParameter("sgApexbossRockets.chargeUpTime", 0)
  self.holdAim = config.getParameter("sgApexbossRockets.holdAim", false)
  self.targetAimFound = false
  self.worldFirePoint = {0, 0}
  
  self.targetAngle = 0
  
  self.angleApproach = config.getParameter("sgApexbossRockets.angleApproach", 1)
  
  self.burstCount = config.getParameter("sgApexbossRockets.burstCount", 1)
  self.burstTime = config.getParameter("sgApexbossRockets.burstTime", 0.1)
  self.burstTimer = self.burstTime

  return {
    projectileType = config.getParameter("sgApexbossRockets.projectileType", "dragonblockbuster"),
    projectileParameters = config.getParameter("sgApexbossRockets.projectileParameters", {}),
    trackSourceEntity = config.getParameter("sgApexbossRockets.trackSourceEntity", false)
  }
end

function sgApexbossRockets.enteringState(stateData)  
  animator.setAnimationState("head", "attackWindup")
  animator.playSound("laserWindup")
end

function sgApexbossRockets.update(dt, stateData)
  self.worldFirePoint = vec2.add({animator.partPoint("head", "projectileSpawnOffset")[1], animator.partPoint("head", "projectileSpawnOffset")[2]}, mcontroller.position())
  if self.chargeUpTime > 0 then
	self.chargeUpTime = math.max(0, self.chargeUpTime - dt)
  elseif self.burstCount == 0 and self.headAngle == 0 then
	return true
  elseif self.burstCount > 0 then
    local projSpawnOffset = {animator.partPoint("head", "projectileSpawnOffset")[1] * mcontroller.facingDirection(), animator.partPoint("head", "projectileSpawnOffset")[2]}
	self.burstTimer = math.max(0, self.burstTimer - dt)
    if self.burstCount > 0 and self.burstTimer == 0 then
	  --Fire Projectile--
	  rangedAttack.aim(projSpawnOffset, self.toTarget)
      animator.playSound("laserFire")
	  rangedAttack.fireOnce(stateData.projectileType, stateData.projectileParameters)
	  
	  self.burstCount = self.burstCount - 1
	  self.burstTimer = self.burstTime
	  
	  if self.burstCount == 0 then  
	    animator.setAnimationState("head", "attackWinddown")
	  end
	end
  end
  
  if self.targetPosition ~= nil then
    flyTo({
      self.targetPosition[1],
      self.spawnPosition[2]
    })
  else
    mcontroller.controlFly({ 0, 1 })
  end
  
  sgApexbossRockets.updateHead(stateData)
end

function sgApexbossRockets.updateHead(stateData)
  animator.resetTransformationGroup("head")
  
  local entityId = world.playerQuery(mcontroller.position(), 300, {includedTypes = {"player"}, order = "nearest"})[1]
  
  if entityId and self.burstCount > 0 then
	if not self.targetAimFound then
      local estimatedPosition = world.distance(mcontroller.position(), world.entityPosition(entityId))
      mcontroller.controlFace(world.distance(mcontroller.position(), world.entityPosition(entityId))[1])
      self.targetAngle = vec2.angle(estimatedPosition) * (mcontroller.facingDirection() * -1)
	  self.toTarget = vec2.norm(world.distance(self.targetPosition, self.worldFirePoint))
	  
	  if estimatedPosition[1] < 0 and not self.holdAim then
	    self.targetAngle = self.targetAngle - math.pi + (self.headAngleOffset)
	  elseif estimatedPosition[1] > 0 and not self.holdAim then
	    self.targetAngle = self.targetAngle + (self.headAngleOffset * 1.0)
	  elseif self.holdAim then
	    local angleAdjust = (estimatedPosition[1] < 0) and math.pi/2 or 0 + self.headAngleOffset * (estimatedPosition[1] < 0 and 1.8 or 1)
	    self.targetAngle = (self.targetAngle * (estimatedPosition[1] < 0 and -1 or 1)) - angleAdjust
	  end
	  
	  self.targetAimFound = self.holdAim
    end
  elseif self.burstCount == 0 then
    self.targetAngle = 0
  end

  self.headAngle = (self.headAngle or 0) + (self.targetAngle - (self.headAngle or 0)) * self.angleApproach
  world.debugLine(self.worldFirePoint, world.entityPosition(entityId), "orange")
  animator.rotateTransformationGroup("head", self.headAngle, self.headRotationCenter)
end

function sgApexbossRockets.leavingState(stateData)
end
