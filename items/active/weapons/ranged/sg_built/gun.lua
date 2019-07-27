require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/items/active/weapons/weapon.lua"

function init()
  activeItem.setCursor("/cursors/reticle0.cursor")
  animator.setGlobalTag("paletteSwaps", config.getParameter("paletteSwaps", ""))

  self.weapon = Weapon:new()

  self.weapon:addTransformationGroup("weapon", {0,0}, 0)
  self.weapon:addTransformationGroup("muzzle", self.weapon.muzzleOffset, 0)

  self.primaryAbility = getPrimaryAbility()
  self.weapon:addAbility(self.primaryAbility)

  local secondaryAbility = getAltAbility(self.weapon.elementalType)
  if secondaryAbility then
    self.weapon:addAbility(secondaryAbility)
  end

  self.weapon:init()
end

function update(dt, fireMode, shiftHeld)
  self.weapon:update(dt, fireMode, shiftHeld)
  
  world.debugPoint(vec2.add(mcontroller.position(), activeItem.handPosition(self.weapon.muzzleOffset)),"orange")
  
  for k, v in pairs(config.getParameter("build")) do
    world.debugPoint(vec2.add(mcontroller.position(), activeItem.handPosition(animator.partPoint(k, "debugOffset"))),hashColor(k))
  end
end

function uninit()
  self.weapon:uninit()
end

function hashColor(text)
  return "#" .. string.sub(string.format("%X", util.hashString(text)), 1, 6)
end
