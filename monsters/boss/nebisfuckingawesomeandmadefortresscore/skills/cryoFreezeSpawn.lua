--------------------------------------------------------------------------------
cryoFreezeSpawn = {}

function cryoFreezeSpawn.enter()
  if not hasTarget() then return nil end
  
  self.active = true
  self.finished = false
  self.canFire = false
  self.leftOffset = config.getParameter("cryoFreezeSpawn.leftOffset")
  self.rightOffset = config.getParameter("cryoFreezeSpawn.rightOffset")
  self.monsterLevel = monster.level() + 1
  
  return {
    fireDuration = config.getParameter("cryoFreezeSpawn.fireDuration", 1),
    windupDuration = config.getParameter("cryoFreezeSpawn.windupDuration", 1),
    monsterType = config.getParameter("cryoFreezeSpawn.monsterType"),
    monsterTestPoly = config.getParameter("cryoFreezeSpawn.monsterTestPoly"),
    spawnOnGround = config.getParameter("cryoFreezeSpawn.spawnOnGround"),
    spawnAnimation = config.getParameter("cryoFreezeSpawn.spawnAnimation"),
    spawnRangeX = config.getParameter("cryoFreezeSpawn.spawnRangeX"),
    spawnRangeY = config.getParameter("cryoFreezeSpawn.spawnRangeY"),
    spawnTolerance = config.getParameter("cryoFreezeSpawn.spawnTolerance"),
    spawnAnimationStatus = config.getParameter("cryoFreezeSpawn.spawnAnimationStatus")
  }
end

function cryoFreezeSpawn.enteringState(stateData)
  monster.setActiveSkillName("cryoFreezeSpawn")
  animator.playSound("cryoAlert")
end

function cryoFreezeSpawn.update(dt, stateData)
  if not hasTarget() then return true end
  
  if self.active and stateData.windupDuration > 0 and not self.canFire then
    stateData.windupDuration = stateData.windupDuration - dt
	
		if stateData.windupDuration <= 0 and not self.canFire then
			self.canFire = true
		end
  end
  
  if self.active then
		if self.canFire and not self.finished then
			--Calculate initial x and y offset for the left spawn position
			local leftxOffset = math.random((self.leftOffset[1] - stateData.spawnRangeX), self.leftOffset[1])
			local leftyOffset = math.random(self.leftOffset[2], (stateData.spawnRangeY + self.leftOffset[2]))
			local leftPosition = vec2.add(entity.position(), {leftxOffset, leftyOffset})
			--Calculate initial x and y offset for the right spawn position
			local rightxOffset = math.random((self.rightOffset[1] - stateData.spawnRangeX), self.rightOffset[1])
			local rightyOffset = math.random(self.rightOffset[2], (stateData.spawnRangeY + self.rightOffset[2]))
			local rightPosition = vec2.add(entity.position(), {leftxOffset, leftyOffset})
		
			--Resolve the monster poly collision to ensure that we can place an monster at the designated position
			local leftResolvedPosition = world.resolvePolyCollision(stateData.monsterTestPoly, leftPosition, stateData.spawnTolerance)
		
			if leftResolvedPosition then
				--Spawn the monster and optionally force the monster spawn effect on them
				local leftEntityId = world.spawnMonster(stateData.monsterType, leftResolvedPosition, {level = self.monsterLevel, aggressive = true})
				if stateData.spawnAnimation then
					world.callScriptedEntity(leftEntityId, "status.addEphemeralEffect", stateData.spawnAnimation)
				end
			end
			
			--Resolve the monster poly collision to ensure that we can place an monster at the designated position
			local rightResolvedPosition = world.resolvePolyCollision(stateData.monsterTestPoly, rightPosition, stateData.spawnTolerance)
		
			if rightResolvedPosition then
				--Spawn the monster and optionally force the monster spawn effect on them
				local rightEntityId = world.spawnMonster(stateData.monsterType, rightResolvedPosition, {level = self.monsterLevel, aggressive = true})
				if stateData.spawnAnimation then
					world.callScriptedEntity(rightEntityId, "status.addEphemeralEffect", stateData.spawnAnimation)
				end
			end
			self.finished = true
		end
	end
	
	if self.finished then
    stateData.fireDuration = stateData.fireDuration - dt
	  
	  if stateData.fireDuration <= 0 then
	    return true
	  end
  end

  return false
end

function cryoFreezeSpawn.leavingState(stateData)
  world.sendEntityMessage(entity.id(), "attemptToCloseSilo", "Left")
  world.sendEntityMessage(entity.id(), "attemptToCloseSilo", "Right")
  self.active = false
  self.canFire = false
end
