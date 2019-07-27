require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

sgpushshot = WeaponAbility:new()

function sgpushshot:init()
  self:reset()

  self.cooldownTimer = 0
end

function sgpushshot:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - dt)

  if self.weapon.currentAbility == nil
    and self.fireMode == "alt"
    and self.cooldownTimer == 0
    and not world.lineTileCollision(mcontroller.position(), self:firePosition())
    and status.overConsumeResource("energy", self.energyUsage) then

    self:setState(self.fire)
  end
end

function sgpushshot:fire()
  self.weapon:setStance(self.stances.fire)
  self.weapon:updateAim()

  animator.setAnimationState("sgpushshotFire", "fire")
  animator.burstParticleEmitter("sgpushshotSmoke")
  animator.playSound("sgpushshot")

  util.wait(self.stances.fire.duration, function()
    local damageArea = partDamageArea("sgpushshotExplosion")
    self.weapon:setDamage(self.damageConfig, damageArea)
  end)

  self.cooldownTimer = self.cooldownTime
end

function sgpushshot:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset))
end

function sgpushshot:reset()
  animator.setAnimationState("sgpushshotFire", "idle")
end

function sgpushshot:uninit()
  self:reset()
end
