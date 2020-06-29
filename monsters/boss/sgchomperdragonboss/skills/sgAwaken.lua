--------------------------------------------------------------------------------
sgAwaken = {}

function sgAwaken.enter()
  if not hasTarget() then return nil end
  if self.hasRoared then return nil end
  self.roarTimer = config.getParameter("sgAwaken.roarTime", 1)
  self.timer = 0
  
  self.hasRoared = false
  
  local newPosition = vec2.add(mcontroller.position(), config.getParameter("sgAwaken.startOffset", {0, 13}))
  self.spawnPosition = newPosition
  
  self.headRotationCenter = config.getParameter("sgAwaken.headRotationCenter", {0, 0})
  self.projectileSpawnOffset = config.getParameter("sgAwaken.projectileSpawnOffset", {0, 0})
  self.headAngleOffset = config.getParameter("sgAwaken.headAngleOffset", 1)
  self.flyTime = config.getParameter("sgAwaken.startOffset", {0, 13})[2] / (mcontroller.baseParameters().flySpeed / 10)

  return {
    projectileType = config.getParameter("sgAwaken.projectileType", "dragonblockbuster"),
    projectileParameters = config.getParameter("sgAwaken.projectileParameters", {}),
    trackSourceEntity = config.getParameter("sgAwaken.trackSourceEntity", false),
	
	amplitude = config.getParameter("sgAwaken.amplitude", 1),
	period = config.getParameter("sgAwaken.period", 1.75)
  }
end

function sgAwaken.onInit()
end

function sgAwaken.onUpdate(dt)
end

function sgAwaken.enteringState(stateData)
  monster.setActiveSkillName("sgAwaken")
  animator.setAnimationState("head", "visible")
end

function sgAwaken.update(dt, stateData)
  self.timer = math.min(((2 * math.pi) / stateData.period) / (self.hasRoared and 2 or 4), self.timer + dt)
  
  if self.timer == ((2 * math.pi) / stateData.period) / 4 then
	if animator.animationState("head") == "attack" then
	  --Roar--
	  if not self.spawnedProjectile then
		animator.playSound("roar")
        local toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(self.projectileSpawnOffset)))
        rangedAttack.aim(self.projectileSpawnOffset, toTarget)
        rangedAttack.fireOnce(stateData.projectileType, stateData.projectileParameters)
		self.spawnedProjectile = true
	  end
	  
	  if self.roarTimer == 0 then
	    animator.setAnimationState("head", "attackWinddown")
		self.hasRoared = true
	  else
	    self.roarTimer = math.max(0, self.roarTimer - dt)
	  end
    elseif animator.animationState("head") == "visible" and not self.hasRoared then
	  animator.setAnimationState("head", "attackWindup")
	end
  elseif self.timer == ((2 * math.pi) / stateData.period)  / 2 then
	parameters = {}
	parameters.gravityEnabled = false
	mcontroller.controlParameters(parameters)
	if self.flyTime > 0 then
      animator.setAnimationState("thrusters", "on")
      animator.setAnimationState("head", "visible")
      flyTo(self.spawnPosition)
	  self.flyTime = self.flyTime - dt
	else
      mcontroller.controlFly({ 0, 0 })
	  return true
    end
  end
  
  sgAwaken.updateHead(stateData)
end

function sgAwaken.updateHead(stateData)
  animator.resetTransformationGroup("head")

  local targetAngle = stateData.amplitude * math.sin(self.timer * stateData.period)

  --self.headAngle = (self.headAngle or 0) + (targetAngle - (self.headAngle or 0)) * stateData.angleApproach
  animator.rotateTransformationGroup("head", targetAngle, self.headRotationCenter)
end