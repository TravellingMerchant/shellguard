--Blast shield slam transitional phase
coreChargeLaser = {}

function coreChargeLaser.enterWith(args)
  if not hasTarget() then return nil end
	
  self.hasCharged = false
	self.chargeUpTime = config.getParameter("coreChargeLaser.chargeUpTime", 1)
	self.shots = config.getParameter("coreChargeLaser.shots", 1)
	
  return {
    chargeUpTime = config.getParameter("coreChargeLaser.chargeUpTime", 1),
    projectileType = config.getParameter("coreChargeLaser.projectileType", 1),
    projectileConfig = config.getParameter("coreChargeLaser.projectileConfig", {})
  }
end

function coreChargeLaser.enteringState(stateData)
	sb.logInfo("hm")
  monster.setActiveSkillName("coreChargeLaser")
  if animator.animationState("blastShield") == "open" then
  end
  if animator.animationState("blastShield") == "closed" then
    animator.setAnimationState("blastShield", "winddown")
  end
end

function coreChargeLaser.update(dt, stateData)
	if stateData.chargeUpTime > 0 then
		stateData.chargeUpTime = stateData.chargeUpTime - dt
		if not self.hasCharged then
			animator.setAnimationState("chargeUp", "charge")
			self.hasCharged = true
		end
		if stateData.chargeUpTime <= 0 and self.shots > 0 then
			--Animation--
			animator.playSound("fire")
			animator.setAnimationState("chargeUp", "hidden")
			
			--Fire Projectile--
		  local projectileOffset = {0,0}
			local toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(projectileOffset)))
			rangedAttack.aim(projectileOffset, toTarget)
			rangedAttack.fireOnce(projectileType, projectileConfig)
			
			--Reset Charge--
			self.shots = self.shots - 1
			self.hasCharged = false
			stateData.chargeUpTime = self.chargeUpTime
		else
			return true
		end
	end
end

function coreChargeLaser.leavingState(stateData)
end