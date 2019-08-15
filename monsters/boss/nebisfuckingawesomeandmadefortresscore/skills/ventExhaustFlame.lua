--------------------------------------------------------------------------------
ventExhaustFlame = {}

function ventExhaustFlame.enter()
  if not hasTarget() then return nil end
  
  self.active = false

  rangedAttack.setConfig(config.getParameter("ventExhaustFlame.projectile.type"), config.getParameter("ventExhaustFlame.projectile.config"), config.getParameter("ventExhaustFlame.fireInterval"))

  return {
    fireDuration = config.getParameter("fireDuration", 1)
  }
end

function ventExhaustFlame.enteringState(stateData)
  monster.setActiveSkillName("ventExhaustFlame")
  self.firstChoice = math.random(1, 2)
  self.secondChoice = math.random(1, 2)
end

function ventExhaustFlame.update(dt, stateData)
  if not hasTarget() then return true end
  
  local leftProjectileOffset = config.getParameter("ventExhaustFlame.leftProjectileOffset")
  local rightProjectileOffset = config.getParameter("ventExhaustFlame.rightProjectileOffset")
  
  if self.active and stateData.fireDuration > 0 then
    stateData.fireDuration = stateData.fireDuration - dt
  
	if animator.animationState("bottomLeftVents") == "open" then
	  rangedAttack.aim(rightProjectileOffset, {1,0})
	  rangedAttack.fireContinuous()
	end
	if animator.animationState("bottomRightVents") == "open" then
	  rangedAttack.aim(leftProjectileOffset, {-1,0})
	  rangedAttack.fireContinuous()
	end
	
	if stateData.fireDuration <= 0 then
	  return true
	end
  end


  if self.secondChoice ~= self.firstChoice and not self.active then
	  animator.setAnimationState("bottomLeftVents", "activate")
	  animator.setAnimationState("bottomRightVents", "activate")
	  self.active = true
  elseif not self.active then
    if self.firstChoice == 1 then
	  animator.setAnimationState("bottomLeftVents", "activate")
	  self.active = true
	elseif self.firstChoice == 2 then
	  animator.setAnimationState("bottomRightVents", "activate")
	  self.active = true
	end
  end

  return false
end

function ventExhaustFlame.leavingState(stateData)
  if animator.animationState("bottomLeftVents") == "open" then
	animator.setAnimationState("bottomLeftVents", "deactivate")
  end
  if animator.animationState("bottomRightVents") == "open" then
	animator.setAnimationState("bottomRightVents", "deactivate")
  end
  self.active = false
  rangedAttack.stopFiring()
end
