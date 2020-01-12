-- Credit to Mikenyes and Dawn Felstar

require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

local wfancientwormbody_init = init
function init(...)
	self.parentEntity = config.getParameter("parentID")
	local monsterParams = {}
	monsterParams.childCount = config.getParameter("childCount") - 1
	monsterParams.parentID = entity.id()
	monsterParams.coreID = config.getParameter("coreID")
	monsterParams.offset = config.getParameter("offset")
	monsterParams.wormHeadName = config.getParameter("wormHeadName")
	monsterParams.wormBodyName = config.getParameter("wormBodyName")
	monsterParams.wormTailName = config.getParameter("wormTailName")
	monsterParams.spawnOffset = config.getParameter("spawnOffset")
	monsterParams.forceChildrenLua = config.getParameter("forceChildrenLua")
	if monsterParams.forceChildrenLua then
		monsterParams.scripts = {"/monsters/monster.lua","/scripts/wfsystem/monster/worm/wfwormbody.lua"}
		monsterParams.movementSettings = {collisionEnabled= false,gravityEnabled=false}
		monsterParams.statusSettings = {stats={maxHealth={baseValue=10000},healthRegen={baseValue=10000}}}
	end
	monsterParams.level = monster.level()
	self.chainOffset = config.getParameter("chainOffset", -1.5)
	self.offset = monsterParams.offset
	self.currentAngle = 0
	self.minChainDistance = 4
	self.coreID = monsterParams.coreID
	self.queryRange = config.getParameter("targetQueryRange", 50)
    self.queryTypes = config.getParameter("targetEntityTypes", {"player"})
	monsterParams.damageTeamType = entity.damageTeam().type
	monsterParams.damageTeam = entity.damageTeam().team

	local newPos = vec2.sub(mcontroller.position(), {0, self.offset})

	if not status.statusProperty("tailSpawned", false) then
		if monsterParams.childCount > 0 then
			self.childID = world.spawnMonster(monsterParams.wormBodyName, vec2.add(mcontroller.position(), monsterParams.spawnOffset), monsterParams)
		elseif monsterParams.childCount == 0 then
			self.childID = world.spawnMonster(monsterParams.wormTailName, vec2.add(mcontroller.position(), monsterParams.spawnOffset), monsterParams)
		end
		status.setStatusProperty("tailSpawned", true)
	end

	mcontroller.setVelocity(config.getParameter("initialVelocity", {0, 0}))
	setRotation(config.getParameter("initialRotation", 0))
	animator.setGlobalTag("directives", config.getParameter("directives", ""))

	self.chains = {}
	self.chainsData = config.getParameter("chains",nil)

	-- monster.setDamageTeam(world.entityDamageTeam(self.parentEntity))
	monster.setDamageOnTouch(true)

	if animator.hasSound("deathPuff") then
		monster.setDeathSound("deathPuff")
	end
	monster.setDeathParticleBurst(config.getParameter("deathParticles"))

	self.despawning = false
	script.setUpdateDelta(1)
	self.state = FSM:new()
	self.gunNames = config.getParameter("gunNames",{})
	self.targets = {}
	self.guns = {}
	for _,gunPart in pairs(self.gunNames) do
		local gunConfig = config.getParameter(gunPart)
		self.guns[gunPart] = coroutine.create(controlGun)
		local status, res = coroutine.resume(self.guns[gunPart],
			gunConfig.part,
			gunConfig.offset,
			gunConfig.projectileType,
			gunConfig.projectileParameters or {},
			gunConfig.count,
			gunConfig.power,
			gunConfig.fireInterval,
			gunConfig.fireCooldown,
			gunConfig.range,
			gunConfig.sound,
			gunConfig.requireLineOfSight
		)
		if not status then
			error(res)
		end
	end

	message.setHandler("despawn", localHandler(despawn))
	message.setHandler("getRotation", localHandler(getRotation))

	if wfancientwormbody_init then
		 return wfancientwormbody_init(...)
	end
end

local wfancientwormbody_update = update
function update(dt,...)
	if not world.entityExists(self.parentEntity) then
		despawn()
	end

	self.chains = {}
	mcontroller.controlFace(1)

	getParentInfo()

	moveChild()

	-- if not self.state.state then
	--	 despawn()
	-- end

	monster.setAnimationParameter("chains", self.chains)
	
	-- query for new targets if there are none (and we have guns)
    if #self.gunNames > 0 and #self.targets == 0 then
        local newTargets = world.entityQuery(mcontroller.position(), self.queryRange, {includedTypes = self.queryTypes})
        table.sort(newTargets, function(a, b)
            return world.magnitude(world.entityPosition(a), mcontroller.position()) < world.magnitude(world.entityPosition(b), mcontroller.position())
        end)
        for _,entityId in pairs(newTargets) do
                table.insert(self.targets, entityId)
        end
    end

    repeat
        self.target = self.targets[1]
        if self.target == nil then break end

        local target = self.target
        if not world.entityExists(target) then
            table.remove(self.targets, 1)
            self.target = nil
        end
    until #self.targets <= 0 or self.target
	
	-- update the guns
	for _,gunName in pairs(self.gunNames) do
		local status, res = coroutine.resume(self.guns[gunName])
		if not status then
			error(res)
		end
	end

	if wfancientwormbody_update then
	return wfancientwormbody_update(dt,...)
	end
end

function damage(damageInfo)
	world.sendEntityMessage(self.coreID, "updateHealth", damageInfo)
end

function moveChild()
	local baseParameters = mcontroller.baseParameters()
	local flyForce = baseParameters.airForce
	local maxFlySpeed = baseParameters.flySpeed

	if not self.despawning then
			local pos = mcontroller.position()
			local targetPosition = vec2.add(self.parentPosition, vec2.mul(vec2.norm(world.distance(pos, self.parentPosition)), self.offset))
			mcontroller.setPosition(targetPosition)

			-- local toTarget = world.distance(targetPosition, mcontroller.position())
			-- local targetDist = vec2.mag(toTarget)

			-- local approachSpeed = math.min(targetDist ^ 0.75 * 15, maxFlySpeed)
			-- local approachVec = vec2.mul(vec2.div(toTarget, targetDist), approachSpeed)

			-- mcontroller.controlApproachVelocity(approachVec, flyForce)

			self.currentAngle = vec2.angle(vec2.norm(world.distance(pos, self.parentPosition))) + math.pi/2
			setRotation(self.currentAngle)
		if self.chainsData and (world.magnitude(pos, self.parentPosition) > self.minChainDistance) then
			chainToParent()
		end
	end

end

function getParentInfo()
	self.parentPosition = world.entityPosition(self.parentEntity)
	-- self.parentRotation = self.parentRotation or 0
	-- if not self.getRotationPromise then
	--	 self.getRotationPromise = world.sendEntityMessage(self.parentEntity,"getRotation")
	-- end
	-- if self.getRotationPromise and self.getRotationPromise:finished() then
	--	 if self.getRotationPromise:succeeded() then
	--		 self.parentRotation = self.getRotationPromise:result()
	--		 self.getRotationPromise = nil
	--	 end
	-- end
end

function chainToParent()
	if not self.despawning then
		self.chain = true
		self.displaychain = true

		local chain = self.chainsData
		chain.sourcePart = "body"
		-- chain.endPosition = vec2.add(vec2.rotate({0, self.chainOffset}, self.parentRotation), self.parentPosition)
		chain.targetEntityId = self.parentEntity

		local currentFrame = frame or 1
		chain.startSegmentImage = chain.startSegmentImage:gsub("<chainFrame>", currentFrame)
		chain.segmentImage = chain.segmentImage:gsub("<chainFrame>", currentFrame)
		chain.endSegmentImage = chain.endSegmentImage:gsub("<chainFrame>", currentFrame)
		chain.testCollision = false
		chain.bounces = 0
		table.insert(self.chains, chain)
	end
end

function controlGun(part, offset, projectileType, params, count, power, interval, cooldown, range, sound, requireLineOfSight)
	-- everything before the first yield is initialization
	coroutine.yield()
	local updateTargetPos = function()
		if self.target == nil then
			self.targetPosition = nil
			return false
		end
		self.targetPosition = world.entityPosition(self.target)
		if self.targetPosition == nil then return true end
		self.center = {0,0}
		if part then 
			self.center = animator.partPoint(part, "rotationCenter") 
		end
		self.toTarget = world.distance(self.targetPosition, vec2.add(mcontroller.position(), self.center))
		if part then
			animator.resetTransformationGroup(part)
			local rotateAngle = vec2.angle(vec2.mul(self.toTarget, {mcontroller.facingDirection(), 1}))
			animator.rotateTransformationGroup(part, rotateAngle, vec2.mul(self.center, {mcontroller.facingDirection(), 1}))
		end
	end
	while true do
		local cooldownOffset = math.random() * cooldown

		if self.target then
			updateTargetPos()
			while self.target and self.targetPosition and world.magnitude(self.targetPosition, mcontroller.position()) < range do
				-- update target position during cooldown
				util.wait(cooldownOffset, updateTargetPos)
				if self.targetPosition == nil then break end
				if requireLineOfSight and not entity.entityInSight(self.target) then break end

				local shots = 0
				while shots < count do
					local aimVector = vec2.norm(self.toTarget)
					local source = vec2.add(mcontroller.position(), vec2.add(self.center, vec2.rotate(offset, vec2.angle(self.toTarget))))
					local scaledPower = power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
					params.power = scaledPower
					world.spawnProjectile(projectileType, source, entity.id(), aimVector, false, params)
					shots = shots + 1
					if sound then
						animator.playSound(sound)
					end
					if interval then
						util.wait(interval)
					end
				end

				util.wait(cooldown - cooldownOffset, function()
					if self.target then
						updateTargetPos()
					else
						return true
					end
				end)
			end
		end

		coroutine.yield()
	end
end

function shouldDie()
	return self.despawning
end

function despawn()
	self.despawning = true
end

function setRotation(angle)
	mcontroller.setRotation(angle)
	animator.resetTransformationGroup("body")
	animator.rotateTransformationGroup("body", angle)
end

function getRotation()
	return mcontroller.rotation()
end
