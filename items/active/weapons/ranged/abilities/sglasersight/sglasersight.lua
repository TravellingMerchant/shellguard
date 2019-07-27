LaserSight = WeaponAbility:new()

function LaserSight:init()
  self.active = config.getParameter("active", false)
  
  for _, beam in pairs(self.beams) do
    beam.offset = vec2.add(vec2.add(beam.offset, config.getParameter("muzzleOffset")), config.getParameter("beamOffset", {0, 0}))
  end
  
  self:reset()
end

function LaserSight:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)
  if self.fireMode == (self.activatingFireMode or self.abilitySlot)
    and self.lastFireMode ~= (self.activatingFireMode or self.abilitySlot) then
    self.active = not self.active
    activeItem.setScriptedAnimationParameter("beams", self.active and self.beams or {})
  end
  self.lastFireMode = fireMode
end

function LaserSight:reset()
  activeItem.setScriptedAnimationParameter("beams", self.active and self.beams or {})
end

function LaserSight:uninit()
  activeItem.setInstanceValue("active", self.active)
  self:reset()
end
