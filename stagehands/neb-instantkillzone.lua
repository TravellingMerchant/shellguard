require "/scripts/stagehandutil.lua"

function init()
end

function update(dt)
  --Find all entites in stagehand and kill them
  local livingEntities = broadcastAreaQuery({includedTypes = {"npc", "monster"}})
  for _, entity in pairs(livingEntities) do
	world.sendEntityMessage(entity, "applyStatusEffect", "monsterdespawn")
	world.sendEntityMessage(entity, "despawn")
	world.sendEntityMessage(entity, "applyStatusEffect", "beamoutanddie")
  end
end
