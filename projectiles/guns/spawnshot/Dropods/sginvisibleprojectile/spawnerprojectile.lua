require "/scripts/vec2.lua"
require "/scripts/rect.lua"


function update()
  local visible = world.isVisibleToPlayer(rect.withCenter(entity.position(), {4, 4}))
  local loaded = world.regionActive(rect.withCenter(vec2.add(entity.position(), {0, 4}), {4, 4}))
  if (not visible) or (not loaded) then
    projectile.die()
  end
end