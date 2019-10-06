require "/scripts/util.lua"
require "/scripts/interp.lua"

TexasRedPrimary = WeaponAbility:new()

function TexasRedPrimary:init()
	self.currentType = config.getParameter("currentType","blade")
	self.weapon:setStance(self.stances[self.currentType.."Idle"])

	self.cooldownTimer = 0
	self.chargeTimer = 0
	self.edgeTriggerTimer = 0
	self.flashTimer = 0
	self.animKeyPrefix = self.animKeyPrefix or ""
	self:computeDamageAndCooldowns()
	self.comboStep = 1
	
	self.weapon.onLeaveAbility = function()
		self.weapon:setStance(self.stances[self.weapon.currentType.."Idle"])
	end
end

function TexasRedPrimary:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)

	if self.cooldownTimer > 0 then
		self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)
		if self.cooldownTimer == 0 and self.weapon.currentType == "blade" then
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
	if self.fireMode == "primary"
		and self.weapon.currentType == "gun"
		and self.cooldownTimer == 0
		and not self.weapon.currentAbility
		and not world.lineTileCollision(mcontroller.position(), self:firePosition())
		and not status.resourceLocked("energy") then
		self:setState(self.gunCharge)
	end
	if not self.weapon.currentAbility and self:shouldActivate() then
		self:setState(self.windup)
	end
	if self.fireMode == "alt" and not shiftHeld
		and self.weapon.currentType == "gun"
		and self.cooldownTimer == 0
		and not self.weapon.currentAbility
		and not world.lineTileCollision(mcontroller.position(), self:firePosition())
		and not status.resourceLocked("energy") then
		self:setState(self.gunFullAuto)
	end
	if not self.weapon.currentAbility and not shiftHeld
		and self.weapon.currentType == "blade"
		and self.cooldownTimer == 0
		and self.fireMode == "alt"
		and not status.statPositive("activeMovementAbilities")
		and status.overConsumeResource("energy", self.flipEnergyUsage) then

		self:setState(self.flipWindup)
	end
end

function TexasRedPrimary:shouldActivate()
	if self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
		if self.comboStep > 1 then
			return self.edgeTriggerTimer > 0 and self.weapon.currentType == "blade"
		else
			return self.fireMode == "primary" and self.weapon.currentType == "blade"
		end
	end
end

function TexasRedPrimary:gunCharge()
	self.weapon:setStance(self.stances.gunCharge)
	if self.chargeAnimation then
		animator.setAnimationState("firing", "charge")
	end

	self.chargeTimer = 0

	while self.fireMode == (self.activatingFireMode or self.abilitySlot) and status.overConsumeResource("energy",(self.energyPerSecond or 0) * self.dt) do
		self.chargeTimer = self.chargeTimer + self.dt
		if self.maxCharge then
			self.chargeTimer = math.min(self.chargeTimer,self.maxCharge)
			if self.maxCharge == self.chargeTimer and not self.hasPlayedFullCharge and animator.hasSound("fullCharge") then
				animator.playSound("fullCharge")
			self.hasPlayedFullCharge = true
			end
		end
		coroutine.yield()
	end
	self.hasPlayedFullCharge = false
	self.chargeLevel = self:currentChargeLevel()
	local energyCost = (self.chargeLevel and self.chargeLevel.energyCost) or 0
	if self.chargeLevel and (energyCost == 0 or status.overConsumeResource("energy", energyCost)) then
		self:setState(self.gunFire)
	end
end

function TexasRedPrimary:gunFullAuto()
	self.weapon:setStance(self.stances.gunCharge)
	self.chargeLevel = self.chargeLevels[1]
	local energyCost = (self.chargeLevel and self.chargeLevel.energyCost) or 0
	if self.chargeLevel and (energyCost == 0 or status.overConsumeResource("energy", energyCost)) and status.overConsumeResource("energy", self.fullAutoEnergy or 0) then
		self:setState(self.gunFire)
	end
end

function TexasRedPrimary:gunFire()
	if world.lineTileCollision(mcontroller.position(), self:firePosition()) then
		animator.setAnimationState("firing", "off")
		self.cooldownTimer = self.chargeLevel.cooldown or 0
		self:setState(self.gunCooldown, self.cooldownTimer)
		return
	end

	self.weapon:setStance(self.stances.gunFire)

	for i = 1, self.chargeLevel.burstCount or 1 do
		if world.lineTileCollision(mcontroller.position(), self:firePosition()) then
			animator.setAnimationState("firing", "off")
			self.cooldownTimer = self.chargeLevel.cooldown or 0
			self:setState(self.gunCooldown, self.cooldownTimer)
			return
		end
		if i > 1 then
			if not status.overConsumeResource("energy",self.chargeLevel.energyCost) then
				break
			end
		end
		self:fireProjectile()
		self:recoil()
		animator.setAnimationState("firing", self.chargeLevel.fireAnimationState or "fire")
		animator.playSound(self.chargeLevel.fireSound or "fire")
		self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(1 - ((self.chargeLevel.burstCount or 1) - i) / (self.chargeLevel.burstCount or 1), self.stances.gunIdle.armRotation+self.stances.gunFire.weaponRotation, self.stances.gunFire.weaponRotation))
		self.weapon.relativeArmRotation = util.toRadians(interp.linear(1 - ((self.chargeLevel.burstCount or 1) - i) / (self.chargeLevel.burstCount or 1), self.stances.gunIdle.armRotation+self.stances.gunFire.armRotation, self.stances.gunFire.armRotation))
		if self.chargeLevel.fireType == "burst" and self.chargeLevel.burstTime then
			util.wait(self.chargeLevel.burstTime)
		end
	end

	if self.stances.gunFire.duration then
		util.wait(self.stances.gunFire.duration)
	end
	if self.chargeLevel.burstCount then
		self.cooldownTimer = (self.chargeLevel.cooldown - self.chargeLevel.burstTime) * self.chargeLevel.burstCount
	else
		self.cooldownTimer = self.chargeLevel.cooldown or 0
	end

	self:setState(self.gunCooldown, self.cooldownTimer)
end

function TexasRedPrimary:recoil()
	if self.chargeLevel.recoilKnockbackVelocity then
		if not (self.chargeLevel.crouchStallsRecoil and mcontroller.crouching()) then
			local momentumAngle,_ = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
			mcontroller.addMomentum(vec2.mul(vec2.rotate(self.chargeLevel.recoilKnockbackVelocity, momentumAngle),{mcontroller.facingDirection(),1}))
		elseif self.chargeLevel.crouchRecoilKnockbackVelocity then
			local momentumAngle,_ = activeItem.aimAngleAndDirection(0, activeItem.ownerAimPosition())
			mcontroller.addMomentum(vec2.mul(vec2.rotate(self.chargeLevel.crouchRecoilKnockbackVelocity, momentumAngle),{mcontroller.facingDirection(),1}))
		end
	end
end

function TexasRedPrimary:gunCooldown(duration)
	self.weapon:setStance(self.stances.gunCooldown)
	self.weapon:updateAim()

	local progress = 0
	util.wait(duration, function()
		local from = self.stances.gunCooldown.weaponOffset or {0,0}
		local to = self.stances.gunIdle.weaponOffset or {0,0}
		self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}

		self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.stances.gunCooldown.weaponRotation, self.stances.gunIdle.weaponRotation))
		self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.stances.gunCooldown.armRotation, self.stances.gunIdle.armRotation))

		progress = math.min(1.0, progress + (self.dt / duration))
	end)
end

function TexasRedPrimary:firePosition()
	return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset or {0,0}))
end

function TexasRedPrimary:aimVector(inaccuracy)
	local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
	aimVector[1] = aimVector[1] * mcontroller.facingDirection()
	return aimVector
end

function TexasRedPrimary:energyPerShot()
	return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function TexasRedPrimary:damagePerShot()
	return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function TexasRedPrimary:currentChargeLevel()
	local bestChargeTime = 0
	local bestChargeLevel
	for _, chargeLevel in pairs(self.chargeLevels) do
		if self.chargeTimer >= chargeLevel.time and self.chargeTimer >= bestChargeTime then
			bestChargeTime = chargeLevel.time
			bestChargeLevel = chargeLevel
		end
	end
	return bestChargeLevel
end

function TexasRedPrimary:fireProjectile()
	local projectileCount = self.chargeLevel.projectileCount or 1

	local params = copy(self.chargeLevel.projectileParameters or {})
	params.power = (self.chargeLevel.baseDamage * config.getParameter("damageLevelMultiplier")) / projectileCount
	if self.chargePowerMultiplier then
	local chargePercentage = (math.min(self.chargeTimer or 0,self.maxCharge or 1)/(self.maxCharge or 1))
		params.power = params.power * (self.chargePowerMultiplier * chargePercentage + (self.basePowerMultiplier or 0))
	end
	params.powerMultiplier = activeItem.ownerPowerMultiplier()

	local spreadAngle = util.toRadians(self.chargeLevel.spreadAngle or 0)
	local totalSpread = spreadAngle * (projectileCount - 1)
	local currentAngle = totalSpread * -0.5
	for i = 1, projectileCount do
		if params.timeToLive then
			params.timeToLive = util.randomInRange(params.timeToLive)
		end

		world.spawnProjectile(
				self.chargeLevel.projectileType,
				self:firePosition(),
				activeItem.ownerEntityId(),
				self:aimVector(currentAngle, self.chargeLevel.inaccuracy or 0),
				false,
				params
			)

		currentAngle = currentAngle + spreadAngle
	end
end

function TexasRedPrimary:windup()
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

function TexasRedPrimary:wait()
	local stance = self.stances["wait"..(self.comboStep - 1)]

	self.weapon:setStance(stance)

	util.wait(stance.duration, function()
		if self:shouldActivate() then
			self:setState(self.windup)
			return
		end
	end)

	self.cooldownTimer = math.max(0, self.cooldowns[self.comboStep - 1] - stance.duration)
	self.comboStep = 1
end

function TexasRedPrimary:preslash()
	local stance = self.stances["preslash"..self.comboStep]

	self.weapon:setStance(stance)
	self.weapon:updateAim()

	util.wait(stance.duration)

	self:setState(self.fire)
end

function TexasRedPrimary:fire()
	local stance = self.stances["fire"..self.comboStep]

	self.weapon:setStance(stance)
	self.weapon:updateAim()

	local animStateKey = self.animKeyPrefix .. (self.comboStep > 1 and "fire"..self.comboStep or "fire")
	animator.setAnimationState("swoosh", animStateKey)
	animator.playSound(animStateKey)

	local swooshKey = self.animKeyPrefix .. (self.elementalType or self.weapon.elementalType) .. "swoosh"
	animator.setParticleEmitterOffsetRegion(swooshKey, self.swooshOffsetRegions[self.comboStep])
	animator.burstParticleEmitter(swooshKey)

	util.wait(stance.duration, function()
		local damageArea = partDamageArea("swoosh")
		self.weapon:setDamage(self.stepDamageConfig[self.comboStep], damageArea)
	end)

	if self.comboStep < self.comboSteps then
		self.comboStep = self.comboStep + 1
		self:setState(self.wait)
	else
		self.cooldownTimer = self.cooldowns[self.comboStep]
		self.comboStep = 1
	end
end

function TexasRedPrimary:computeDamageAndCooldowns()
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

function TexasRedPrimary:flipWindup()
	self.weapon:setStance(self.stances.flipWindup)

	status.setPersistentEffects("weaponMovementAbility", {{stat = "activeMovementAbilities", amount = 1}})

	util.wait(self.stances.flipWindup.duration, function(dt)
			mcontroller.controlCrouch()
		end)

	self:setState(self.flip)
end

function TexasRedPrimary:flip()
	self.weapon:setStance(self.stances.flip)
	self.weapon:updateAim()

	animator.setAnimationState("swoosh", "flip")
	animator.playSound(self.fireSound or "flipSlash")

	self.flipTime = self.rotations * self.rotationTime
	self.flipTimer = 0

	self.jumpTimer = self.jumpDuration

	while self.flipTimer < self.flipTime do
		self.flipTimer = self.flipTimer + self.dt

		mcontroller.controlParameters(self.flipMovementParameters)

		if self.jumpTimer > 0 then
			self.jumpTimer = self.jumpTimer - self.dt
			mcontroller.setVelocity({self.jumpVelocity[1] * self.weapon.aimDirection, self.jumpVelocity[2]})
		end

		local damageArea = partDamageArea("swoosh")
		self.weapon:setDamage(self.flipDamageConfig, damageArea, self.fireTime)

		mcontroller.setRotation(-math.pi * 2 * self.weapon.aimDirection * (self.flipTimer / self.rotationTime))

		coroutine.yield()
	end

	status.clearPersistentEffects("weaponMovementAbility")

	animator.setAnimationState("swoosh", "idle")
	mcontroller.setRotation(0)
	self.cooldownTimer = self.flipCooldownTime
end

function TexasRedPrimary:readyFlash()
	animator.setGlobalTag("bladeDirectives", self.flashDirectives)
	self.flashTimer = self.flashTime
end

function TexasRedPrimary:uninit()
	self.weapon:setDamage()
	status.clearPersistentEffects("weaponMovementAbility")
	animator.setAnimationState("swoosh", "idle")
	mcontroller.setRotation(0)
end