require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"

sgrocketburst = GunFire:new()

function sgrocketburst:new(abilityConfig)
  local primary = config.getParameter("primaryAbility")
  return GunFire.new(self, sb.jsonMerge(primary, abilityConfig))
end

function sgrocketburst:init()
  self.cooldownTimer = self.fireTime
end

function sgrocketburst:update(dt, fireMode, shiftHeld)
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

function sgrocketburst:fireProjectile(...)
  local projectileId = GunFire.fireProjectile(self, ...)
  world.callScriptedEntity(projectileId, "setApproach", self:aimVector(0))
end

function sgrocketburst:muzzleFlash()
  animator.burstParticleEmitter("altMuzzleFlash", true)
  animator.playSound("altFire")
end
