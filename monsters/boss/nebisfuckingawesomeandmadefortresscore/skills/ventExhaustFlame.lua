--------------------------------------------------------------------------------
ventExhaustFlame = {}

function ventExhaustFlame.enter()
  if not hasTarget() then return nil end
  
  self.active = false
  self.canFire = false
  self.leftProjectileOffset = config.getParameter("ventExhaustFlame.leftProjectileOffset")
  self.rightProjectileOffset = config.getParameter("ventExhaustFlame.rightProjectileOffset")

  rangedAttack.setConfig(config.getParameter("ventExhaustFlame.projectile.type"), config.getParameter("ventExhaustFlame.projectile.config"), config.getParameter("ventExhaustFlame.fireInterval"))

  return {
    fireDuration = config.getParameter("ventExhaustFlame.fireDuration", 1),
    windupDuration = config.getParameter("ventExhaustFlame.windupDuration", 1)
  }
end

function ventExhaustFlame.enteringState(stateData)
  monster.setActiveSkillName("ventExhaustFlame")
  self.firstChoice = math.random(1, 2)
  self.secondChoice = math.random(1, 2)
  animator.playSound("ventAlert")
end

function ventExhaustFlame.update(dt, stateData)
  if not hasTarget() then return true end
  
  
  if self.active and stateData.windupDuration > 0 and not self.canFire then
    stateData.windupDuration = stateData.windupDuration - dt
	
	if stateData.windupDuration <= 0 then
      self.canFire = true
	end
  end
  
  if self.active and self.canFire and stateData.fireDuration > 0 then
    stateData.fireDuration = stateData.fireDuration - dt
  
	if animator.animationState("bottomLeftVents") == "open" then
	  rangedAttack.aim(vec2.add(self.rightProjectileOffset, {3,0}), {-1,0})
	  rangedAttack.fireContinuous()
	  rangedAttack.aim(vec2.add(self.rightProjectileOffset, {1,0}), {-1,0})
	  rangedAttack.fireContinuous()
	  rangedAttack.aim(vec2.add(self.rightProjectileOffset, {2,0}), {-1,0})
	  rangedAttack.fireContinuous()
	  rangedAttack.aim(self.rightProjectileOffset, {-1,0})
	  rangedAttack.fireContinuous()
	end
	if animator.animationState("bottomRightVents") == "open" then
	  rangedAttack.aim(vec2.add(self.leftProjectileOffset, {-3,0}), {1,0})
	  rangedAttack.fireContinuous()
	  rangedAttack.aim(vec2.add(self.leftProjectileOffset, {-2,0}), {1,0})
	  rangedAttack.fireContinuous()
	  rangedAttack.aim(vec2.add(self.leftProjectileOffset, {-1,0}), {1,0})
	  rangedAttack.fireContinuous()
	  rangedAttack.aim(self.leftProjectileOffset, {1,0})
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
  self.canFire = false
  rangedAttack.stopFiring()
end
