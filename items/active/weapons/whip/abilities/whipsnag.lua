require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"
require "/scripts/rope.lua"

-- whip primary attack plus swinging from absolutely anything and more
WhipSnag = WeaponAbility:new()

function WhipSnag:init()
  self.damageConfig.baseDamage = self.chainDps * self.fireTime

  self.weapon:setStance(self.stances.idle)
  animator.setAnimationState("attack", "idle")
  activeItem.setScriptedAnimationParameter("chains", nil)

  self.cooldownTimer = self:cooldownTime()

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end

  self.projectileConfig = self.projectileConfig or {}


  self.chain = config.getParameter("chain")
  
  self.didSnagInitSnap = false
  self.anchor = nil
  self.anchorKind = nil
  self.anchorEntityType = nil
  self.ropeProjectiles = {}
  self.movedSinceLastTick = false
  self.previousPos = mcontroller.position()
  self.rope = {}
  
  self.movement = {}

  self.DoTTickCooldown = self.DoTTickSpeed
  self.ropeRandomProjectileCooldown = self.ropeRandomProjectileSpeed

  if not self.cutoffRange or self.cutoffRange == 0 then
    self.cutoffRange = false
  end
  
  self.dotProjectileConfig = self.dotProjectileConfig or {}
end

-- Ticks on every update regardless if this is the active ability
function WhipSnag:update(dt, fireMode, shiftHeld, moves)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  --why no mcontroller.moving()
  self.movedSinceLastTick = not vec2.eq(self.previousPos, mcontroller.position())
  self.previousPos = mcontroller.position()

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.DoTTickCooldown = math.max(0, self.DoTTickCooldown - self.dt)
  self.ropeRandomProjectileCooldown = math.max(0, self.ropeRandomProjectileCooldown - self.dt)
  
  if (self.triggerType == nil) or (self.triggerType == "hold") then
    if self.fireMode == (self.activatingFireMode or self.abilitySlot) and self:canStartAttack() then
      self:setState(self.windup)
      self.fireHeld = true
    elseif self.fireMode ~= (self.activatingFireMode or self.abilitySlot) and self.fireHeld then
      self.fireHeld = false
      self:disconnect()
    end
  elseif self.triggerType == "switch" then
    if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) then
      if self.fireHeld then
        self.fireHeld = false
        self:disconnect()
      elseif self:canStartAttack() then
        self:setState(self.windup)
        self.fireHeld = true
      end
    end
  end
  
  self.movement = moves --if loaded by a wrong loader, nils. Not dangerous unless wrong loader AND controllable.
  
  if self.killRopeProjectileWhenMoving and #self.ropeProjectiles > 0 and self.movedSinceLastTick then
    for _, projectileId in pairs(self.ropeProjectiles) do
      world.sendEntityMessage(projectileId, "kill")
    end
    self.ropeProjectiles = {}
  end

  self.lastFireMode = fireMode
end

function WhipSnag:canStartAttack()
  return not self.weapon.currentAbility and self.cooldownTimer == 0
end

-- State: windup
function WhipSnag:windup()
  self.weapon:setStance(self.stances.windup)

  animator.setAnimationState("attack", "windup")

  util.wait(self.stances.windup.duration)

  self:setState(self.extend)
end

-- State: extend
function WhipSnag:extend()
  self.weapon:setStance(self.stances.extend)

  animator.setAnimationState("attack", "extend")
  animator.playSound("swing")

  util.wait(self.stances.extend.duration)

  if self.fireHeld then
    self.anchor = self:findAnchor()
  end

  if self.anchor then
    animator.setAnimationState("attack", "fire")
    self:setState(self.swing)
  else
    animator.setAnimationState("attack", "fire")
    self:setState(self.fire)
  end
end

-- State: swing
function WhipSnag:swing()
  self.weapon:setStance(self.stances.swing)
  self.weapon:updateAim()

  self.cooldownTimer = self:cooldownTime()

  animator.burstParticleEmitter("crack")
  animator.playSound("crack")

  while self.anchor do
    --sb.logInfo("swing| anchor: %s | anchorKind: %s | anchorEntityType: %s | anchorPos: %s", self.anchor, self.anchorKind, self.anchorEntityType, self.anchorPos)
    local handPosition = vec2.add(mcontroller.position(), activeItem.handPosition(self.chain.startOffset))
    local chainStartPos = handPosition
    local chainEndPos

    if self.anchorKind == "entity" and world.entityExists(self.anchor) then
      chainEndPos = world.entityPosition(self.anchor)
    elseif self.anchorKind == "tile" then
        chainEndPos = self.anchor
    else
      self:disconnect()
      return
    end

    world.debugLine(chainStartPos, chainEndPos, "pink")

    local newRope
    if #self.rope == 0 then
      newRope = {chainStartPos, chainEndPos}
    else
      newRope = copy(self.rope)
      table.insert(newRope, 1, world.nearestTo(newRope[1], chainStartPos))
      table.insert(newRope, world.nearestTo(newRope[#newRope], chainEndPos))
    end

    windRope(newRope)
    self:updateRope(newRope)

    if not self.cutoffRange or self.ropeLength <= self.cutoffRange then
      local aimVector = world.distance(self.rope[2], chainStartPos)
      local swingAngle = vec2.angle(aimVector)
      local distanceFromFirstSegment = world.magnitude(handPosition, self.rope[2])
      world.debugLine(handPosition, self.rope[2], "blue")
      world.debugText("distanceFromFirstSegment: %s", distanceFromFirstSegment, vec2.add(handPosition, {5, 5}), "blue")
      sb.setLogMap("distanceFromFirstSegment", ": %s", distanceFromFirstSegment)
      
      if distanceFromFirstSegment >= self.minSwingDistance and (not self.onlyPullWhileAirborne or not mcontroller.groundMovement()) then
        --up/down moves
        if self.controllable and self.movement.down and self.ropeLength < (self.cutoffRange or self.chain.length[2]) - 4 then
          mcontroller.controlApproachVelocityAlongAngle(swingAngle, -self.reelSpeed, self.maxControlForce, true)
        elseif self.controllable and self.movement.up and self.ropeLength > self.chain.length[1] then
          mcontroller.controlApproachVelocityAlongAngle(swingAngle,  self.reelSpeed, self.maxControlForce, true)
        elseif not self.onlyPullWhenAboveAnchor or aimVector[2] > 0 then
          mcontroller.controlApproachVelocityAlongAngle(swingAngle, 0, self.maxControlForce, true)
        end
        
        --left/right moves. Technically, player moves by themselves, they have a small 0 g thruster, but this part makes the thruster stronger.
        if self.controllable and (self.movement.left or self.movement.right) then
          mcontroller.controlParameters({airForce = self.airForce})
        end
      end

      if self.weapon.aimDirection < 0 then
        self.weapon.aimAngle = vec2.angle({-aimVector[1], aimVector[2]})
      else
        self.weapon.aimAngle = swingAngle
      end
      self.weapon:updateAim()


      --[[ damage part ]]

      if not self.didSnagInitSnap then --todo move that above the while
        self.didSnagInitSnap = true --highly descriptive naming going on here
        self.projectileConfig.power = self:crackDamage()
        self:spawnCrackProjectile(chainEndPos)
      end

      --"dot" projectile
      if self.DoTTickCooldown == 0 then
        self:spawnCrackProjectile(chainEndPos, self.dotProjectileType, self.dotProjectileConfig)
        self.DoTTickCooldown = self.DoTTickSpeed
      end


      --rope projectile
      if self.ropeRandomProjectileCooldown == 0 then 
        self.ropeRandomProjectileCooldown = self.ropeRandomProjectileSpeed
        if self.doSpawnRandomRopeProjectiles and (self.movedSinceLastTick or self.spawnRopeProjectileWhileMoving) then
          local randomSource = sb.makeRandomSource()
          local suitableChainSegment
          local segmentSize
          local shuffled = shuffled(self.ropeChain)

          for _,shuffledSegment in pairs(shuffled) do
            segmentSize = world.magnitude(shuffledSegment.startPosition, shuffledSegment.endPosition)
            if segmentSize >= self.minChainSegmentLengthToSpawnOn / 8 then
              suitableChainSegment = shuffledSegment
              break
            end
          end

          if suitableChainSegment then
            local segmentVector = world.distance(suitableChainSegment.endPosition, suitableChainSegment.startPosition)
            local segmentAngle = vec2.angle(segmentVector)
            local randomSpot = vec2.add(suitableChainSegment.startPosition, vec2.withAngle(segmentAngle, randomSource:randf(0, segmentSize)))
            --local randomSpot = {randomSource:randf(suitableChainSegment.startPosition[1], suitableChainSegment.endPosition[1]), randomSource:randf(suitableChainSegment.startPosition[2], suitableChainSegment.endPosition[2])}
            
            local projectileId = self:spawnCrackProjectile(randomSpot, self.ropeRandomProjectileType, self.ropeRandomProjectileConfig, segmentVector)
            if projectileId then table.insert(self.ropeProjectiles, projectileId) end
          end
        end
      end


      coroutine.yield()
    else
      self:disconnect()
    end
  end
end

function WhipSnag:updateRope(newRope)
  self.rope = newRope
  self.ropeLength = 0
  local chain = {}

  local i = 2
  while i <= #newRope do
    local before = newRope[i - 1]
    local current = newRope[i]
    local after = newRope[i + 1]
    world.debugLine(before, current, "green")

    self.ropeLength = self.ropeLength + world.magnitude(before, current)

    local segment = copy(self.chain)
    segment.startPosition = before
    segment.endPosition = current

    if after then
      segment.endSegmentImage = nil
    end

    i = i + 1

    table.insert(chain, segment)
  end
  self.ropeChain = chain --yeehaw
  activeItem.setScriptedAnimationParameter("chains", chain)
end  

function WhipSnag:disconnect()
  self.rope = {}
  self.ropeLength = 0
  activeItem.setScriptedAnimationParameter("chains", nil)

  self.didSnagInitSnap = false
  self.anchor = nil
  self.anchorKind = nil
  self.anchorEntityType = nil
  animator.setAnimationState("attack", "idle")
  self.chain.endPosition = nil
  
  if self.triggerType == "switch" then
    self.fireHeld = false
  end

  animator.playSound("disconnect")
end

-- State: fire
function WhipSnag:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  local chainStartPos = vec2.add(mcontroller.position(), activeItem.handPosition(self.chain.startOffset))
  local chainLength = world.magnitude(chainStartPos, activeItem.ownerAimPosition())
  chainLength = math.min(self.chain.length[2], math.max(self.chain.length[1], chainLength))

  self.chain.endOffset = vec2.add(self.chain.startOffset, {chainLength, 0})
  local collidePoint = world.lineCollision(chainStartPos, vec2.add(mcontroller.position(), activeItem.handPosition(self.chain.endOffset)))
  if collidePoint then
    chainLength = world.magnitude(chainStartPos, collidePoint) - 0.25
    if chainLength < self.chain.length[1] then
      animator.setAnimationState("attack", "idle")
      return
    else
      self.chain.endOffset = vec2.add(self.chain.startOffset, {chainLength, 0})
    end
  end

  local chainEndPos = vec2.add(mcontroller.position(), activeItem.handPosition(self.chain.endOffset))

  activeItem.setScriptedAnimationParameter("chains", {self.chain})

  animator.resetTransformationGroup("endpoint")
  animator.translateTransformationGroup("endpoint", self.chain.endOffset)
  animator.burstParticleEmitter("crack")
  animator.playSound("crack")

  self.projectileConfig.power = self:crackDamage()
  self.projectileConfig.powerMultiplier = activeItem.ownerPowerMultiplier()

  self:spawnCrackProjectile(chainEndPos)

  util.wait(self.stances.fire.duration, function()
    if self.damageConfig.baseDamage > 0 then
      self.weapon:setDamage(self.damageConfig, {self.chain.startOffset, {self.chain.endOffset[1] + 0.75, self.chain.endOffset[2]}}, self.fireTime)
    end
  end)

  animator.setAnimationState("attack", "idle")
  activeItem.setScriptedAnimationParameter("chains", nil)
  
  if self.triggerType == "switch" then
    self.fireHeld = false
  end

  self.cooldownTimer = self:cooldownTime()
end

function WhipSnag:cooldownTime()
  return self.fireTime - (self.stances.windup.duration + self.stances.extend.duration + self.stances.fire.duration)
end

function WhipSnag:uninit(unloaded)
  self.weapon:setDamage()
  activeItem.setScriptedAnimationParameter("chains", nil)
end


function WhipSnag:spawnCrackProjectile(pos, projectileType, projectileConfig, projectileAngle)
  projectileType = projectileType or self.projectileType
  projectileConfig = projectileConfig or self.projectileConfig

  if projectileType == nil or projectileType == "" then return end

  if not projectileAngle then
    projectileAngle = vec2.withAngle(self.weapon.aimAngle)
    if self.weapon.aimDirection < 0 then projectileAngle[1] = -projectileAngle[1] end
  end

  return world.spawnProjectile(
    projectileType,
    pos,
    activeItem.ownerEntityId(),
    projectileAngle,
    false,
    projectileConfig
  )
end

function WhipSnag:chainDamage()
  return (self.chainDps * self.fireTime) * config.getParameter("damageLevelMultiplier")
end

function WhipSnag:crackDamage()
  return (self.crackDps * self.fireTime) * config.getParameter("damageLevelMultiplier")
end

function WhipSnag:isAnchorValid(pos)
  --pos = vec2.add(pos,{self:getAnchorPos(anchorValid)[1],0})
  --local distToCursor = world.magnitude(pos, activeItem.ownerAimPosition())
  --if distToCursor <= self.snapDistance and distToHand <= self.chain.length[2] and distToHand >= self.chain.length[1] then --original
  local distToHand = world.magnitude(pos, vec2.add(mcontroller.position(), activeItem.handPosition(self.chain.startOffset)))
  if distToHand <= self.chain.length[2] and distToHand >= self.chain.length[1] then
    return true
  end

  return false
end

function WhipSnag:findAnchor()
  local col = world.lineCollision(mcontroller.position(), activeItem.ownerAimPosition())
  local colDistance = nil
  if col then
    colDistance = world.magnitude(mcontroller.position(), col)
  end

  for i, targetId in ipairs(world.entityLineQuery(mcontroller.position(), activeItem.ownerAimPosition(), {boundMode = "collisionarea", order = "nearest", includedTypes = self.targetTypes, withoutEntityId = activeItem.ownerEntityId()})) do
    --sb.logInfo("potential anchor: %s %s", i, targetId)
    local entityPos = world.entityPosition(targetId)
    local entityDistance = world.magnitude(mcontroller.position(), entityPos)
    if col and colDistance < entityDistance then --return tile collision if the ground's closer than the entity
      if self.canSnagTerrain and self:isAnchorValid(col) then
        self.anchorKind = "tile"
        return col
      else
        return
      end
    elseif self:isAnchorValid(entityPos) then --else return the nearest entity in line
      self.anchorKind = "entity"
      self.anchorEntityType = world.entityType(targetId)
      return targetId
    end
  end

  if col and self.canSnagTerrain and self:isAnchorValid(col) then --repetitive lame code but I'm too tired, sorry future me or whoever you are!
    self.anchorKind = "tile"
    return col
  end
end