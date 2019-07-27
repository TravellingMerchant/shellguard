require "/objects/spawner/colonydeed/timer.lua"
require "/scripts/util.lua"

function init()
  self = config.getParameter("spawner")
  if not self then
    sb.logInfo("Monster spawner at %s is missing configuration! Prepare for some serious Lua errors!", object.position())
    return
  end

  object.setInteractive(false)
  self.position = object.toAbsolutePosition(self.position)
  self.firstUpdate = true
  
  self.spawnTimer = Timer:new("spawnTimer", {
      delay = self.delay or 0,
      completeCallback = delayedSpawn,
      loop = false
    })
end

function finishInit()
  local uniqueId = entity.uniqueId()
  if not uniqueId then
    uniqueId = sb.makeUuid()
    world.setUniqueId(entity.id(), uniqueId)
  end
  self.monsterParams.tetherUniqueId = uniqueId
end

function onInteraction(args)
  return "None"
end

function update(dt)
  
  if self.firstUpdate then
    self.firstUpdate = false
    finishInit()
  elseif object.getInputNodeLevel(0) then
	if not storage.monsterUniqueId or world.loadUniqueEntity(storage.monsterUniqueId) == 0 then
	  if not self.spawnTimer:active() then
		animator.setAnimationState("spawnerState", "open")
	    self.spawnTimer:start()
	  else
	    self.spawnTimer:update(dt)
	  end
	end
  end
end

function delayedSpawn()
  local monsterId = spawn()
  if monsterId then
	local uniqueId = sb.makeUuid()
	world.setUniqueId(monsterId, uniqueId)
	storage.monsterUniqueId = uniqueId
  end
end

function die()
  if storage.monsterUniqueId and world.loadUniqueEntity(storage.monsterUniqueId) ~= 0 then
    world.callScriptedEntity(world.loadUniqueEntity(storage.monsterUniqueId), "status.setResource", "health", 0)
  end
end

function spawn()
  local attempts = 10
  while attempts > 0 do
    local spawnPosition = {}
    for i,val in ipairs(self.positionVariance) do
      if val == 0 then
        spawnPosition[i] = self.position[i]
      else
        spawnPosition[i] = self.position[i] + math.random(val) - (val / 2)
      end
    end

    if not self.outOfSight or not world.isVisibleToPlayer({spawnPosition[1] - 3, spawnPosition[2] - 3, spawnPosition[1] + 3, spawnPosition[2] + 3}) then
      local monsterType = util.randomFromList(self.monsterTypes)
      self.monsterParams.level = self.monsterLevel and util.randomInRange(self.monsterLevel) or world.threatLevel()

      local monsterId = world.spawnMonster(monsterType, spawnPosition, self.monsterParams or {})
      if monsterId ~= 0 then
        return monsterId
      end
    end

    attempts = attempts - 1
  end
end
