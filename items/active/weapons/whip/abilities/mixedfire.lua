require "/scripts/util.lua"
require "/items/active/weapons/weapon.lua"
require "/items/active/weapons/ranged/gunfire.lua"

MixedFire = WeaponAbility:new()

for k, v in pairs(GunFire) do
  MixedFire[k] = v
end

function MixedFire:init()
  self.weapon:setStance(self.stances.idle)

  self.cooldownTimer = self.fireTime

  self.weapon.onLeaveAbility = function()
    self.weapon:setStance(self.stances.idle)
  end
end

function MixedFire:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if animator.animationState("firing") ~= "fire" then
    animator.setLightActive("muzzleFlash", false)
  end

  --a copy of vanilla weapon.lua fsm, for local use
  if self.currentState then
    if coroutine.status(self.stateThread) ~= "dead" then
      local status, result = coroutine.resume(self.stateThread)
      if not status then error(result) end
    else
      self.currentAbility:uninit()
      self.currentAbility = nil
      self.currentState = nil
      self.stateThread = nil
      if self.weapon.onLeaveAbility and not self.weapon.currentAbility then
        self.weapon.onLeaveAbility()
      end
    end
  end

  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and not self.currentState
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

function MixedFire:setState(state, ...)
  self:setAbilityState(self, state, ...)
end

function MixedFire:setAbilityState(ability, state, ...)
  self.currentAbility = ability
  self.currentState = state
  self.stateThread = coroutine.create(state)
  local status, result = coroutine.resume(self.stateThread, ability, ...)
  if not status then
    error(result)
  end
end
