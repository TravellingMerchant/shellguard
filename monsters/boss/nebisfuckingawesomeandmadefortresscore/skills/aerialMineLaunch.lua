--------------------------------------------------------------------------------
aerialMineLaunch = {}

function aerialMineLaunch.enter()
  if not hasTarget() then return nil end
  
  self.active = false
  self.canFire = false
  self.leftProjectileOffset = config.getParameter("aerialMineLaunch.leftProjectileOffset")
  self.rightProjectileOffset = config.getParameter("aerialMineLaunch.rightProjectileOffset")
	self.config = config.getParameter("aerialMineLaunch.projectile.config", {})
	self.config.power = config.getParameter("aerialMineLaunch.projectile.power") * (root.evalFunction("monsterLevelPowerMultiplier", monster.level())) / (config.getParameter("aerialMineLaunch.fireInterval") / config.getParameter("aerialMineLaunch.fireDuration"))

  rangedAttack.setConfig(config.getParameter("aerialMineLaunch.projectile.type"), self.config, config.getParameter("aerialMineLaunch.fireInterval"))

  return {
    fireDuration = config.getParameter("aerialMineLaunch.fireDuration", 1),
    windupDuration = config.getParameter("aerialMineLaunch.windupDuration", 1)
  }
end

function aerialMineLaunch.enteringState(stateData)
  monster.setActiveSkillName("aerialMineLaunch")
  self.firstChoice = math.random(1, 2)
  self.secondChoice = math.random(1, 2)
  animator.playSound("ventAlert")
end

function aerialMineLaunch.update(dt, stateData)
  if not hasTarget() then return true end
  
  
  if self.active and stateData.windupDuration > 0 and not self.canFire then
    stateData.windupDuration = stateData.windupDuration - dt
	
	if stateData.windupDuration <= 0 then
      self.canFire = true
	end
  end
  
  if self.active and self.canFire and stateData.fireDuration > 0 then
    stateData.fireDuration = stateData.fireDuration - dt
  
	if animator.animationState("topLeftVents") == "open" then
	  rangedAttack.aim(vec2.add(self.rightProjectileOffset, {3,0}), {-1,0})
	  rangedAttack.fireContinuous()
	  rangedAttack.aim(vec2.add(self.rightProjectileOffset, {1,0}), {-1,0})
	  rangedAttack.fireContinuous()
	  rangedAttack.aim(vec2.add(self.rightProjectileOffset, {2,0}), {-1,0})
	  rangedAttack.fireContinuous()
	  rangedAttack.aim(self.rightProjectileOffset, {-1,0})
	  rangedAttack.fireContinuous()
	end
	if animator.animationState("topRightVents") == "open" then
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
	  animator.setAnimationState("topLeftVents", "activate")
	  animator.setAnimationState("topRightVents", "activate")
	  self.active = true
  elseif not self.active then
    if self.firstChoice == 1 then
	  animator.setAnimationState("topLeftVents", "activate")
	  self.active = true
	elseif self.firstChoice == 2 then
	  animator.setAnimationState("topRightVents", "activate")
	  self.active = true
	end
  end

  return false
end

function aerialMineLaunch.leavingState(stateData)
  if animator.animationState("topLeftVents") == "open" then
	animator.setAnimationState("topLeftVents", "deactivate")
  end
  if animator.animationState("topRightVents") == "open" then
	animator.setAnimationState("topRightVents", "deactivate")
  end
  self.active = false
  self.canFire = false
  rangedAttack.stopFiring()
end
