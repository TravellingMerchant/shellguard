-- Melee combo edit! to shoot projectiles, by Nebulox!

-- Melee primary ability
NebSGProjectileCombo = WeaponAbility:new()

function NebSGProjectileCombo:init()
  self.comboStep = 1

  self.energyUsage = self.energyUsage or 0

  self:computeDamageAndCooldowns()

  self.weapon:setStance(self.stances.idle)

  self.edgeTriggerTimer = 0
  self.flashTimer = 0
  self.cooldownTimer = self.cooldowns[1]

  self.animKeyPrefix = self.animKeyPrefix or ""

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

-- Ticks on every update regardless if this is the active ability
function NebSGProjectileCombo:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.cooldownTimer > 0 then
    self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
    if self.cooldownTimer == 0 then
      self:readyFlash()
    end
  end

  if self.flashTimer > 0 then
    self.flashTimer = math.max(0, self.flashTimer - self.dt)
    if self.flashTimer == 0 then
      animator.setGlobalTag("bladeDirectives", "")
    end
  end

  self.edgeTriggerTimer = math.max(0, self.edgeTriggerTimer - dt)
  if self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) and fireMode == (self.activatingFireMode or self.abilitySlot) then
    self.edgeTriggerTimer = self.edgeTriggerGrace
  end
  self.lastFireMode = fireMode

  if not self.weapon.currentAbility and self:shouldActivate() then
    self:setState(self.windup)
  end
end

-- State: windup
function NebSGProjectileCombo:windup()
  local stance = self.stances["windup"..self.comboStep]

  self.weapon:setStance(stance)

  self.edgeTriggerTimer = 0

  if stance.hold then
    while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
      coroutine.yield()
    end
  else
    util.wait(stance.duration)
  end

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances["preslash"..self.comboStep] then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: wait
-- waiting for next combo input
function NebSGProjectileCombo:wait()
  local stance = self.stances["wait"..(self.comboStep - 1)]

  self.weapon:setStance(stance)

  util.wait(stance.duration, function()
    if self:shouldActivate() then
      self:setState(self.windup)
      return
    end
  end)
  
  self.weapon:setStance(self.stances.idle)
  self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
  self.comboStep = 1
end

-- State: preslash
-- brief frame in between windup and fire
function NebSGProjectileCombo:preslash()
  local stance = self.stances["preslash"..self.comboStep]

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  util.wait(stance.duration)

  self:setState(self.fire)
end

-- State: fire
function NebSGProjectileCombo:fire()
  local stance = self.stances["fire"..self.comboStep]
	local canFire = true
	local loopTimer = 0

  self.weapon:setStance(stance)
  self.weapon:updateAim()

  local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
  animator.setAnimationState("swoosh", animStateKey)
  animator.playSound(animStateKey)

  local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
  animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
  animator.burstParticleEmitter(swooshKey)

  local progress = 0
  util.wait(stance.duration, function(dt)
    local damageArea = partDamageArea("swoosh")
    self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
		
		--Options--
		if stance.gunShotConfig and canFire then
			local firePosition = vec2.add(mcontroller.position(), activeItem.handPosition(stance.gunShotConfig.projectileFirePoint or animator.partPoint("blade", "projectileFirePoint") or {0,0}))
			local params = stance.gunShotConfig.projectileParameters or {}
			params.power = stance.gunShotConfig.projectileDamage * config.getParameter("damageLevelMultiplier") / stance.gunShotConfig.projectileCount or 1
			params.powerMultiplier = activeItem.ownerPowerMultiplier()
			params.speed = util.randomInRange(params.speed)
			
			world.debugPoint(firePosition, "red")
			
			if not world.lineTileCollision(mcontroller.position(), firePosition) and status.overConsumeResource("energy", stance.gunShotConfig.energyUsage) then
				--Muzzle Flash--
				animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
				animator.burstParticleEmitter("muzzleFlash")
				animator.setAnimationState("firing", "fire")
				animator.playSound(stance.gunShotConfig.fireSound or "gunfire")

				animator.setLightActive("muzzleFlash", true)
			
				
			
				--Recoil--
				if stance.gunShotConfig.recoilKnockbackVelocity then
					--Aim Vector--
					local aimVector = vec2.rotate({1, 0}, (stance.gunShotConfig.aimAtCursor and (activeItem.aimAngle(0, activeItem.ownerAimPosition())) or self.weapon.aimAngle) + sb.nrand(stance.gunShotConfig.projectileInaccuracy or 0, 0) + (stance.gunShotConfig.projectileAimAngleOffset or 0))
					if stance.gunShotConfig.aimAtCursor then
					  aimVector = vec2.mul(aimVector,{mcontroller.facingDirection(),1})
					end
					aimVector[1] = aimVector[1] * mcontroller.facingDirection()
					--If not crouching or if crouch does not impact recoil
					if not (stance.gunShotConfig.crouchStopsRecoil and mcontroller.crouching()) then
						local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(aimVector, -1)), stance.gunShotConfig.recoilKnockbackVelocity)
						--If aiming down and not in zero G, reset Y velocity first to allow for breaking of falls
						if (self.weapon.aimAngle <= 0 and not mcontroller.zeroG()) then
						mcontroller.setYVelocity(0)
						end
						mcontroller.addMomentum(recoilVelocity)
						mcontroller.controlJump()
					--If crouching
					elseif stance.gunShotConfig.crouchRecoilKnockbackVelocity then
						local recoilVelocity = vec2.mul(vec2.norm(vec2.mul(aimVector, -1)), stance.gunShotConfig.crouchRecoilKnockbackVelocity)
						mcontroller.setYVelocity(0)
						mcontroller.addMomentum(recoilVelocity)
					end
				end
		
				
				--Spawn the Projectile--
				for i = 1, (stance.gunShotConfig.projectileCount or 1) do
					world.spawnProjectile(
						stance.gunShotConfig.projectile,
						firePosition,
						activeItem.ownerEntityId(),
						self:aimVector(stance),
						false,
						params
					)
				end
			end
			canFire = false
		end
		if stance.gunShotConfig then
			if stance.gunShotConfig.fireTime and not canFire then
				loopTimer = loopTimer + dt
				if loopTimer >= stance.gunShotConfig.fireTime then
					loopTimer = 0
					canFire = true
				end
			end
		end
	if stance.endWeaponRotation then
      local from = stance.weaponOffset or {0,0}
      local to = stance.endWeaponOffset or {0,0}
      self.weapon.weaponOffset = {util.interpolateHalfSigmoid(progress, from[1], to[1]), util.interpolateHalfSigmoid(progress, from[2], to[2])}

      self.weapon.relativeWeaponRotation = util.toRadians(util.interpolateHalfSigmoid(progress, stance.weaponRotation, stance.endWeaponRotation))
      self.weapon.relativeArmRotation = util.toRadians(util.interpolateHalfSigmoid(progress, stance.armRotation, stance.endArmRotation))

      progress = math.min(1.0, progress + (self.dt / stance.duration))
	end
  end)

  if self.comboStep < self.comboSteps then
    self.comboStep = self.comboStep + 1
    self:setState(self.wait)
  else
    self.weapon:setStance(self.stances.idle)
    self.cooldownTimer = self.cooldowns[self.comboStep]
    self.comboStep = 1
  end
end

function NebSGProjectileCombo:shouldActivate()
  if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    if self.comboStep > 1 then
      return self.edgeTriggerTimer > 0
    else
      return self.fireMode == (self.activatingFireMode or self.abilitySlot)
    end
  end
end

function NebSGProjectileCombo:readyFlash()
  animator.setGlobalTag("bladeDirectives", self.flashDirectives)
  self.flashTimer = self.flashTime
end

function NebSGProjectileCombo:computeDamageAndCooldowns()
  local attackTimes = {}
  for i = 1, self.comboSteps do
    local attackTime = self.stances["windup"..i].duration + self.stances["fire"..i].duration
    if self.stances["preslash"..i] then
      attackTime = attackTime + self.stances["preslash"..i].duration
    end
    table.insert(attackTimes, attackTime)
  end

  self.cooldowns = {}
  local totalAttackTime = 0
  local totalDamageFactor = 0
  for i, attackTime in ipairs(attackTimes) do
    self.stepDamageConfig[i] = util.mergeTable(copy(self.damageConfig), self.stepDamageConfig[i])
    self.stepDamageConfig[i].timeoutGroup = "primary"..i

    local damageFactor = self.stepDamageConfig[i].baseDamageFactor
    self.stepDamageConfig[i].baseDamage = damageFactor * self.baseDps * self.fireTime

    totalAttackTime = totalAttackTime + attackTime
    totalDamageFactor = totalDamageFactor + damageFactor

    local targetTime = totalDamageFactor * self.fireTime
    local speedFactor = 1.0 * (self.comboSpeedFactor ^ i)
    table.insert(self.cooldowns, (targetTime - totalAttackTime) * speedFactor)
  end
end

--Aim vector for firing projectiles
function NebSGProjectileCombo:aimVector(stance)
  local aimVector = vec2.rotate({1, 0}, (stance.gunShotConfig.aimAtCursor and (activeItem.aimAngle(0, activeItem.ownerAimPosition())) or self.weapon.aimAngle) + sb.nrand(stance.gunShotConfig.projectileInaccuracy or 0, 0) + (stance.gunShotConfig.projectileAimAngleOffset or 0))
  if stance.gunShotConfig.aimAtCursor then
    aimVector = vec2.mul(aimVector,{mcontroller.facingDirection(),1})
  end
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function NebSGProjectileCombo:uninit()
  self.weapon:setDamage()
end
