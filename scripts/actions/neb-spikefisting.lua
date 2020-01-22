-- Helpers

-- Probably the hackiest thing in all the behavior nodes
-- All of these should be node parameters
function parseProjectileConfig(board, args)
	local parsed = copy(args)
	if parsed.power and type(parsed.power) == "string" then
		parsed.power = board:getNumber(args.power)
	end
	if parsed.speed and type(parsed.speed) == "string" then
		parsed.speed = board:getNumber(args.speed)
	end
	if parsed.timeToLive and type(parsed.timeToLive) == "string" then
		parsed.timeToLive = board:getNumber(args.timeToLive)
	end
	if parsed.animationCycle and type(parsed.animationCycle) == "string" then
		parsed.animationCycle = board:getNumber(args.animationCycle)
	end

	return parsed
end

function scalePower(power)
	local level = 1
	power = power or 10

	if entity.entityType() == "monster" then
		power = power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
		level = monster.level()
	elseif entity.entityType() == "npc" then
		power = power * root.evalFunction("npcLevelPowerMultiplierModifier", npc.level())
		level = npc.level()
	end
	power = power * status.stat("powerMultiplier")
	return power
end

-- param position
-- param offset
-- param projectileType
-- param angle
-- param aimVector
-- param sourceEntity
-- param trackSource
-- param projectileConfig
-- param scalePower
-- param damageRepeatGroup
-- param uniqueRepeatGroup
-- output targetProjectile
function spawnChainedProjectile(args, board)
	local parameters = parseProjectileConfig(board, args.projectileConfig or {})
	if args.scalePower then parameters.power, parameters.level = scalePower(parameters.power) end
	local aimVector = args.aimVector or vec2.withAngle(args.angle)
	if args.damageRepeatGroup and args.damageRepeatGroup ~= "" then
		parameters.damageRepeatGroup = args.damageRepeatGroup
		if args.uniqueRepeatGroup then
			parameters.damageRepeatGroup = string.format(parameters.damageRepeatGroup.."-%s", entity.id())
		end
	end
	local projectileId = world.spawnProjectile(args.projectileType, vec2.add(args.position, args.offset), args.sourceEntity, aimVector, args.trackSource, parameters)
	chainToProjectile(projectileId, args.gunPart)
	return true, {targetProjectile = projectileId}
end

function chainToProjectile(projectileId, gunPart)
		local startPos = mcontroller.position()	--Temporary for testing purposes
	local enemyPos = world.entityPosition(projectileId)
	local angle = vec2.angle(startPos, enemyPos)
	local frame = 4
		local bounces = 0
		local dist = world.distance(startPos, enemyPos)
	
		spikeFistChain(true, gunPart, angle, frame, "damage", bounces, dist, enemyPos, projectileId, startPos)
end
-- param position
-- param projectileType
-- param aimVector
-- param trackSource
-- param parameters
-- param target
function spawnTargetedChainedProjectile(args, board)
	local parameters = copy(args.parameters)
	parameters.power, parameters.level = scalePower(parameters.power)

	if not args.target or not world.entityExists(args.target) then return false end

	local projectileId = world.spawnProjectile(args.projectileType, args.position, entity.id(), args.aimVector, args.trackSource, parameters)
	world.sendEntityMessage(projectileId, "setTarget", args.target)
		chainToProjectile(projectileId)
	return true
end

-- param projectileName
-- output gravityMultiplier
function projectileGravityMultiplier(args, board)
	if args.projectileName == nil or args.projectileName == "" then return false end
	return true, {gravityMultiplier = root.projectileGravityMultiplier(args.projectileName)}
end

-- param projectileId
-- param gunPart
function waitForBoomerangReturn(args, board)
	if not args.projectileId then
		return false
	end
	self.trackedBoomerangs = self.trackedBoomerangs or {}
	self.trackedBoomerangs[args.gunPart] = args.projectileId
	while world.entityExists(self.trackedBoomerangs[args.gunPart]) do
		coroutine.yield(nil)
	end
	return true
end
