-- Credit to Mikenyes and Dawn Felstar

require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

local wfancientwormhead_init = init
function init(...)
    local monsterParams = {}
    monsterParams.childCount = config.getParameter("childCount",10)
    monsterParams.parentID = entity.id()
    monsterParams.coreID = entity.id()
    monsterParams.offset = config.getParameter("segmentOffset",4)
    monsterParams.wormHeadName = config.getParameter("wormHeadName","wfancientwormhead")
    monsterParams.wormBodyName = config.getParameter("wormBodyName","wfancientwormbody")
    monsterParams.wormTailName = config.getParameter("wormTailName","wfancientwormtail")
	monsterParams.forceChildrenLua = config.getParameter("forceChildrenLua",false)
	if monsterParams.forceChildrenLua then
		monsterParams.scripts = {"/monsters/monster.lua","/scripts/wfsystem/monster/worm/wfwormbody.lua"}
		monsterParams.movementSettings = {collisionEnabled=false,gravityEnabled=false}
		monsterParams.statusSettings = {stats={maxHealth={baseValue=10000},healthRegen={baseValue=10000}}}
	end
    monsterParams.level = monster.level()
	monsterParams.damageTeamType = entity.damageTeam().type
	monsterParams.damageTeam = entity.damageTeam().team

    if not status.statusProperty("tailSpawned", false) then
		for i = 1,config.getParameter("tailCount",1) do
			monsterParams.spawnOffset = {math.random()-0.5,math.random()-0.5}
			self.childID = world.spawnMonster(monsterParams.wormHeadName, vec2.add(mcontroller.position(), monsterParams.spawnOffset), monsterParams)
		end
		status.setStatusProperty("tailSpawned", true)
    end
	
	self.ignoreApproach = config.getParameter("ignoreApproach",false)
    self.despawning = false
	  self.inGround = true

    self.state = FSM:new()
    self.movement = coroutine.create(approachOrbit)
    self.targets = {}
    self.queryRange = config.getParameter("targetQueryRange", 50)
    self.queryTypes = config.getParameter("targetEntityTypes", {"player"})
    local orbitRandoms = {-1,1}
    self.orbitSpeed = orbitRandoms[math.random(1,2)] * config.getParameter("orbitSpeed", 0.1)
    self.requireTerrain = config.getParameter("requireTerrain", true)

    local orbitDistance = config.getParameter("orbitDistance", 3)
    local tangentialSpeed = config.getParameter("tangentialSpeed", 50)

    local status, res = coroutine.resume(self.movement, orbitDistance, tangentialSpeed, 20)
    if not status then error(res) end
	
    message.setHandler("despawn", localHandler(despawn))
    message.setHandler("getRotation", localHandler(getRotation))
    message.setHandler("updateHealth", localHandler(updateHealth))
    if wfancientwormhead_init then
        return wfancientwormhead_init(...)
    end
end

function updateHealth(damageInfo)
  status.applySelfDamageRequest(damageInfo)
end

local wfancientwormhead_update = update
function update(dt,...)
    if self.requireTerrain then
		if world.pointTileCollision(mcontroller.position(),{"Block","Slippery"}) then
			self.inGround = true
			mcontroller.controlParameters({
				gravityEnabled = false
			})
		else
			self.inGround = false
			mcontroller.controlParameters({
				gravityEnabled = true
			})
		end
	end
    -- query for new targets if there are none
    if #self.targets == 0 then
        self.approachAngle = math.random() * math.pi * 2
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

    if self.target and (self.inGround or world.gravity(mcontroller.position()) == 0) and not self.ignoreApproach then
        local toTarget = world.distance(world.entityPosition(self.target), mcontroller.position())

        local status, res = coroutine.resume(self.movement, dt)
        if not status then error(res) end
    end

    if wfancientwormhead_update then
        return wfancientwormhead_update(dt,...)
    end
end

function approachOrbit(distance, maxTangential)
    local tangentialSpeed = 0
    local dt = coroutine.yield()
    while true do
            self.approachAngle = self.approachAngle + self.orbitSpeed
            if self.approachAngle > (2 * math.pi) then self.approachAngle = 0 end

            if not self.target then return true end
            local targetPosition = world.entityPosition(self.target)
            local targetVelocity = world.entityVelocity(self.target)

            local toTarget = world.distance(targetPosition, mcontroller.position())
            local approachPoint = vec2.add(targetPosition, vec2.mul(toTarget, -1))
            local toApproach = vec2.norm(world.distance(approachPoint, mcontroller.position()))
            local approach = vec2.add(vec2.mul(toApproach,mcontroller.baseParameters().flySpeed),targetVelocity)

            local toOrbit
            if vec2.mag(toTarget) > distance then
                local toEdge = math.sqrt((vec2.mag(toTarget) ^ 2) - (distance ^ 2))
                local toEdgeAngle = math.atan(distance, toEdge)
                toOrbit = vec2.withAngle(toEdgeAngle)
            else
                toOrbit = {0, 1}
            end

            local targetAngle = vec2.angle(toTarget)
            local leadDir = util.toDirection(util.angleDiff(targetAngle, self.approachAngle))
            local tangentialSpeed = leadDir * maxTangential
            local tangentialApproach = vec2.mul(vec2.rotate({toOrbit[1], toOrbit[2] * util.toDirection(tangentialSpeed)}, targetAngle), math.abs(tangentialSpeed))
            approach = vec2.add(approach, tangentialApproach)

            mcontroller.controlApproachVelocity(approach, mcontroller.baseParameters().airForce, true)

        coroutine.yield()
    end
end

function shouldDie()
    return self.despawning or status.resource("health") <= 0
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
