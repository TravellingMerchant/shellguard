--------------------------------------------------------------------------------
sgufoMoveFireAttackrocket = {}

function sgufoMoveFireAttackrocket.enter()
  if not hasTarget() then return nil end

  rangedAttack.setConfig(config.getParameter("sgufoMoveFireAttackrocket.projectile.type"), config.getParameter("sgufoMoveFireAttackrocket.projectile.config"), config.getParameter("sgufoMoveFireAttackrocket.fireInterval"))

  return {
    timer = 0,
    bobTime = config.getParameter("sgufoMoveFireAttackrocket.bobTime"),
    bobHeight = config.getParameter("sgufoMoveFireAttackrocket.bobHeight"),
    skillTime = config.getParameter("sgufoMoveFireAttackrocket.skillTime"),
    direction = util.randomDirection(),
    basePosition = self.spawnPosition,
    cruiseDistance = config.getParameter("cruiseDistance")
  }
end

function sgufoMoveFireAttackrocket.enteringState(stateData)
  monster.setActiveSkillName(nil)
end

function sgufoMoveFireAttackrocket.update(dt, stateData)
  mcontroller.controlFace(1)
  if not hasTarget() then return true end

  local projectileOffset = config.getParameter("sgufoMoveFireAttackrocket.projectileOffset")

  local toTarget = vec2.norm(world.distance(self.targetPosition, monster.toAbsolutePosition(projectileOffset)))
  rangedAttack.aim(projectileOffset, toTarget)
  rangedAttack.fireContinuous()

  local position = mcontroller.position()

  local toTarget = world.distance(self.targetPosition, position)
  if toTarget[1] < -stateData.cruiseDistance or checkWalls(1) then
    stateData.direction = -1
  elseif toTarget[1] > stateData.cruiseDistance or checkWalls(-1) then
    stateData.direction = 1
  end

  stateData.timer = stateData.timer + dt
  local angle = 2.0 * math.pi * stateData.timer / stateData.bobTime
  local targetPosition = {
    position[1] + stateData.direction * 5,
    stateData.basePosition[2] + stateData.bobHeight * math.cos(angle)
  }
  flyTo(targetPosition)

  if stateData.timer > stateData.skillTime then
    return true
  else
    return false
  end
end

function sgufoMoveFireAttackrocket.leavingState(stateData)
end
