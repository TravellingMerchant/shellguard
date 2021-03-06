sgHeadRocketBarrage = {}

function sgHeadRocketBarrage.enter()
  self.headRotationCenter = config.getParameter("sgHeadRocketBarrage.headRotationCenter", {0, 0})
  self.projectileSpawnOffset = config.getParameter("sgHeadRocketBarrage.projectileSpawnOffset", {0, 0})
  self.headAngleOffset = config.getParameter("sgHeadRocketBarrage.headAngleOffset", 1)
  self.chargeUpTime = config.getParameter("sgChomperHeadLaser.chargeUpTime", 0)
  self.targetTimer = config.getParameter("sgChomperHeadLaser.targetingTime", 0)
  self.holdAim = config.getParameter("sgHeadRocketBarrage.holdAim", false)
  self.targetAimFound = false
  self.worldFirePoint = {0, 0}
  
  self.targetAngle = 0
  
  self.angleApproach = config.getParameter("sgHeadRocketBarrage.angleApproach", 1)
  
  self.burstCount = config.getParameter("sgHeadRocketBarrage.burstCount", 1)
  self.burstTime = config.getParameter("sgHeadRocketBarrage.burstTime", 0.1)
  self.burstTimer = self.burstTime

  return {
    projectileType = config.getParameter("sgHeadRocketBarrage.projectileType", "dragonblockbuster"),
    projectileParameters = config.getParameter("sgHeadRocketBarrage.projectileParameters", {}),
    trackSourceEntity = config.getParameter("sgHeadRocketBarrage.trackSourceEntity", false)
  }
end

function sgHeadRocketBarrage.enteringState(stateData)
  monster.setActiveSkillName("sgHeadRocketBarrage")
  
  animator.setAnimationState("head", "attackWindup")
  animator.playSound("rocketBarrageWindup")
end

function sgHeadRocketBarrage.update(dt, stateData)
  self.worldFirePoint = vec2.add({animator.partPoint("head", "projectileSpawnOffset")[1], animator.partPoint("head", "projectileSpawnOffset")[2]}, mcontroller.position())
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
      animator.playSound("rocketBarrageFire")
	  rangedAttack.fireOnce(stateData.projectileType, stateData.projectileParameters)
	  
	  self.burstCount = self.burstCount - 1
	  self.burstTimer = self.burstTime
	  
	  if self.burstCount == 0 then  
	    animator.setAnimationState("head", "attackWinddown")
	  end
	end
  end
  
  sgHeadRocketBarrage.updateHead(stateData)
end

function sgHeadRocketBarrage.updateHead(stateData)
  animator.resetTransformationGroup("head")
  
  local entityId = world.playerQuery(mcontroller.position(), 300, {includedTypes = {"player"}, order = "nearest"})[1]
  
  if entityId and self.burstCount > 0 then
	if not self.targetAimFound then
      local estimatedPosition = world.distance(mcontroller.position(), world.entityPosition(entityId))
      mcontroller.controlFace(world.distance(mcontroller.position(), world.entityPosition(entityId))[1])
      self.targetAngle = vec2.angle(estimatedPosition) * (mcontroller.facingDirection() * -1) + self.headAngleOffset
	  self.toTarget = vec2.norm(world.distance(self.targetPosition, self.worldFirePoint))
	  
	  if estimatedPosition[1] < 0 then -- and not self.holdAim then
	    self.targetAngle = self.targetAngle - math.pi + util.toRadians(self.headAngleOffset)
	  elseif estimatedPosition[1] > 0 then-- and not self.holdAim then
	    self.targetAngle = self.targetAngle + util.toRadians(self.headAngleOffset * 1.0) 
	  --elseif self.holdAim then
	    --local angleAdjust = (estimatedPosition[1] < 0) and math.pi or 0 + self.headAngleOffset * (estimatedPosition[1] < 0 and -55.55 or 0.25)
	    --self.targetAngle = self.targetAngle - angleAdjust
	  end
	  
	  self.targetAimFound = self.holdAim and (self.targetTimer == 0)
    end
  elseif self.burstCount == 0 then
    self.targetAngle = 0
  end
  
  self.headAngle = (self.headAngle or 0) + (self.targetAngle - (self.headAngle or 0)) * self.angleApproach
  world.debugLine(self.worldFirePoint, world.entityPosition(entityId), "orange")
  animator.rotateTransformationGroup("head", self.headAngle, self.headRotationCenter)
end

function sgHeadRocketBarrage.leavingState(stateData)
end


