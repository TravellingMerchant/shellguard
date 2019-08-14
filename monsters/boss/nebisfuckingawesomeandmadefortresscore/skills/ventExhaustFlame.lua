--------------------------------------------------------------------------------
ventExhaustFlame = {}

function ventExhaustFlame.enter()
  if not hasTarget() then return nil end

  rangedAttack.setConfig(config.getParameter("ventExhaustFlame.projectile.type"), config.getParameter("ventExhaustFlame.projectile.config"), 0.2)

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

  if self.secondChoice ~= self.firstChoice then
    if self.firstChoice == 1 then
	  animator.setAnimationState("bottomLeftVents", "activate")
	elseif self.firstChoice == 2 then
	  animator.setAnimationState("bottomRightVents", "activate")
	end
	
    if self.secondChoice == 1 then
	  animator.setAnimationState("bottomLeftVents", "activate")
	elseif self.secondChoice == 2 then
	  animator.setAnimationState("bottomRightVents", "activate")
	end
  else
    if self.firstChoice == 1 then
	  animator.setAnimationState("bottomLeftVents", "activate")
	elseif self.firstChoice == 2 then
	  animator.setAnimationState("bottomRightVents", "activate")
	end
  end

  return false
end

function ventExhaustFlame.leavingState(stateData)
  rangedAttack.stopFiring()
end
