--------------------------------------------------------------------------------
siloMonsterSpawnAirborne = {}

function siloMonsterSpawnAirborne.enter()
  if not hasTarget() then return nil end
  
  self.active = false
  self.finished = false
  self.leftFinished = false
  self.rightFinished = false
  self.canFire = false
  self.first = false
  self.leftSiloOffset = config.getParameter("siloMonsterSpawnAirborne.leftSiloOffset")
  self.rightSiloOffset = config.getParameter("siloMonsterSpawnAirborne.rightSiloOffset")
  self.monsterLevel = monster.level() - 2
  
  return {
    fireDuration = config.getParameter("siloMonsterSpawnAirborne.fireDuration", 1),
    windupDuration = config.getParameter("siloMonsterSpawnAirborne.windupDuration", 1),
		monsterCount = config.getParameter("siloMonsterSpawnAirborne.monsterCount", 5),
		monsters = config.getParameter("siloMonsterSpawnAirborne.monsters"),
    monsterTypes = config.getParameter("siloMonsterSpawnAirborne.monsterTypes"),
    monsterCount = config.getParameter("siloMonsterSpawnAirborne.monsterCount"),
    monsterTestPoly = config.getParameter("siloMonsterSpawnAirborne.monsterTestPoly"),
    spawnOnGround = config.getParameter("siloMonsterSpawnAirborne.spawnOnGround"),
    spawnAnimation = config.getParameter("siloMonsterSpawnAirborne.spawnAnimation"),
    spawnRangeX = config.getParameter("siloMonsterSpawnAirborne.spawnRangeX"),
    spawnRangeY = config.getParameter("siloMonsterSpawnAirborne.spawnRangeY"),
    spawnTolerance = config.getParameter("siloMonsterSpawnAirborne.spawnTolerance"),
    spawnAnimationStatus = config.getParameter("siloMonsterSpawnAirborne.spawnAnimationStatus")
  }
end

function siloMonsterSpawnAirborne.enteringState(stateData)
  monster.setActiveSkillName("siloMonsterSpawnAirborne")
  self.firstChoice = math.random(1, 2)
  self.secondChoice = math.random(1, 2)
  animator.playSound("ventAlert")
end

function siloMonsterSpawnAirborne.update(dt, stateData)
  if not hasTarget() then return true end
  
  if animator.animationState("topRightSilo") == "risen" and not self.activeRight then
    animator.setAnimationState("topRightSilo", "dooropen")
    self.active = true
    self.activeRight = true
  end
  if animator.animationState("topLeftSilo") == "risen" and not self.activeLeft then
    animator.setAnimationState("topLeftSilo", "dooropen")
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
		if animator.animationState("topLeftSilo") == "openidle" and self.canFire and not self.leftFinished then
			for i = 1, math.random(stateData.monsterCount[1], stateData.monsterCount[2]) do
				--Calculate initial x and y offset for the spawn position
				local xOffset = math.random((self.leftSiloOffset[1] - stateData.spawnRangeX), self.leftSiloOffset[1])
				--xOffset = xOffset * util.randomChoice({-1, 1})
				local yOffset = math.random(self.leftSiloOffset[2], (stateData.spawnRangeY + self.leftSiloOffset[2]))
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
			if self.first then
				animator.setAnimationState("topLeftSilo", "doorclose")
				self.finished = true
				self.leftFinished = true
			end
		end
		if animator.animationState("topRightSilo") == "openidle" and self.canFire and not self.rightFinished then

			for i = 1, math.random(stateData.monsterCount[1], stateData.monsterCount[2]) do
				--Calculate initial x and y offset for the spawn position
				local xOffset = math.random(self.rightSiloOffset[1], (self.rightSiloOffset[1] + stateData.spawnRangeX))
				--xOffset = xOffset * util.randomChoice({-1, 1})
				local yOffset = math.random(self.rightSiloOffset[2], (stateData.spawnRangeY + self.rightSiloOffset[2]))
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
			animator.setAnimationState("topRightSilo", "doorclose")
			self.finished = true
			self.rightFinished = true
		end
		
		if self.finished then
			stateData.fireDuration = stateData.fireDuration - dt
			
			if animator.animationState("topLeftSilo") == "openidle" then
				animator.setAnimationState("topLeftSilo", "doorclose")
			end
			if animator.animationState("topRightSilo") == "openidle" then
				animator.setAnimationState("topRightSilo", "doorclose")
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
		if animator.animationState("topLeftSilo") == "idle" and animator.animationState("topRightSilo") == "idle" then
			animator.setAnimationState("topLeftSilo", "rise")
			animator.setAnimationState("topRightSilo", "rise")
		end
	elseif not self.active then
		if self.firstChoice == 1 then
			self.first = true
			if animator.animationState("topLeftSilo") == "idle" then
				animator.setAnimationState("topLeftSilo", "rise")
			end
		elseif self.firstChoice == 2 then
			if animator.animationState("topRightSilo") == "idle" then
				animator.setAnimationState("topRightSilo", "rise")
			end
		end
  end

  return false
end

function siloMonsterSpawnAirborne.leavingState(stateData)
  world.sendEntityMessage(entity.id(), "attemptToCloseSilo", "Left")
  world.sendEntityMessage(entity.id(), "attemptToCloseSilo", "Right")
  self.active = false
  self.canFire = false
  self.first = false
    self.leftFinished = false
  self.rightFinished = false
	self.activeRight = false
	self.activeLeft = false
end
