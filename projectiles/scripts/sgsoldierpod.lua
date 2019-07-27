require "/scripts/vec2.lua"

function uninit()
  local npcSpecies = config.getParameter("npcSpecies")
  local npcType = config.getParameter("npcType")
  local npcLevel = config.getParameter("npcLevel")
  local npcParameters = config.getParameter("npcParameters", {})
  local npcPoly = config.getParameter("npcParameters", { {-0.75, -2.0}, {-0.35, -2.5}, {0.35, -2.5}, {0.75, -2.0}, {0.75, 0.65}, {0.35, 1.22}, {-0.35, 1.22}, {-0.75, 0.65} })
  local warpPoint = world.resolvePolyCollision(collidePoly, vec2.add(mcontroller.position(), config.getParameter("npcOffset", {0, 0})), config.getParameter("npcOffsetTolerance"))
  if warpPoint then
    world.spawnNpc(warpPoint, npcSpecies, npcType, npcLevel, nil, npcParameters)
  else
    local selfItem = config.getParameter("selfItem", false)
    if selfItem then
      world.spawnItem(selfItem, mcontroller.position())
    end
  end
end