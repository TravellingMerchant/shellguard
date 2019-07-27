require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"
require "/items/active/weapons/ranged/gunfire.lua"

sgspiderburst = GunFire:new()

function sgspiderburst:new(abilityConfig)
  return GunFire.new(self, abilityConfig)
end

function sgspiderburst:init()
  self.cooldownTimer = self.fireTime
end

function sgspiderburst:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if self.fireMode == "alt"
    and not self.weapon.currentAbility
    and self.cooldownTimer == 0
    and not status.resourceLocked("energy")
    and not world.lineTileCollision(mcontroller.position(), self:firePosition()) then
    
    self:setState(self.burst)
  end
end

function sgspiderburst:fireProjectile(...)
  local projectileId = GunFire.fireProjectile(self, ...)
  world.callScriptedEntity(projectileId, "setApproach", self:aimVector(0))
end

function sgspiderburst:muzzleFlash()
  animator.burstParticleEmitter("altMuzzleFlash", true)
  animator.playSound("altFire")
end
