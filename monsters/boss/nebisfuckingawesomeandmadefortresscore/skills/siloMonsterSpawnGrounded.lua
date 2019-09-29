--------------------------------------------------------------------------------
siloMonsterSpawnGrounded = {}

function siloMonsterSpawnGrounded.enter()
  if not hasTarget() then return nil end
  
  self.active = false
  self.finished = false
  self.leftFinished = false
  self.rightFinished = false
  self.canFire = false
  self.first = false
  self.leftSiloOffset = config.getParameter("siloMonsterSpawnGrounded.leftSiloOffset")
  self.rightSiloOffset = config.getParameter("siloMonsterSpawnGrounded.rightSiloOffset")
  self.monsterLevel = monster.level() - 2
  
  return {
    fireDuration = config.getParameter("siloMonsterSpawnGrounded.fireDuration", 1),
    windupDuration = config.getParameter("siloMonsterSpawnGrounded.windupDuration", 1),
		monsterCount = config.getParameter("siloMonsterSpawnGrounded.monsterCount", 5),
		monsters = config.getParameter("siloMonsterSpawnGrounded.monsters"),
    monsterTypes = config.getParameter("siloMonsterSpawnGrounded.monsterTypes"),
    monsterCount = config.getParameter("siloMonsterSpawnGrounded.monsterCount"),
    monsterTestPoly = config.getParameter("siloMonsterSpawnGrounded.monsterTestPoly"),
    spawnOnGround = config.getParameter("siloMonsterSpawnGrounded.spawnOnGround"),
    spawnAnimation = config.getParameter("siloMonsterSpawnGrounded.spawnAnimation"),
    spawnRangeX = config.getParameter("siloMonsterSpawnGrounded.spawnRangeX"),
    spawnRangeY = config.getParameter("siloMonsterSpawnGrounded.spawnRangeY"),
    spawnTolerance = config.getParameter("siloMonsterSpawnGrounded.spawnTolerance"),
    spawnAnimationStatus = config.getParameter("siloMonsterSpawnGrounded.spawnAnimationStatus")
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
  
  if animator.animationState("bottomRightSilo") == "risen" and not self.activeRight then
    animator.setAnimationState("bottomRightSilo", "dooropen")
    self.active = true
    self.activeRight = true
  end
  if animator.animationState("bottomLeftSilo") == "risen" and not self.activeLeft then
    animator.setAnimationState("bottomLeftSilo", "dooropen")
    self.active = true
    self.activeLeft = true
  end
  
  if self.active and stateData.windupDuration > 0 and not self.canFire then
    stateData.windupDuration = stateData.windupDuration - dt
	
		if stateData.windupDuration <= 0 and not self.canFire then
			self.canFire = true
		end
  end
  
  if self.active then
		if animator.animationState("bottomLeftSilo") == "openidle" and self.canFire and not self.leftFinished then
			for i = 1, math.random(stateData.monsterCount[1], stateData.monsterCount[2]) do
				--Calculate initial x and y offset for the spawn position
				local xOffset = math.random((self.leftSiloOffset[1] - stateData.spawnRangeX), self.leftSiloOffset[1])
				--xOffset = xOffset * util.randomChoice({-1, 1})
				local yOffset = math.random(self.leftSiloOffset[2], stateData.spawnRangeY)
				local position = vec2.add(entity.position(), {xOffset, yOffset})
			
				--Optionally correct the position by finding the ground below the projected position
				local correctedPositionAndNormal = {position, nil}
				if stateData.spawnOnGround then
					correctedPositionAndNormal = world.lineTileCollisionPoint(position, vec2.add(position, {0, -50})) or {position, 0}
				end
			
				--Resolve the monster poly collision to ensure that we can place an monster at the designated position
				local resolvedPosition = world.resolvePolyCollision(stateData.monsterTestPoly, correctedPositionAndNormal[1], stateData.spawnTolerance)
			
				if resolvedPosition then
					--Spawn the monster and optionally force the monster spawn effect on them
					local entityId = world.spawnMonster(util.randomChoice(stateData.monsterTypes), resolvedPosition, {level = self.monsterLevel, aggressive = true})
					if stateData.spawnAnimation then
						world.callScriptedEntity(entityId, "status.addEphemeralEffect", stateData.spawnAnimationStatus)
					end
				end
			end
			self.leftFinished = true
			self.finished = true
		end
		if animator.animationState("bottomRightSilo") == "openidle" and self.canFire and not self.rightFinished then
			for i = 1, math.random(stateData.monsterCount[1], stateData.monsterCount[2]) do
				--Calculate initial x and y offset for the spawn position
				local xOffset = math.random(self.rightSiloOffset[1], (self.rightSiloOffset[1] + stateData.spawnRangeX))
				--xOffset = xOffset * util.randomChoice({-1, 1})
				local yOffset = math.random(self.rightSiloOffset[2], stateData.spawnRangeY)
				local position = vec2.add(entity.position(), {xOffset, yOffset})
			
				--Optionally correct the position by finding the ground below the projected position
				local correctedPositionAndNormal = {position, nil}
				if stateData.spawnOnGround then
					correctedPositionAndNormal = world.lineTileCollisionPoint(position, vec2.add(position, {0, -50})) or {position, 0}
				end
			
				--Resolve the monster poly collision to ensure that we can place an monster at the designated position
				local resolvedPosition = world.resolvePolyCollision(stateData.monsterTestPoly, correctedPositionAndNormal[1], stateData.spawnTolerance)
			
				if resolvedPosition then
				--Spawn the monster and optionally force the monster spawn effect on them
					local entityId = world.spawnMonster(util.randomChoice(stateData.monsterTypes), resolvedPosition, {level = self.monsterLevel, aggressive = true})
					if stateData.spawnAnimation then
						world.callScriptedEntity(entityId, "status.addEphemeralEffect", stateData.spawnAnimationStatus)
					end
				end
			end
			self.rightFinished = true
			self.finished = true
		end
		
		if self.finished then
			stateData.fireDuration = stateData.fireDuration - dt
			
			if animator.animationState("bottomLeftSilo") == "openidle" then
				animator.setAnimationState("bottomLeftSilo", "doorclose")
			end
			if animator.animationState("bottomRightSilo") == "openidle" then
				animator.setAnimationState("bottomRightSilo", "doorclose")
			end
			if animator.animationState("bottomRightSilo") == "risen" then
				animator.setAnimationState("bottomRightSilo", "sink")
			end
			if animator.animationState("bottomLeftSilo") == "risen" then
				animator.setAnimationState("bottomLeftSilo", "sink")
			end
	  
			if stateData.fireDuration <= 0 then
				return true
			end
		end
  end


  if self.secondChoice ~= self.firstChoice and not self.active then
		if animator.animationState("bottomRightSilo") == "idle" and animator.animationState("bottomLeftSilo") == "idle" then
			animator.setAnimationState("bottomLeftSilo", "rise")
			animator.setAnimationState("bottomRightSilo", "rise")
		end
	elseif not self.active then
		if self.firstChoice == 1 then	
			if animator.animationState("bottomLeftSilo") == "idle" then
				animator.setAnimationState("bottomLeftSilo", "rise")
				self.first = true
			end
		elseif self.firstChoice == 2 then
			if animator.animationState("bottomRightSilo") == "idle" then
				animator.setAnimationState("bottomRightSilo", "rise")
			end
		end
  end

  return false
end

function siloMonsterSpawnGrounded.leavingState(stateData)
  self.active = false
  self.canFire = false
  self.first = false
	self.activeRight = false
	self.activeLeft = false
end
