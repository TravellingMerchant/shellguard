require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.homingDistance = config.getParameter("homingDistance")
  self.hitProjectile = config.getParameter("hitProjectile")
  self.hitProjectileParams = config.getParameter("hitProjectileParams", {})
  self.hitProjectileParams.power = projectile.power() * config.getParameter("hitProjectileDamageMult", 1) * config.getParameter("scriptDelta", 1) / 60 
  self.hitProjectileParams.powerMultiplier = projectile.powerMultiplier()
  self.inaccuracy = config.getParameter("hitProjectileInaccuracy", 0.3)
  self.sourceEntity = projectile.sourceEntity()
  self.queryParameters = {
    withoutEntityId = self.sourceEntity,
    includedTypes = {"npc", "monster", "player"},
    order = "nearest"
  }
end

function update(dt)
  local pos = mcontroller.position()
  local candidates = world.entityQuery(pos, self.homingDistance, self.queryParameters)
  
  world.debugPoly({
    vec2.add(pos, {0,-self.homingDistance}),
    vec2.add(pos, {self.homingDistance,0}),
    vec2.add(pos, {0,self.homingDistance}),
    vec2.add(pos, {-self.homingDistance,0})
  }, {255,0,0})

  candidates = util.filter(candidates, function(entityId)
    if not world.entityCanDamage(self.sourceEntity, entityId) then
      return false
    end

    if (world.entityDamageTeam(entityId).type == "passive") and (world.entityTypeName(entityId) ~= "punchy") then
      return false
    end

    return true
  end)
  
  if #candidates == 0 then return end
  
  for i, candidate in ipairs(candidates) do
    local canPos = world.entityPosition(candidate)
    if not world.lineTileCollision(pos, canPos) then
      local toTarget = world.distance(canPos, pos)
      
      world.spawnProjectile(
        self.hitProjectile,
        pos,
        self.sourceEntity,
        aimVector(toTarget, self.inaccuracy),
        true,
        self.hitProjectileParams
      )
    end
  end
end



function aimVector(vector, inaccuracy)
  return vec2.rotate(vector, sb.nrand(inaccuracy, 0))
end

