coreChargeLaserblast = {}

function coreChargeLaserblast.enter()
  if not hasTarget() then return nil end
	
  self.hasCharged = false
	self.chargeUpTime = config.getParameter("coreChargeLaserblast.chargeUpTime", 1)
	self.shots = config.getParameter("coreChargeLaserblast.shots", 1)
	
  return {
    chargeUpTime = config.getParameter("coreChargeLaserblast.chargeUpTime", 1),
    projectileType = config.getParameter("coreChargeLaserblast.projectileType", 1),
    projectileConfig = config.getParameter("coreChargeLaserblast.projectileConfig")
  }
end

function coreChargeLaserblast.enteringState(stateData)
	stateData.projectileConfig.power = config.getParameter("coreChargeLaserblast.projectileConfig.power") * (root.evalFunction("monsterLevelPowerMultiplier", monster.level())) / self.shots

  monster.setActiveSkillName("coreChargeLaserblast")
  if animator.animationState("blastShield") == "open" then
  end
  if animator.animationState("blastShield") == "closed" then
    animator.setAnimationState("blastShield", "winddown")
  end
	
	local playerId = world.playerQuery(mcontroller.position(), 50, {order = "random"})[1]
	if not playerId then
		playerId = entity.id()
	end
	world.sendEntityMessage(playerId, "queueRadioMessage", "sgfortresscorelaserattack")
	self.radioMessage = true
end

function coreChargeLaserblast.update(dt, stateData)
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

function coreChargeLaserblast.leavingState(stateData)
end