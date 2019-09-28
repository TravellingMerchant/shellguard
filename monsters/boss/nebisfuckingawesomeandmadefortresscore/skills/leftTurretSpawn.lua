--------------------------------------------------------------------------------
leftTurretSpawn = {}

function leftTurretSpawn.enter()
  if not hasTarget() then return nil end
  
  self.active = false
  self.finished = false
  self.canFire = false
  self.turretOffset = config.getParameter("leftTurretSpawn.turretOffset")
  self.monsterLevel = monster.level() - 1
  
  return {
    fireDuration = config.getParameter("leftTurretSpawn.fireDuration", 1),
    windupDuration = config.getParameter("leftTurretSpawn.windupDuration", 1),
    monsterType = config.getParameter("leftTurretSpawn.monsterType"),
    monsterTestPoly = config.getParameter("leftTurretSpawn.monsterTestPoly"),
    spawnOnGround = config.getParameter("leftTurretSpawn.spawnOnGround"),
    spawnTolerance = config.getParameter("leftTurretSpawn.spawnTolerance"),
	entityId = nil
  }
end

function leftTurretSpawn.enteringState(stateData)
  if not hasTarget() then return true end
  monster.setActiveSkillName("leftTurretSpawn")
  animator.playSound("ventAlert")
	
	if not self.radioMessage then
		local playerId = world.playerQuery(mcontroller.position(), 50, {order = "random"})[1]
		world.sendEntityMessage(playerId, "queueRadioMessage", "sgfortressturretspawn")
		self.radioMessage = true
	end
end

function leftTurretSpawn.update(dt, stateData)
  if not hasTarget() then return true end
  
  if animator.animationState("topLeftSilo") == "risen" and not self.active then
	self.active = true
  end
  if animator.animationState("topLeftSilo") == "risen" and not self.active then
	self.active = true
  end
  
  if self.active and stateData.windupDuration > 0 and not self.canFire then
    stateData.windupDuration = stateData.windupDuration - dt
	
	if stateData.windupDuration <= 0 and not self.canFire then
      self.canFire = true
	end
  end
  
  if self.active and animator.animationState("topLeftSilo") == "risen" and self.canFire and not self.finished then
    if not self.finished then
	  --Calculate initial x and y offset for the spawn position
	  local xOffset = self.turretOffset[1]
	  local yOffset = self.turretOffset[2]
	  local position = vec2.add(entity.position(), {xOffset, yOffset})
	  
	  --Optionally correct the position by finding the ground below the projected position
	  local correctedPositionAndNormal = {position, nil}
	  if stateData.spawnOnGround then
	    correctedPositionAndNormal = world.lineTileCollisionPoint(position, vec2.add(position, {0, -50})) or {position, 0}
	  end
	  
	  --Resolve the monster poly collision to ensure that we can place an monster at the designated position
	  local resolvedPosition = world.resolvePolyCollision(stateData.monsterTestPoly, correctedPositionAndNormal[1], stateData.spawnTolerance)
	  
	  if resolvedPosition then
	    --Attempt to spawn the monster
	    world.sendEntityMessage(entity.id(), "attemptToSpawnTurret", {
		  monsterType  = stateData.monsterType,
		  position = resolvedPosition, 
		  monsterParameters  = {level = self.monsterLevel, aggressive = true},
		  relativeSide = "Left"
		})
	  end
	  self.finished = true
	end
	
	if self.finished then
      stateData.fireDuration = stateData.fireDuration - dt
	  
	  if stateData.fireDuration <= 0 then
	    return true
	  end
	end
  end


  if not self.active then
	if animator.animationState("topLeftSilo") == "idle" then
	  animator.setAnimationState("topLeftSilo", "rise")
	end
  end

  return false
end

function leftTurretSpawn.leavingState(stateData)
  world.sendEntityMessage(entity.id(), "attemptToCloseSilo", "Left")
  self.active = false
  self.canFire = false
end
