require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/status.lua"
require "/items/active/weapons/whip/sgwhipcontrolledweapon.lua"

function init()
  activeItem.setCursor("/cursors/reticle0.cursor")

  self.weapon = ControlledWeapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, 0)
  self.weapon:addTransformationGroup("muzzle", self.weapon.muzzleOffset or {0, 0}, math.pi/2)

  self.primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(self.primaryAbility)

  self.altAbility = getAltAbility()
  if self.altAbility then
    self.weapon:addAbility(self.altAbility)
  end

  self.weapon:init()
end

function update(dt, fireMode, shiftHeld, moves)
  self.weapon:update(dt, fireMode, shiftHeld, moves)
end

function uninit()
  self.weapon:uninit()
end
