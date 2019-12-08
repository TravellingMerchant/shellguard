require "/scripts/util.lua"
require "/scripts/rect.lua"

local storage_init = init
local storage_update = update
function init()
  storage_init()
  
  local uniqueId = config.getParameter("uniqueId")
  if uniqueId then
    monster.setUniqueId(uniqueId)
  end
end

function update(dt)
  storage_update(dt)
  
  if not status.resourcePositive("health") then
    setBattleMusicEnabled(false)
  end
  
  if hasTarget() then
    monster.setDamageBar("Special")
    monster.setAggressive(true)
    setBattleMusicEnabled(true)
    
  elseif self.hadTarget then
    status.setResource("health", status.stat("maxHealth"))
    
    monster.setDamageBar("None")
    monster.setAggressive(false)
    setBattleMusicEnabled(false)
  end
  
  self.hadTarget = hasTarget()
end


function hasTarget()
  local target = self.board:getEntity("target")
  if target and target ~= 0 then
    return target
  end
  return false
end

function setBattleMusicEnabled(enabled)
  if self.musicEnabled ~= enabled then
    local musicStagehands = config.getParameter("musicStagehands", {})
    for _,stagehand in pairs(musicStagehands) do
      local entityId = world.loadUniqueEntity(stagehand)

      if entityId and world.entityExists(entityId) then
        world.callScriptedEntity(entityId, "setMusicEnabled", enabled)
        self.musicEnabled = enabled
      end
    end
  end
end