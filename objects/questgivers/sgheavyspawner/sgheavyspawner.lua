require "/scripts/util.lua"

function init()
  storage.mercenaries = storage.mercenaries or {}
  self.spawner = config.getParameter("spawner")
end

function update(dt)
  storage.mercenaries = util.filter(storage.mercenaries, function (uniqueId)
      return world.findUniqueEntity(uniqueId):result()
    end)

  while #storage.mercenaries < 5 do
    local uniqueId = sb.makeUuid()
    local parameters = {
        scriptConfig = {
            uniqueId = uniqueId
          }
      }
    local entityId = world.spawnNpc(entity.position(), self.spawner.species, self.spawner.typeName, world.threatLevel(), nil, parameters)
    world.callScriptedEntity(entityId, "status.addEphemeralEffect", "beamin")
    table.insert(storage.mercenaries, uniqueId)
  end
end
