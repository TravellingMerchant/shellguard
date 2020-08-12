sgApexbossrockets = {}

function sgApexbossrockets.enter()
  self.headRotationCenter = config.getParameter("sgApexbossrockets.headRotationCenter", {0, 0})
  self.projectileSpawnOffset = config.getParameter("sgApexbossrockets.projectileSpawnOffset", {0, 0})
  self.headAngleOffset = config.getParameter("sgApexbossrockets.headAngleOffset", 1)
  self.chargeUpTime = config.getParameter("sgApexbossrockets.chargeUpTime", 0)
  self.holdAim = config.getParameter("sgApexbossrockets.holdAim", false)
  self.targetAimFound = false
  
  self.targetAngle = 0
  
  self.angleApproach = config.getParameter("sgApexbossrockets.angleApproach", 1)
  
  self.burstCount = config.getParameter("sgApexbossrockets.burstCount", 1)
  self.burstTime = config.getParameter("sgApexbossrockets.burstTime", 0.1)
  self.burstTimer = self.burstTime

  return {
    projectileType = config.getParameter("sgApexbossrockets.projectileType", "dragonblockbuster"),
    projectileParameters = config.getParameter("sgApexbossrockets.projectileParameters", {}),
    trackSourceEntity = config.getParameter("sgApexbossrockets.trackSourceEntity", false)
  }
end

function sgApexbossrockets.enteringState(stateData)
  monster.setActiveSkillName("sgApexbossrockets")
  
  animator.setAnimationState("head", "attackWindup")
  animator.playSound("laserWindup")
end

function sgApexbossrockets.update(dt, stateData)
  if self.chargeUpTime > 0 then
	self.chargeUpTime = math.max(0, self.chargeUpTime - dt)
  elseif self.burstCount == 0 and self.headAngle == 0 then
	return true
  elseif self.burstCount > 0 then
    local projSpawnOffset = {animator.partPoint("head", "projectileSpawnOffset")[1] * mcontroller.facingDirection(), animator.partPoint("head", "projectileSpawnOffset")[2]}
	self.burstTimer = math.max(0, self.burstTimer - dt)
    if self.burstCount > 0 and self.burstTimer == 0 then
	  --Fire Projectile--
	  local toTarget = vec2.norm(vec2.rotate({0,1}, self.targetAngle))
	  rangedAttack.aim(projSpawnOffset, toTarget)
      animator.playSound("laserFire")
	  rangedAttack.fireOnce(stateData.projectileType, stateData.projectileParameters)
	  
	  self.burstCount = self.burstCount - 1
	  self.burstTimer = self.burstTime
	  
	  if self.burstCount == 0 then  
	    animator.setAnimationState("head", "attackWinddown")
	  end
	end
  end
  
  sgApexbossrockets.updateHead(stateData)
end

function sgApexbossrockets.updateHead(stateData)
  animator.resetTransformationGroup("head")
  
  local entityId = world.playerQuery(mcontroller.position(), 300, {includedTypes = {"player"}, order = "nearest"})[1]
  
  if entityId and self.burstCount > 0 then
    mcontroller.controlFace(world.distance(mcontroller.position(), world.entityPosition(entityId))[1])
	
	if not self.targetAimFound then
      local estimatedPosition = world.distance(mcontroller.position(), world.entityPosition(entityId))
      self.targetAngle = vec2.angle(estimatedPosition) * (mcontroller.facingDirection() * -1) + self.headAngleOffset
	  
	  self.targetAimFound = self.holdAim
    end
	
	if estimatedPosition and estimatedPosition[1] < 0 then
	  self.targetAngle = self.targetAngle - math.pi
	end
  elseif self.burstCount == 0 then
    self.targetAngle = 0
  end

  self.headAngle = (self.headAngle or 0) + (self.targetAngle - (self.headAngle or 0)) * self.angleApproach
  world.debugLine(self.worldFirePoint, world.entityPosition(entityId), "orange")
  animator.rotateTransformationGroup("head", self.headAngle, self.headRotationCenter)
end

function sgApexbossrockets.leavingState(stateData)
end
