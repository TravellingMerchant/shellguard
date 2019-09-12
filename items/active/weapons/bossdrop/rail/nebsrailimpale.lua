require "/scripts/util.lua"
require "/scripts/status.lua"
require "/scripts/poly.lua"
require "/items/active/weapons/weapon.lua"

-- Melee primary ability
RailAndImpale = WeaponAbility:new()

function RailAndImpale:init()
  self.damageConfig.baseDamage = self.baseDamage or self.baseDps * self.fireTime
  self.hasHit = false
  self.queryDamageSince = 0

  self.energyUsage = self.energyUsage or 0

  self.cooldownTimer = self:cooldownTime()
end

-- Ticks on every update regardless if this is the active ability
function RailAndImpale:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.damageListener then
    self.damageListener:update()
  end

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == "alt" and self.cooldownTimer == 0 and (self.energyUsage == 0 or not status.resourceLocked("energy")) then
    self:setState(self.windup)
  end
end

-- State: windup
function RailAndImpale:windup()
  self.weapon:setStance(self.stances.windup)

  if self.stances.windup.hold then
    while self.fireMode == "alt" do
      coroutine.yield()
    end
  else
    util.wait(self.stances.windup.duration / 3)
  end

  animator.playSound(self.windupSound or "altWindup")
  util.wait(self.stances.windup.duration / 1.5)
  animator.setAnimationState("weapon", "thrust")

  if self.energyUsage then
    status.overConsumeResource("energy", self.energyUsage)
  end

  if self.stances.preslash then
    self:setState(self.preslash)
  else
    self:setState(self.fire)
  end
end

-- State: preslash
-- brief frame in between windup and fire
function RailAndImpale:preslash()
  self.weapon:setStance(self.stances.preslash)
  self.weapon:updateAim()

  util.wait(self.stances.preslash.duration)

  self:setState(self.fire)
end

-- State: fire
function RailAndImpale:fire()
  self.weapon:setStance(self.stances.fire)
  self.queryDamageSince = 0
  self.weapon:updateAim()

  animator.setAnimationState("altSwoosh", "fire")
  animator.playSound(self.fireSound or "altFire")
  animator.burstParticleEmitter("altSwoosh")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("altSwoosh")
    self.weapon:setDamage(self.damageConfig, damageArea, self.fireTime)

    --Set up a damagelistener for outgoing damage
    local damageNotifications, nextStep = status.inflictedDamageSince(self.queryDamageSince)
    	self.queryDamageSince = nextStep
    	for _, notification in ipairs(damageNotifications) do
  	  if notification.healthLost > 0 and notification.sourceEntityId ~= notification.targetEntityId and world.entityType(notification.targetEntityId) ~= "object" and notification.damageSourceKind == self.damageConfig.damageSourceKind and not self.hasHit then
        --if notification.sourceEntityId ~= -65536 and notification.healthLost > 0 and status.overConsumeResource("energy", self:energyPerShot()) then
            activeItem.emote("annoyed")
          	self.hasHit = true
            self:fireProjectile()
            self:muzzleFlash()
            self.queryDamageSince = 0
            sb.logInfo("spank")
            animator.setAnimationState("weapon", "idle")
        	return true
        end
      end
  end)

  if not self.hasHit then
    animator.setAnimationState("weapon", "retract")
    animator.playSound(self.retractSound or "altRetract")
  else
    animator.setAnimationState("weapon", "idle")
  end

  self.weapon:setStance(self.stances.idle)
  util.wait(self.fireTime - self.stances.windup.duration - self.stances.fire.duration)

  self.cooldownTimer = self:cooldownTime()
  self.hasHit = false
end

function RailAndImpale:fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount)
  local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
  params.power = self:damagePerShot()
  params.powerMultiplier = activeItem.ownerPowerMultiplier()
  params.speed = util.randomInRange(params.speed)

  if not projectileType then
    projectileType = self.projectileType
  end
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  local projectileId = 0
  for i = 1, (projectileCount or self.projectileCount) do
    if params.timeToLive then
      params.timeToLive = util.randomInRange(params.timeToLive)
    end

    projectileId = world.spawnProjectile(
        projectileType,
        firePosition or self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(inaccuracy or self.inaccuracy),
        false,
        params
      )
  end
  return projectileId
end

function RailAndImpale:muzzleFlash()
  animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
  animator.setAnimationState("firing", "fire")
  animator.burstParticleEmitter("muzzleFlash")
  animator.playSound("fire")

  animator.setLightActive("muzzleFlash", true)
end

function RailAndImpale:energyPerShot()
  return self.energyUsage * self.fireTime * (self.energyUsageMultiplier or 1.0)
end

function RailAndImpale:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function RailAndImpale:aimVector(inaccuracy)
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(inaccuracy, 0))
  aimVector[1] = aimVector[1] * mcontroller.facingDirection()
  return aimVector
end

function RailAndImpale:damagePerShot()
  return (self.baseDamage or (self.baseDps * self.fireTime)) * (self.baseDamageMultiplier or 1.0) * config.getParameter("damageLevelMultiplier") / self.projectileCount
end

function RailAndImpale:cooldownTime()
  local cooldownMultiplier = 1.0
  if self.hasHit then
    cooldownMultiplier = 1.75
  end
  return (self.fireTime - self.stances.windup.duration - self.stances.fire.duration) * cooldownMultiplier
end

function RailAndImpale:uninit()
  self.weapon:setDamage()
  self.hasHit = false
end
