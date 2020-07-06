sgHeadPlasma = {}

function sgHeadPlasma.enter()
  self.headRotationCenter = config.getParameter("sgHeadPlasma.headRotationCenter", {0, 0})
  self.projectileSpawnOffset = config.getParameter("sgHeadPlasma.projectileSpawnOffset", {0, 0})
  self.headAngleOffset = config.getParameter("sgHeadPlasma.headAngleOffset", 1)
  self.chargeUpTime = config.getParameter("sgHeadPlasma.chargeUpTime", 0)
  self.holdAim = config.getParameter("sgHeadPlasma.holdAim", false)
  self.targetAimFound = false
  
  self.targetAngle = 0
  
  self.angleApproach = config.getParameter("sgHeadPlasma.angleApproach", 1)
  
  self.burstCount = config.getParameter("sgHeadPlasma.burstCount", 1)
  self.burstTime = config.getParameter("sgHeadPlasma.burstTime", 0.1)
  self.burstTimer = self.burstTime

  return {
    projectileType = config.getParameter("sgHeadPlasma.projectileType", "dragonblockbuster"),
    projectileParameters = config.getParameter("sgHeadPlasma.projectileParameters", {}),
    trackSourceEntity = config.getParameter("sgHeadPlasma.trackSourceEntity", false)
  }
end

function sgHeadPlasma.enteringState(stateData)
  monster.setActiveSkillName("sgHeadPlasma")
  
  animator.setAnimationState("head", "attackWindup")
  animator.playSound("plasmaWindup")
end

function sgHeadPlasma.update(dt, stateData)
  if self.chargeUpTime > 0 then
	self.chargeUpTime = math.max(0, self.chargeUpTime - dt)
  elseif self.burstCount == 0 and self.headAngle == 0 then
	return true
  elseif self.burstCount > 0 then
	self.burstTimer = math.max(0, self.burstTimer - dt)
    if self.burstCount > 0 and self.burstTimer == 0 then
	  --Fire Projectile--
	  local toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(self.projectileSpawnOffset)))
	  rangedAttack.aim(self.projectileSpawnOffset, toTarget)
      animator.playSound("plasmaFire")
	  rangedAttack.fireOnce(stateData.projectileType, stateData.projectileParameters)
	  
	  self.burstCount = self.burstCount - 1
	  self.burstTimer = self.burstTime
	  
	  if self.burstCount == 0 then  
	    animator.setAnimationState("head", "attackWinddown")
	  end
	end
  end
  
  sgHeadPlasma.updateHead(stateData)
end

function sgHeadPlasma.updateHead(stateData)
  animator.resetTransformationGroup("head")
  
  local entityId = world.playerQuery(mcontroller.position(), 300, {includedTypes = {"player"}, order = "nearest"})[1]
  
  if entityId and self.burstCount > 0 and (self.holdAim and not self.targetAimFound) then
    mcontroller.controlFace(world.distance(mcontroller.position(), world.entityPosition(entityId))[1])
	
    local estimatedPosition = world.distance(mcontroller.position(), world.entityPosition(entityId))
    self.targetAngle = vec2.angle(estimatedPosition) * (mcontroller.facingDirection() * -1) + self.headAngleOffset
	
	if estimatedPosition[1] < 0 then
	  self.targetAngle = self.targetAngle - math.pi
	end
	
	self.targetAimFound = true
  end

  self.headAngle = (self.headAngle or 0) + (self.targetAngle - (self.headAngle or 0)) * self.angleApproach
  animator.rotateTransformationGroup("head", self.headAngle, self.headRotationCenter)
end

function sgHeadPlasma.leavingState(stateData)
end
