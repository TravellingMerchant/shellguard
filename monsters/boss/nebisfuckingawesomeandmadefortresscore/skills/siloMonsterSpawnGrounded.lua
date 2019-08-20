--------------------------------------------------------------------------------
siloMonsterSpawnGrounded = {}

function siloMonsterSpawnGrounded.enter()
  if not hasTarget() then return nil end
  
  self.active = false
  self.canFire = false
  self.leftSiloOffset = config.getParameter("siloMonsterSpawnGrounded.leftSiloOffset")
  self.rightSiloOffset = config.getParameter("siloMonsterSpawnGrounded.rightSiloOffset")

  return {
    fireDuration = config.getParameter("siloMonsterSpawnGrounded.fireDuration", 1),
    windupDuration = config.getParameter("siloMonsterSpawnGrounded.windupDuration", 1)
  }
end

function siloMonsterSpawnGrounded.enteringState(stateData)
  monster.setActiveSkillName("siloMonsterSpawnGrounded")
  self.firstChoice = math.random(1, 2)
  self.secondChoice = math.random(1, 2)
  animator.playSound("ventAlert")
end

function siloMonsterSpawnGrounded.update(dt, stateData)
  if not hasTarget() then return true end
  
  
  if self.active and stateData.windupDuration > 0 and not self.canFire then
    stateData.windupDuration = stateData.windupDuration - dt
	
	if stateData.windupDuration <= 0 then
      self.canFire = true
	end
  end
  
  if self.active and self.canFire and stateData.fireDuration > 0 then
    stateData.fireDuration = stateData.fireDuration - dt
  
	if animator.animationState("bottomLeftSilo") == "risen" then
	  animator.setAnimationState("bottomLeftSilo", "dooropen")
	  chosenMonsters = {}
	  for _ = 1, 5 do
		table.insert(chosenMonsters, monsters[math.random(#monsters)])
	  end
	  
	  for _, monster in ipairs(chosenMonsters) do
		world.spawnMonster(monster, self.leftSiloOffset)
	  end
	end
	if animator.animationState("bottomRightSilo") == "risen" then
	end
	
	if stateData.fireDuration <= 0 then
	  if animator.animationState("bottomRightSilo") == "openidle" then
	    animator.setAnimationState("bottomRightSilo", "doorclose")
	  end
	  if animator.animationState("bottomLeftSilo") == "openidle" then
	    animator.setAnimationState("bottomLeftSilo", "doorclose")
	  end
	  return true
	end
  end


  if self.secondChoice ~= self.firstChoice and not self.active then
	  animator.setAnimationState("bottomLeftSilo", "rise")
	  animator.setAnimationState("bottomRightSilo", "rise")
	  self.active = true
  elseif not self.active then
    if self.firstChoice == 1 then
	  animator.setAnimationState("bottomLeftSilo", "rise")
	  self.active = true
	elseif self.firstChoice == 2 then
	  animator.setAnimationState("bottomRightSilo", "rise")
	  self.active = true
	end
  end

  return false
end

function siloMonsterSpawnGrounded.leavingState(stateData)
  if animator.animationState("bottomLeftSilo") == "risen" then
	animator.setAnimationState("bottomLeftSilo", "sink")
  end
  if animator.animationState("bottomRightSilo") == "risen" then
	animator.setAnimationState("bottomRightSilo", "sink")
  end
  self.active = false
  self.canFire = false
end
