require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  self.parentEntity = config.getParameter("parentEntity")
  self.movementMode = config.getParameter("movementMode")
  self.attackMode = config.getParameter("attackMode")

  mcontroller.setVelocity(config.getParameter("initialVelocity", {0, 0}))
  setRotation(config.getParameter("initialRotation", 0))
  animator.setGlobalTag("directives", config.getParameter("directives", ""))

  monster.setDamageTeam(world.entityDamageTeam(self.parentEntity))
  monster.setDamageOnTouch(true)

  if animator.hasSound("deathPuff") then
    monster.setDeathSound("deathPuff")
  end
  monster.setDeathParticleBurst(config.getParameter("deathParticles"))

  self.despawning = false

  self.gunConfig = config.getParameter("gun")
  if self.gunConfig then
    self.fireDelayTimer = self.gunConfig.fireDelay or 0
    self.fireTimer = 0
  end
  self.targetRange = config.getParameter("targetRange")
  self.targetQueryParameters = {
    withoutEntityId = self.parentEntity,
    includedTypes = {"creature"},
    order = "nearest"
  }

  self.state = FSM:new()
  self.state:set(_ENV["move" .. self.movementMode])

  message.setHandler("setTargetOffset", function(_, _, targetOffset)
      self.targetOffset = targetOffset
    end)
  message.setHandler("despawn", localHandler(despawn))
end

function update(dt)
  if not world.entityExists(self.parentEntity) then
    despawn()
  end

  mcontroller.controlFace(1)

  self.state:update()

  if not self.state.state then
    despawn()
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

function moveOrbit()
  self.targetOffset = config.getParameter("targetOffset")

  local baseParameters = mcontroller.baseParameters()
  local flyForce = baseParameters.airForce
  local maxFlySpeed = baseParameters.flySpeed

  while not self.despawning do
    local pos = mcontroller.position()
    local parentPosition = world.entityPosition(self.parentEntity)
		local trackingVec = parentPosition
		local trackingVel = world.entityVelocity(self.parentEntity)
		
		if not self.perfectTracking then
			local targetPosition = vec2.add(parentPosition, self.targetOffset)
			mcontroller.setPosition(targetPosition)
		else
			local targetPosition = vec2.add(parentPosition, self.targetOffset)
			mcontroller.setPosition(targetPosition)
		end

    updateAttack()

    coroutine.yield()
  end
end

function moveStandoff()
  local standoffDist = config.getParameter("standoffDistance")

  local baseParameters = mcontroller.baseParameters()
  local flyForce = baseParameters.airForce
  local maxFlySpeed = baseParameters.flySpeed

  local traction = 0
  local slipTime = 2

  while not self.despawning do
    if traction < 1 then
      traction = math.min(1.0, traction + script.updateDt() / slipTime)
    end

    local fromParent = world.distance(world.entityPosition(self.parentEntity), mcontroller.position())
    local parentDist = vec2.mag(fromParent)

    local approachSpeed = (standoffDist > parentDist and -1 or 1) * math.min(math.abs(standoffDist - parentDist) ^ 0.75 * 10, maxFlySpeed)
    local approachVec = vec2.mul(vec2.div(fromParent, parentDist), approachSpeed)

    mcontroller.controlApproachVelocity(approachVec, flyForce * traction)

    updateAttack()

    coroutine.yield()
  end
end

function updateAttack()
  if self.attackMode == "Target" then
    findTarget()
  else
    local idleAngle = math.atan(self.targetOffset[2], self.targetOffset[1])
    setRotation(idleAngle)
  end

  if self.gunConfig then
    if self.fireDelayTimer > 0 then
      self.fireDelayTimer = self.fireDelayTimer - script.updateDt()
    else
      self.fireTimer = math.max(0, self.fireTimer - script.updateDt())
      if self.fireTimer == 0 then
        self.fireTimer = self.gunConfig.fireTime
        animator.playSound("fire")
        fire()
      end
    end
  end
end

function fire()
  local baseAimAngle = mcontroller.rotation()
  local baseAimVector = vec2.withAngle(baseAimAngle)
  local baseFirePosition = vec2.add(mcontroller.position(), vec2.rotate(self.gunConfig.fireOffset, baseAimAngle))

  if mcontroller.zeroG() then
    self.gunConfig.projectileParameters.referenceVelocity = mcontroller.velocity()
  else
    self.gunConfig.projectileParameters.referenceVelocity = nil
  end

  local pCount = self.gunConfig.projectileCount or 1
  local pSpread = self.gunConfig.projectileSpread or 0
  local inacc = self.gunConfig.projectileInaccuracy or 0
  local aimVec = vec2.rotate(baseAimVector, -0.5 * (pCount - 1) * pSpread)

  local firePos = baseFirePosition
  local pSpacing
  if self.gunConfig.projectileSpacing and pCount > 1 then
    pSpacing = vec2.rotate(self.gunConfig.projectileSpacing, baseAimAngle)
    firePos = vec2.add(firePos, vec2.mul(pSpacing, (pCount - 1) * -0.5))
  end

  for i = 1, pCount do
    local thisFirePos = firePos
    if self.gunConfig.projectileRandomOffset then
      thisFirePos = vec2.add(thisFirePos, {(math.random() - 0.5) * self.gunConfig.projectileRandomOffset[1], (math.random() - 0.5) * self.gunConfig.projectileRandomOffset[2]})
    end

    local thisAimVec = aimVec
    if self.gunConfig.projectileInaccuracy then
      thisAimVec = vec2.rotate(thisAimVec, sb.nrand(self.gunConfig.projectileInaccuracy, 0))
    end

    world.spawnProjectile(
        self.gunConfig.projectileType,
        thisFirePos,
        self.parentEntity,
        thisAimVec,
        self.gunConfig.projectileTrackSource,
        self.gunConfig.projectileParameters)

    aimVec = vec2.rotate(aimVec, pSpread)
    if pSpacing then
      firePos = vec2.add(firePos, pSpacing)
    end
  end
end

function findTarget()
  local pos = mcontroller.position()
  local candidates = world.entityQuery(pos, self.targetRange, self.targetQueryParameters)

  for _, candidate in ipairs(candidates) do
    if world.entityCanDamage(self.parentEntity, candidate) then
      local canPos = world.entityPosition(candidate)
      if not world.lineTileCollision(pos, canPos) then
        local toTarget = world.distance(canPos, pos)
        local toTargetAngle = vec2.angle(toTarget)
        setRotation(toTargetAngle)

        return
      end
    end
  end

  -- no target found, don't shoot
  self.fireTimer = self.gunConfig.fireTime

  local idleAngle = vec2.angle(world.distance(world.entityPosition(self.parentEntity), mcontroller.position())) + math.pi
	setRotation(idleAngle)
end
