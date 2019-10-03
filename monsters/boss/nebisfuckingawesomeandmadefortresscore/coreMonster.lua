require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/rect.lua"

function init()
	--Message Handling--
	message.setHandler("attemptToCloseSilo", localHandler(attemptToCloseSilo))
	message.setHandler("attemptToSpawnTurret", localHandler(attemptToSpawnTurret))
	message.setHandler("killYourself", localHandler(fuckingDie))
	message.setHandler("cutTheMusic", localHandler(cutTheMusic))
	self.hasDiedFromMessage = false
	
	--Dialogue--
	self.weHaventSaidThisYes = false
	self.tookDamage = false
	self.startPhase = false
	self.rematch = false
	self.currentIntro = 1
	self.sayTime = config.getParameter("dialog.lineDuration", 4)
	
	--Collision Init--
	self.openCollisionPoly = config.getParameter("collisionPolys.openCollisionPoly", {})
	self.closedCollisionPoly = config.getParameter("collisionPolys.closedCollisionPoly", {})
	
	--Turret Init--
	self.leftTurretEntityId = nil
	self.rightTurretEntityId = nil
	self.leftSpawnedTurret = false
	self.rightSpawnedTurret = false
	
	--Silo Platforming--
	self.leftSiloPlatformId = world.spawnVehicle("neb-sgfortresscoresilos", vec2.add(entity.position(), {-30, -22.5}))
	self.rightSiloPlatformId = world.spawnVehicle("neb-sgfortresscoresilos", vec2.add(entity.position(), {30, -22.5}))
		
	--General Init--
	self.dead = false
	self.slappedToDeath = false
	self.worldGravity = world.gravity(mcontroller.position())
	self.maxHealth = status.resource("health")
	
	if rangedAttack then
		rangedAttack.loadConfig()
	end

	--Movement
	self.spawnPosition = mcontroller.position()

	self.jumpTimer = 0
	self.isBlocked = false
	self.willFall = false

	self.queryTargetDistance = config.getParameter("queryTargetDistance", 30)
	self.trackTargetDistance = config.getParameter("trackTargetDistance")
	self.switchTargetDistance = config.getParameter("switchTargetDistance")
	self.keepTargetInSight = config.getParameter("keepTargetInSight", true)

	self.targets = {}

	--Non-combat states
	local states = stateMachine.scanScripts(config.getParameter("scripts"), "(%a+State)%.lua")
	self.state = stateMachine.create(states)

	self.state.leavingState = function(stateName)
		self.state.moveStateToEnd(stateName)
	end

	self.skillParameters = {}
	for _, skillName in pairs(config.getParameter("skills")) do
		self.skillParameters[skillName] = config.getParameter(skillName)
	end

	--Load phases
	self.phases = config.getParameter("phases")
	setPhaseStates(self.phases)

	for skillName, params in pairs(self.skillParameters) do
		if type(_ENV[skillName].onInit) == "function" then
			_ENV[skillName].onInit()
		end
	end

	monster.setUniqueId(config.getParameter("uniqueId"))
	monster.setDeathParticleBurst("deathPoof")
	monster.setDamageBar("None")
	self.musicEnabled = false
end

function fuckingDie(damageBar)
	monster.setDamageBar(damageBar)
	self.state.endState()
	world.setDungeonGravity(0, self.worldGravity)
	self.slappedToDeath = true
	local dropPools = config.getParameter("dropPools")
	for _, pool in pairs(dropPools) do
		world.spawnTreasure(mcontroller.position(), pool, 1)
	end
	self.hasDiedFromMessage = true

	self.state.update(dt)
end

function cutTheMusic(music)
	setBattleMusicEnabled(false)
end

function attemptToCloseSilo(relativeSide)
	if not self[relativeSide .."TurretEntityId"] then
		if animator.animationState("top"..relativeSide.."Silo") == "risen" then
			animator.setAnimationState("top"..relativeSide.."Silo", "sink")
		end
	end
end

function attemptToSpawnTurret(data)
	monsterType = data.monsterType 
	position = data.position
	monsterParameters = data.monsterParameters
	relativeSide = data.relativeSide
	
	if not self[relativeSide .."TurretEntityId"] then
		self[relativeSide .."TurretEntityId"] = world.spawnMonster(monsterType, position, monsterParameters)
		world.callScriptedEntity(self[relativeSide .."TurretEntityId"], "status.addEphemeralEffect", "nebfortressturretspawn")
		self[relativeSide .."SpawnedTurret"] = true
	end
end

function update(dt)
	--Messager Handling Update--
	if self.LeftSpawnedTurret and not world.entityExists(self.LeftTurretEntityId) then
		self.LeftSpawnedTurret = false
		self.LeftTurretEntityId = nil
		attemptToCloseSilo("Left")
	end
	if self.RightSpawnedTurret and not world.entityExists(self.RightTurretEntityId) then
		self.RightSpawnedTurret = false
		self.RightTurretEntityId = nil
		attemptToCloseSilo("Right")
	end
	
	--Silo Platforming--
	if animator.animationState("bottomLeftSilo") == "rise" and not self.leftActed then
		world.sendEntityMessage(self.leftSiloPlatformId, "moveUp", 3, 0.8)
		self.leftActed = true
	end
	if animator.animationState("bottomLeftSilo") == "risen" and self.leftActed then
		self.leftActed = false
	end
	if animator.animationState("bottomRightSilo") == "rise" and not self.rightActed then
		world.sendEntityMessage(self.rightSiloPlatformId, "moveUp", 3, 0.8)
		self.rightActed = true
	end	
	if animator.animationState("bottomRightSilo") == "risen" and self.rightActed then
		self.rightActed = false
	end
	if animator.animationState("bottomLeftSilo") == "sink" and not self.leftActed then
		world.sendEntityMessage(self.leftSiloPlatformId, "moveDown", 3, 0.8)
		self.leftActed = true
	end
	if animator.animationState("bottomLeftSilo") == "idle" and self.leftActed then
		self.leftActed = false
	end
	if animator.animationState("bottomRightSilo") == "sink" and not self.rightActed then
		world.sendEntityMessage(self.rightSiloPlatformId, "moveDown", 3, 0.8)
		self.rightActed = true
	end
	if animator.animationState("bottomRightSilo") == "idle" and self.rightActed then
		self.rightActed = false
	end
	
	--Initiate Energy Shield--
	if self.phase == 2 then
		status.addPersistentEffect("nebuloxWasHereAYO", "fortresscore-energyShield")
	elseif self.phase == 4 then
		status.addPersistentEffect("nebuloxWasHereAYO", "fortresscore-energyShield")
	else
		status.clearPersistentEffects("nebuloxWasHereAYO")
	end
	
	--Collision Correction--
	if animator.animationState("blastShield") == "closed" then
		mcontroller.controlParameters({collisionPoly = self.closedCollisionPoly})
		status.addPersistentEffect("nebuloxWasntHereAYO", "fortressidontwanttodie")
	else
		mcontroller.controlParameters({collisionPoly = self.openCollisionPoly})
		status.clearPersistentEffects("nebuloxWasntHereAYO")
	end

	self.tookDamage = false
	
	if not status.resourcePositive("health") and self.phase == 5 then
		
		--Check if death phase is ready
		local nextPhase = self.phases[self.phase + 1]
		if nextPhase then
			self.phase = self.phase + 1
		end
	
		local inState = self.state.stateDesc()
		if inState ~= "dieState" and not self.state.pickState({ die = true }) then
			self.state.endState()
		
			world.setDungeonGravity(0, self.worldGravity)

			self.state.update(dt)

			setBattleMusicEnabled(false)
		end
	elseif not self.slappedToDeath then
		trackTargets(self.keepTargetInSight, self.queryTargetDistance, self.trackTargetDistance, self.switchTargetDistance)

		for skillName, params in pairs(self.skillParameters) do
			if type(_ENV[skillName].onUpdate) == "function" then
				_ENV[skillName].onUpdate(dt)
			end
		end

		if hasTarget() then
			script.setUpdateDelta(1)
		if self.startPhase then
			updatePhase(dt)
			animator.setGlobalTag("phase", "phase"..currentPhase())
		end

		local playerId = world.playerQuery(mcontroller.position(), 50, {order = "random"})[1]
		local playerName = "Mr. Deadass"
		if playerId then
			playerName = world.entityName(playerId)
		else
			playerId = entity.id()
		end
		
		if self.sayTime > 0 then
			self.sayTime = self.sayTime - dt
		
		--if not self.rematch then
			if not self.weHaventSaidThisYes then
				if self.currentIntro == 1 then
					world.sendEntityMessage(playerId, "queueRadioMessage", "sgsurvivorfortressintro1")
					self.weHaventSaidThisYes = true
				elseif self.currentIntro == 2 then
					world.sendEntityMessage(playerId, "queueRadioMessage", "sgsurvivorfortressintro2")
					self.weHaventSaidThisYes = true
				else
					monster.sayPortrait(config.getParameter("dialog.intro"..self.currentIntro), config.getParameter("chatPortrait"), { player = playerName })
					self.weHaventSaidThisYes = true
				end
			end
			if self.sayTime <= 0 then
				if self.currentIntro < config.getParameter("dialog.introLines", 1) then
					self.currentIntro = self.currentIntro + 1
					self.weHaventSaidThisYes = false
				end
				self.sayTime = config.getParameter("dialog.lineDuration", 4)
				if self.currentIntro == config.getParameter("dialog.introLines", 1) and not self.hasDiedFromMessage then
					monster.setDamageBar("Special")
					monster.setAggressive(true)
					setBattleMusicEnabled(true)	
					self.startPhase = true
				end	
			end
		end
		else
			if self.hadTarget then
				--Lost target, reset boss
		self.finished = true
		world.sendEntityMessage(entity.id(), "attemptToCloseSilo", "Left")
		world.sendEntityMessage(entity.id(), "attemptToCloseSilo", "Right")
		if animator.animationState("bottomRightSilo") ~= "idle" then
			animator.setAnimationState("bottomRightSilo", "sink")
		end
		if animator.animationState("bottomLeftSilo") ~= "idle" then
			animator.setAnimationState("bottomLeftSilo", "sink")
		end
		if animator.animationState("topRightSilo") ~= "idle" then
			animator.setAnimationState("topRightSilo", "sink")
		end
		if animator.animationState("topLeftSilo") ~= "idle" then
			animator.setAnimationState("topLeftSilo", "sink")
		end
				if currentPhase() then
					self.phaseStates[currentPhase()].endState()
				end
				self.phase = nil
				self.lastPhase = nil
				setPhaseStates(self.phases)
				status.setResource("health", status.stat("maxHealth"))

				if bossReset then bossReset() end
				monster.setDamageBar("None")
				monster.setAggressive(false)
			end
			
			--Cull existing monsters
			local remainingMonsters = world.monsterQuery(mcontroller.position(), 100, {
				withoutEntityId = entity.id()
			})
			for _, monster in pairs(remainingMonsters) do
				world.sendEntityMessage(monster, "applyStatusEffect", "monsterdespawn")
				world.sendEntityMessage(monster, "despawn")
				world.sendEntityMessage(monster, "applyStatusEffect", "beamoutanddie")
			end
		
			script.setUpdateDelta(10)

			if not self.state.update(dt) then
				self.state.pickState()
			end

			setBattleMusicEnabled(false)
		end

		self.hadTarget = hasTarget()
	end
end

function damage(args)
	self.tookDamage = true

	if args.sourceId and args.sourceId ~= 0 and not inTargets(args.sourceId) then
		table.insert(self.targets, args.sourceId)
	end
end

function shouldDie()
	return self.dead
end

function hasTarget()
	if self.targetId and self.targetId ~= 0 then
		return self.targetId
	end
	return false
end

function trackTargets(keepInSight, queryRange, trackingRange)
	if keepInSight == nil then keepInSight = true end

	if #self.targets == 0 then
		local newTarget = closestValidTarget(queryRange)
		table.insert(self.targets, newTarget)
	end

	self.targets = util.filter(self.targets, function(targetId)
		if not world.entityExists(targetId) then return false end

		if keepInSight and not entity.entityInSight(targetId) then return false end
	
	if entity.damageTeam(targetId).type ~= "enemy" then return false end

		if trackingRange and world.magnitude(mcontroller.position(), world.entityPosition(targetId)) > trackingRange then
			return false
		end

		return true
	end)

	--Set target to be top of the list
	self.targetId = self.targets[1]
	if self.targetId then
		self.targetPosition = world.entityPosition(self.targetId)
	end
end

function validTarget(targetId, keepInSight, trackingRange)
	local entityType = world.entityType(targetId)
	if entityType ~= "player" and entityType ~= "npc" then
		return false
	end

	if not world.entityExists(targetId) then return false end

	if keepInSight and not entity.entityInSight(targetId) then return false end

	if trackingRange then
		local distance = world.magnitude(mcontroller.position(), world.entityPosition(targetId))
		if distance > trackingRange then return false end
	end

	return true
end

function inTargets(entityId)
	for i,targetId in ipairs(self.targets) do
		if targetId == entityId then
			return i
		end
	end
	return false
end

--PHASES-----------------------------------------------------------------------

function currentPhase()
	return self.phase
end

function updatePhase(dt)
	if not self.phase then
		self.phase = 1
	end

	--Check if next phase is ready
	local nextPhase = self.phases[self.phase + 1]
	if nextPhase then
		if not status.resourcePositive("health") then
		status.modifyResource("health", self.maxHealth)
			self.phase = self.phase + 1
			self.finished = true
			world.sendEntityMessage(entity.id(), "attemptToCloseSilo", "Left")
			world.sendEntityMessage(entity.id(), "attemptToCloseSilo", "Right")
			if animator.animationState("bottomRightSilo") ~= "idle" then
				animator.setAnimationState("bottomRightSilo", "sink")
			end
			if animator.animationState("bottomLeftSilo") ~= "idle" then
				animator.setAnimationState("bottomLeftSilo", "sink")
			end
			if animator.animationState("topRightSilo") ~= "idle" then
				animator.setAnimationState("topRightSilo", "sink")
			end
			if animator.animationState("topLeftSilo") ~= "idle" then
				animator.setAnimationState("topLeftSilo", "sink")
			end
		end
	end

	if not self.lastPhase or self.lastPhase ~= self.phase then
		if self.lastPhase then
			self.phaseStates[self.lastPhase].endState()
		end
		self.phaseStates[currentPhase()].pickState({enteringPhase = currentPhase()})
	end
	if not self.phaseStates[currentPhase()].update(dt) then
		self.phaseStates[currentPhase()].pickState()
	end

	self.lastPhase = self.phase
end

function setPhaseStates(phases)
	self.phaseSkills = {}
	self.phaseStates = {}
	for i,phase in ipairs(phases) do
		self.phaseSkills[i] = {}
		for _,skillName in ipairs(phase.skills) do
			table.insert(self.phaseSkills[i], skillName)
		end
		if phase.enterPhase then
			table.insert(self.phaseSkills[i], 1, phase.enterPhase)
		end
		self.phaseStates[i] = stateMachine.create(self.phaseSkills[i])

		--Cycle through the skills
		self.phaseStates[i].leavingState = function(stateName)
			self.phaseStates[i].moveStateToEnd(stateName)
		end
	end
end

--MOVEMENT---------------------------------------------------------------------

function boundingBox(force)
	if self.boundingBox and not force then return self.boundingBox end

	local collisionPoly = mcontroller.collisionPoly()
	local bounds = {0, 0, 0, 0}

	for _,point in pairs(collisionPoly) do
		if point[1] < bounds[1] then bounds[1] = point[1] end
		if point[2] < bounds[2] then bounds[2] = point[2] end
		if point[1] > bounds[3] then bounds[3] = point[1] end
		if point[2] > bounds[4] then bounds[4] = point[2] end
	end
	self.boundingBox = bounds

	return bounds
end

function checkWalls(direction)
	local bounds = mcontroller.boundBox()
	bounds[2] = bounds[2] + 1
	if direction > 0 then
		bounds[1] = bounds[3]
		bounds[3] = bounds[3] + 0.25
	else
		bounds[3] = bounds[1]
		bounds[1] = bounds[1] - 0.25
	end
	util.debugRect(rect.translate(bounds, mcontroller.position()), "yellow")
	return world.rectTileCollision(rect.translate(bounds, mcontroller.position()), {"Null", "Block", "Dynamic", "Slippery"})
end

function flyTo(position, speed)
	if speed then mcontroller.controlParameters({flySpeed = speed}) end
	local toPosition = vec2.norm(world.distance(position, mcontroller.position()))
	mcontroller.controlFly(toPosition)
end

--------------------------------------------------------------------------------
function move(delta, run, jumpThresholdX)
	checkTerrain(delta[1])

	mcontroller.controlMove(delta[1], run)

	if self.jumpTimer > 0 and not self.onGround then
		mcontroller.controlHoldJump()
	else
		if self.jumpTimer <= 0 then
			if jumpThresholdX == nil then jumpThresholdX = 4 end

			-- We either need to be blocked by something, the target is above us and
			-- we are about to fall, or the target is significantly high above us
			local doJump = false
			if isBlocked() then
				doJump = true
			elseif (delta[2] >= 0 and willFall() and math.abs(delta[1]) > 7) then
				doJump = true
			elseif (math.abs(delta[1]) < jumpThresholdX and delta[2] > config.getParameter("jumpTargetDistance")) then
				doJump = true
			end

			if doJump then
				self.jumpTimer = util.randomInRange(config.getParameter("jumpTime"))
				mcontroller.controlJump()
			end
		end
	end

	if delta[2] < 0 then
		mcontroller.controlDown()
	end
end

function closestValidTarget(range)
	local newTargets = world.entityQuery(entity.position(), range, { includedTypes = {"player"}, order = "nearest" })
	local valid = util.find(newTargets, function(targetId) return entity.damageTeam(targetId).type == "enemy" and entity.entityInSight(targetId) end)
	return valid or 0
end

--------------------------------------------------------------------------------
--TODO: this could probably be further optimized by creating a list of discrete points and using sensors... project for another time
function checkTerrain(direction)
	--normalize to 1 or -1
	direction = direction > 0 and 1 or -1

	local reverse = false
	if direction ~= nil then
		reverse = direction ~= mcontroller.facingDirection()
	end

	local boundBox = mcontroller.boundBox()

	-- update self.isBlocked
	local blockLine, topLine
	if not reverse then
		blockLine = {monster.toAbsolutePosition({boundBox[3] + 0.25, boundBox[4]}), monster.toAbsolutePosition({boundBox[3] + 0.25, boundBox[2] - 1.0})}
	else
		blockLine = {monster.toAbsolutePosition({-boundBox[3] - 0.25, boundBox[4]}), monster.toAbsolutePosition({-boundBox[3] - 0.25, boundBox[2] - 1.0})}
	end

	local blockBlocks = world.collisionBlocksAlongLine(blockLine[1], blockLine[2])
	self.isBlocked = false
	if #blockBlocks > 0 then
		--check for basic blockage
		local topOffset = blockBlocks[1][2] - blockLine[2][2]
		if topOffset > 2.75 then
			self.isBlocked = true
		elseif topOffset > 0.25 then
			--also check for that stupid little hook ledge thing
			self.isBlocked = not world.pointTileCollision({blockBlocks[1][1] - direction, blockBlocks[1][2] - 1})

			if not self.isBlocked then
				--also check if blocks above prevent us from climbing
				topLine = {monster.toAbsolutePosition({boundBox[1], boundBox[4] + 0.5}), monster.toAbsolutePosition({boundBox[3], boundBox[4] + 0.5})}
				self.isBlocked = world.lineTileCollision(topLine[1], topLine[2])
			end
		end
	end

	-- update self.willFall
	local fallLine
	if reverse then
		fallLine = {monster.toAbsolutePosition({-0.5, boundBox[2] - 0.75}), monster.toAbsolutePosition({boundBox[3], boundBox[2] - 0.75})}
	else
		fallLine = {monster.toAbsolutePosition({0.5, boundBox[2] - 0.75}), monster.toAbsolutePosition({-boundBox[3], boundBox[2] - 0.75})}
	end
	self.willFall =
			world.lineTileCollision(fallLine[1], fallLine[2]) == false and
			world.lineTileCollision({fallLine[1][1], fallLine[1][2] - 1}, {fallLine[2][1], fallLine[2][2] - 1}) == false
end

--------------------------------------------------------------------------------
function isBlocked()
	return self.isBlocked
end
--------------------------------------------------------------------------------
function willFall()
	return self.willFall
end

function setBattleMusicEnabled(enabled)
	if self.musicEnabled ~= enabled then
		local musicStagehands = config.getParameter("musicStagehands", {})
		for _,stagehand in pairs(musicStagehands) do
			local entityId = world.loadUniqueEntity(stagehand)

			if entityId and world.entityExists(entityId) then
				world.callScriptedEntity(entityId, "setMusicEnabled", enabled)
				self.musicEnabled = enabled
			end
		end
	end
end
