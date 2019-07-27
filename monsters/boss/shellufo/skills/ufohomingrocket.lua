--------------------------------------------------------------------------------
ufohomingrocket = {}

function ufohomingrocket.enter()
  if not hasTarget() then return nil end

  rangedAttack.setConfig(config.getParameter("ufohomingrocket.projectile.type"), config.getParameter("ufohomingrocket.projectile.config"), config.getParameter("ufohomingrocket.fireInterval"))

  return {
    timer = 0,
    bobTime = config.getParameter("ufohomingrocket.bobTime"),
    bobHeight = config.getParameter("ufohomingrocket.bobHeight"),
    skillTime = config.getParameter("ufohomingrocket.skillTime"),
    direction = util.randomDirection(),
    basePosition = self.spawnPosition,
    cruiseDistance = config.getParameter("cruiseDistance")
  }
end

function ufohomingrocket.enteringState(stateData)
  monster.setActiveSkillName(nil)
end

function ufohomingrocket.update(dt, stateData)
  mcontroller.controlFace(1)
  if not hasTarget() then return true end

  local projectileOffset = config.getParameter("ufohomingrocket.projectileOffset")

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

function ufohomingrocket.leavingState(stateData)
end
