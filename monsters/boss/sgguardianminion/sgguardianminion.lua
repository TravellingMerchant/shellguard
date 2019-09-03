require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  message.setHandler("despawn", despawn)

  monster.setDeathParticleBurst("deathPoof")
  monster.setDeathSound("deathPuff")

  self.state = FSM:new()

  self.managerUid = config.getParameter("managerUid")
  self.bossId = config.getParameter("bossId")
  self.triggerId = config.getParameter("triggerId")
  message.setHandler("setGroup", function(_,_, entityIds)
    self.group = entityIds
  end)

  self.targetRange = config.getParameter("targetRange", 300)

  message.setHandler("collide", function(_, _, position)
    self.state:set(collideState, position)
  end)

  if config.getParameter("partOfGroup", false) then
    self.state:set(blorbState)
  else
    self.state:set(spawnState)
  end
end

function update(dt)
  if self.bossId and not world.entityExists(self.bossId) then
    self.state:set(despawnState)
    self.bossId = nil
  end

  if status.resourcePositive("stunned") then
    animator.setGlobalTag("hurt", "hurt")
    self.stunned = true
    mcontroller.clearControls()
    if self.damaged then
      self.suppressDamageTimer = config.getParameter("stunDamageSuppression", 0.5)
      monster.setDamageOnTouch(false)
    end
    return
  else
    animator.setGlobalTag("hurt", "")
  end

  self.state:update()
end

function despawn()
  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)
  self.despawn = true
  status.addEphemeralEffect("monsterdespawn")
end

function die()
  if self.triggerId and not self.despawn then
    -- trigger boss event if last one in the group to die
    local group = util.filter(self.group, world.entityExists)
    if #group == 1 then
      world.sendEntityMessage(self.managerUid, "trigger", self.triggerId, mcontroller.position())
    end
  end
end

-- States

function blorbState()
  while self.group == nil do
    status.addEphemeralEffect("invulnerable", 1.0)
    coroutine.yield()
  end
  self.state:set(spawnState)
end

function spawnState()
  animator.setAnimationState("body", "spawn")
  status.addEphemeralEffect("invulnerable", 2)
  monster.setDamageOnTouch(false)

  while animator.animationState("body") == "spawn" do
    coroutine.yield()
  end

  status.removeEphemeralEffect("invulnerable")
  self.state:set(idleState)
end

function idleState()
  animator.resetTransformationGroup("body")
  local players = world.entityQuery(entity.position(), self.targetRange, {includedTypes = {"player"}})
  -- target valid targets in sight
  players = util.filter(players, function(playerId)
      return entity.isValidTarget(playerId) and not world.lineTileCollision(entity.position(), world.entityPosition(playerId))
    end)

  if #players > 0 then
    self.state:set(approachState, util.randomFromList(players))
  else
    self.state:set(despawnState)
  end
end

function approachState(targetId)
  monster.setDamageOnTouch(true)
  while true do
    local targetPosition = world.entityPosition(targetId)
    if not world.entityExists(targetId) or world.lineTileCollision(targetPosition, mcontroller.position()) then
      break
    end
    local toTarget = world.distance(targetPosition, mcontroller.position())
    mcontroller.controlFly(toTarget)

    local vel = mcontroller.velocity()
    local angle = math.atan(vel[2], math.abs(vel[1]))
    animator.resetTransformationGroup("body")
    animator.rotateTransformationGroup("body", angle)

    coroutine.yield()
  end

  self.state:set(idleState)
end

function despawnState()
  monster.setDamageOnTouch(false)

  despawn()
  -- wait to despawn
  while true do coroutine.yield() end
end

function collideState(pos)
  animator.setAnimationState("body", "despawn")
  monster.setDamageOnTouch(false)

  mcontroller.setPosition(pos)
  mcontroller.setVelocity({0, 0})

  monster.setDropPool(nil)
  monster.setDeathParticleBurst(nil)
  monster.setDeathSound(nil)

  util.wait(0.5)

  status.setResource("health", 0)
  self.shouldDie = true
end
