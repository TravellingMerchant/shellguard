coreChargeLaser = {}

function coreChargeLaser.enter()
  if not hasTarget() then return nil end
	
  self.hasCharged = false
	self.chargeUpTime = config.getParameter("coreChargeLaser.chargeUpTime", 1)
	self.shots = config.getParameter("coreChargeLaser.shots", 1)
	
  return {
    chargeUpTime = config.getParameter("coreChargeLaser.chargeUpTime", 1),
    projectileType = config.getParameter("coreChargeLaser.projectileType", 1),
    projectileConfig = config.getParameter("coreChargeLaser.projectileConfig")
  }
end

function coreChargeLaser.enteringState(stateData)
	stateData.projectileConfig.power = config.getParameter("coreChargeLaser.projectileConfig.power") * (root.evalFunction("monsterLevelPowerMultiplier", monster.level())) / self.shots

  monster.setActiveSkillName("coreChargeLaser")
  if animator.animationState("blastShield") == "open" then
  end
  if animator.animationState("blastShield") == "closed" then
    animator.setAnimationState("blastShield", "winddown")
  end
	
	if not self.radioMessage then
		local playerId = world.playerQuery(mcontroller.position(), 50, {order = "random"})[1]
		world.sendEntityMessage(playerId, "queueRadioMessage", "sgfortresscorelaserattack")
		self.radioMessage = true
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
			rangedAttack.fireOnce(stateData.projectileType, stateData.projectileConfig)
			
			--Reset Charge--
			self.shots = self.shots - 1
			if self.shots > 0 then
			  self.hasCharged = false
			end
			stateData.chargeUpTime = self.chargeUpTime
		elseif self.shots == 0 then
			return true
		end
	end
end

function coreChargeLaser.leavingState(stateData)
end