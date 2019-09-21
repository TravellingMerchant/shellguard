sgarenabossPunchAttack = {}

--------------------------------------------------------------------------------
function sgarenabossPunchAttack.enter()
  if not hasTarget() then return nil end

  return {
    distanceRange = config.getParameter("sgarenabossPunchAttack.distanceRange"),
    winddownTimer = config.getParameter("sgarenabossPunchAttack.winddownTime"),
    windupTimer = config.getParameter("sgarenabossPunchAttack.windupTime"),
    punching = false
  }
end

--------------------------------------------------------------------------------
function sgarenabossPunchAttack.enteringState(stateData)
  animator.setAnimationState("movement", "idle")

  monster.setActiveSkillName("sgarenabossPunchAttack")
end

--------------------------------------------------------------------------------
function sgarenabossPunchAttack.update(dt, stateData)
  if not hasTarget() then return true end

  local toTarget = world.distance(self.targetPosition, mcontroller.position())
  local targetDir = util.toDirection(toTarget[1])

  if not stateData.punching then 
    if math.abs(toTarget[1]) > stateData.distanceRange[2] then
      animator.setAnimationState("movement", "move")
      mcontroller.controlMove(util.toDirection(toTarget[1]), true)
    elseif math.abs(toTarget[1]) < stateData.distanceRange[1] then
      mcontroller.controlMove(util.toDirection(-toTarget[1]), true)
      animator.setAnimationState("movement", "move")
      mcontroller.controlFace(targetDir)
    else
      stateData.punching = true
    end
  else
    mcontroller.controlFace(targetDir)
    if stateData.windupTimer > 0 then
      if stateData.windupTimer == config.getParameter("sgarenabossPunchAttack.windupTime") then
      animator.setAnimationState("movement", "punch")
      end
      stateData.windupTimer = stateData.windupTimer - dt
    elseif stateData.winddownTimer > 0 then
      if stateData.winddownTimer == config.getParameter("sgarenabossPunchAttack.winddownTime") then
        sgarenabossPunchAttack.punch(targetDir)
        animator.playSound("punch")
      end
      stateData.winddownTimer = stateData.winddownTimer - dt
    else
      return true
    end
  end


  return false
end

function sgarenabossPunchAttack.punch(direction)
  local projectileType = config.getParameter("sgarenabossPunchAttack.projectile.type")
  local projectileConfig = config.getParameter("sgarenabossPunchAttack.projectile.config")
  local projectileOffset = config.getParameter("sgarenabossPunchAttack.projectile.offset")
  
  if projectileConfig.power then
    projectileConfig.power = projectileConfig.power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  end

  world.spawnProjectile(projectileType, monster.toAbsolutePosition(projectileOffset), entity.id(), {direction, 0}, true, projectileConfig)
end

function sgarenabossPunchAttack.leavingState(stateData)
  monster.setActiveSkillName("")
end
