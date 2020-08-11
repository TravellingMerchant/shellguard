sgChomperFlyAroundAndShoot = {}

function sgChomperFlyAroundAndShoot.enter()
  self.headRotationCenter = config.getParameter("sgChomperFlyAroundAndShoot.headRotationCenter", {0, 0})
  self.projectileSpawnOffset = config.getParameter("sgChomperFlyAroundAndShoot.projectileSpawnOffset", {0, 0})
  self.headAngleOffset = config.getParameter("sgChomperFlyAroundAndShoot.headAngleOffset", 1)
  self.chargeUpTime = config.getParameter("sgChomperHeadLaser.chargeUpTime", 0)
  self.targetTimer = config.getParameter("sgChomperHeadLaser.targetingTime", 0)
  self.holdAim = config.getParameter("sgChomperFlyAroundAndShoot.holdAim", false)
  self.targetAimFound = false
  
  self.targetAngle = 0
  
  self.angleApproach = config.getParameter("sgChomperFlyAroundAndShoot.angleApproach", 1)
  
  self.burstCount = config.getParameter("sgChomperFlyAroundAndShoot.burstCount", 1)
  self.burstTime = config.getParameter("sgChomperFlyAroundAndShoot.burstTime", 0.1)
  self.burstTimer = self.burstTime

  return {
    projectileType = config.getParameter("sgChomperFlyAroundAndShoot.projectileType", "dragonblockbuster"),
    projectileParameters = config.getParameter("sgChomperFlyAroundAndShoot.projectileParameters", {}),
    trackSourceEntity = config.getParameter("sgChomperFlyAroundAndShoot.trackSourceEntity", false)
  }
end

function sgChomperFlyAroundAndShoot.enteringState(stateData)  
  animator.setAnimationState("head", "attackWindup")
  animator.playSound("laserWindup")
end

function sgChomperFlyAroundAndShoot.update(dt, stateData)
  if self.targetTimer > 0 then
	self.targetTimer = math.max(0, self.targetTimer - dt)
  elseif self.chargeUpTime > 0 then
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
  
  sgChomperFlyAroundAndShoot.updateHead(stateData)
end

function sgChomperFlyAroundAndShoot.updateHead(stateData)
  animator.resetTransformationGroup("head")
  
  local entityId = world.playerQuery(mcontroller.position(), 300, {includedTypes = {"player"}, order = "nearest"})[1]
  
  if entityId and self.burstCount > 0 then
	if not self.targetAimFound then
      local estimatedPosition = world.distance(mcontroller.position(), world.entityPosition(entityId))
      mcontroller.controlFace(world.distance(mcontroller.position(), world.entityPosition(entityId))[1])
      self.targetAngle = vec2.angle(estimatedPosition) * (mcontroller.facingDirection() * -1)
	  self.toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(self.projectileSpawnOffset)))
	  
	  if estimatedPosition[1] < 0 and not self.holdAim then
	    self.targetAngle = self.targetAngle - math.pi + util.toRadians(self.headAngleOffset)
	  elseif estimatedPosition[1] > 0 and not self.holdAim then
	    self.targetAngle = self.targetAngle + util.toRadians(self.headAngleOffset * 1.0) 
	  elseif self.holdAim then
	    local angleAdjust = (estimatedPosition[1] < 0) and math.pi/2 or 0 + self.headAngleOffset * (estimatedPosition[1] < 0 and 1.8 or 1)
	    self.targetAngle = (self.targetAngle * (estimatedPosition[1] < 0 and -1 or 1)) - angleAdjust
	  end
	  
	  self.targetAimFound = self.holdAim and (self.targetTimer == 0)
    end
  elseif self.burstCount == 0 then
    self.targetAngle = 0
  end

  self.headAngle = (self.headAngle or 0) + (self.targetAngle - (self.headAngle or 0)) * self.angleApproach
  animator.rotateTransformationGroup("head", self.headAngle, self.headRotationCenter)
end

function sgChomperFlyAroundAndShoot.leavingState(stateData)
end
