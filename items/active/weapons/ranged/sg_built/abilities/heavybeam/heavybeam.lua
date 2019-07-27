require "/scripts/util.lua"
require "/scripts/interp.lua"

HeavyBeam = WeaponAbility:new()

function HeavyBeam:init()
  self.beamLength = self.beamLength / (self.projectileCount ^ 0.45) * (self.fireTime ^ 0.25)
  
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime
  self.beamTimer = 0
  self.beamState = 0
  
  self.inaccuracyArray = {}

  self.weapon.onLeaveAbility = function()
    self.weapon:setOwnerDamage()
    activeItem.setScriptedAnimationParameter("chains", {})
    self.weapon:setStance(self.stances.idle)
  end
end

function HeavyBeam:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  
  --world.debugText("%s", self.cooldownTimer, vec2.add(mcontroller.position(), {0, 3}),"red")

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
  self.beamTimer = math.max(0, self.beamTimer - self.dt)
  
  --world.debugText("%s", self.cooldownTimer, vec2.add(mcontroller.position(), {0, 2}),"red")

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  if self.beamState == 1 then
    if self.beamTimer == 0 then
      self:reset()
      self.beamTimer = self.burstTime and (self.burstTime / 4) or self.stances.fire.cooldown
      self.beamState = 2
    else
      local damage = {}
      local chains = {}
      for i = 1, (projectileCount or self.projectileCount) do
        local beamStart = self:firePosition()
        local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(self.inaccuracyArray[i])), self.beamLength))
        local beamLength = self.beamLength
        local collidePoint = world.lineCollision(beamStart, beamEnd)
        if collidePoint then
          beamEnd = collidePoint
      
          beamLength = world.magnitude(beamStart, beamEnd)
        end
        chains[i] = self:drawBeam(beamEnd, collidePoint, self.chain)
        
        damage[i] = self:damageSource(self.damageConfig, {self:localPos(beamStart), self:localPos(beamEnd)}, self.burstTime or self.fireTime)
      end
      
      self.weapon.damageWasSet = true
      self.weapon.damageCleared = false
      activeItem.setDamageSources(damage)
      
      activeItem.setScriptedAnimationParameter("chains", chains)
    end
  elseif self.beamState == 2 then
    if self.beamTimer == 0 then
      self:reset()
      self.beamState = 0
    else
      local chains = {}
      for i = 1, (projectileCount or self.projectileCount) do
        local beamStart = self:firePosition()
        local beamEnd = vec2.add(beamStart, vec2.mul(vec2.norm(self:aimVector(self.inaccuracyArray[i])), self.beamLength))
        local beamLength = self.beamLength
        local collidePoint = world.lineCollision(beamStart, beamEnd)
        if collidePoint then
          beamEnd = collidePoint
      
          beamLength = world.magnitude(beamStart, beamEnd)
        end
        chains[i] = self:drawBeam(beamEnd, collidePoint, self.weakChain)
      end
      
      activeItem.setScriptedAnimationParameter("chains", chains)
    end
  end
  
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then

    if self.fireType == "auto" and status.overConsumeResource("energy", self:energyPerShot()) then
      self:setState(self.auto)
    elseif self.fireType == "burst" then
      self:setState(self.burst)
    end
  end
end

function HeavyBeam:auto()
  self.weapon:setStance(self.stances.fire)

  self:muzzleFlash()
  self:fireProjectile()

  if self.stances.fire.duration then
    util.wait(self.stances.fire.duration)
  end

  self.cooldownTimer = self.fireTime
  self:setState(self.cooldown)
end

function HeavyBeam:burst()
  self.weapon:setStance(self.stances.fire)

  local shots = self.burstCount
  while shots > 0 and status.overConsumeResource("energy", self:energyPerShot()) do
    self:muzzleFlash()
    self:fireProjectile()
    shots = shots - 1

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - shots / self.burstCount, 0, self.stances.fire.armRotation))

    util.wait(self.burstTime)
  end

  self.cooldownTimer = (self.fireTime - self.burstTime) * self.burstCount
end

function HeavyBeam:cooldown()
  self.weapon:setStance(self.stances.cooldown)
  self.weapon:updateAim()

  local progress = 0
  util.wait(self.stances.cooldown.duration, function()
    local from = self.stances.cooldown.weaponOffset or {0,0}
    local to = self.stances.idle.weaponOffset or {0,0}
    self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

    self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.weaponRotation, self.stances.idle.weaponRotation))
    self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.cooldown.armRotation, self.stances.idle.armRotation))

    progress = math.min(1.0, progress + (self.dt / self.stances.cooldown.duration))
  end)
end

function HeavyBeam:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function HeavyBeam:fireProjectile()
  self.beamTimer = self.burstTime and (self.burstTime / 2) or self.stances.fire.duration
  self.beamState = 1
  for i = 1, (projectileCount or self.projectileCount) do
    self.inaccuracyArray[i] = sb.nrand(self.inaccuracy, 0)
  end
end

function HeavyBeam:firePosition()
  --return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
  return vec2.add(mcontroller.position(), vec2.rotate(activeItem.handPosition(self.weapon.muzzleOffset), -self.weapon.relativeArmRotation * self.weapon.aimDirection))
end

function HeavyBeam:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + inaccuracy)
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function HeavyBeam:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function HeavyBeam:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier")
end

function HeavyBeam:uninit()
  self:reset()
end


function HeavyBeam:reset()
  self.weapon:setOwnerDamage()
  activeItem.setScriptedAnimationParameter("chains", {})
end

function HeavyBeam:drawBeam(endPos, didCollide, chain)
  local newChain = copy(chain)
  newChain.startPosition = self:firePosition()
  newChain.endPosition = endPos

  if didCollide then
    newChain.endSegmentImage = nil
  end

  return newChain
end

function HeavyBeam:damageSource(damageConfig, damageArea, damageTimeout)
  if damageArea then
    local knockback = damageConfig.knockback
    if knockback and damageConfig.knockbackDirectional ~= false then
      knockback = knockbackMomentum(damageConfig.knockback, damageConfig.knockbackMode, self.weapon.aimAngle, self.weapon.aimDirection)
    end
    local damage = self:damagePerShot() * activeItem.ownerPowerMultiplier()

    local damageLine, damagePoly
    if #damageArea == 2 then
      damageLine = damageArea
    else
      damagePoly = damageArea
    end

    return {
      poly = damagePoly,
      line = damageLine,
      damage = damage,
      trackSourceEntity = damageConfig.trackSourceEntity,
      sourceEntity = activeItem.ownerEntityId(),
      team = damageConfig.damageTeam or activeItem.ownerTeam(),
      damageSourceKind = damageConfig.damageSourceKind,
      statusEffects = damageConfig.statusEffects,
      knockback = knockback or 0,
      rayCheck = damageConfig.rayCheck,
      damageRepeatGroup = damageRepeatGroup(damageConfig.timeoutGroup),
      damageRepeatTimeout = damageTimeout or damageConfig.timeout
    }
  end
end

function HeavyBeam:localAimVector(inaccuracy)
  return vec2.rotate({1, 0}, inaccuracy)
end

function HeavyBeam:localPos(vector)
  return world.distance(vector, mcontroller.position())
end