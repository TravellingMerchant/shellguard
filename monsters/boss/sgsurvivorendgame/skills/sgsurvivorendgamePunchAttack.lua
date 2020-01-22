sgsurvivorendgamePunchAttack = {}

--------------------------------------------------------------------------------
function sgsurvivorendgamePunchAttack.enter()
  if not hasTarget() then return nil end

  return {
    distanceRange = config.getParameter("sgsurvivorendgamePunchAttack.distanceRange"),
    winddownTimer = config.getParameter("sgsurvivorendgamePunchAttack.winddownTime"),
    windupTimer = config.getParameter("sgsurvivorendgamePunchAttack.windupTime"),
    punching = false
  }
end

--------------------------------------------------------------------------------
function sgsurvivorendgamePunchAttack.enteringState(stateData)
  animator.setAnimationState("movement", "idle")

  monster.setActiveSkillName("sgsurvivorendgamePunchAttack")
end

--------------------------------------------------------------------------------
function sgsurvivorendgamePunchAttack.update(dt, stateData)
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
      if stateData.windupTimer == config.getParameter("sgsurvivorendgamePunchAttack.windupTime") then
      animator.setAnimationState("movement", "punch")
      end
      stateData.windupTimer = stateData.windupTimer - dt
    elseif stateData.winddownTimer > 0 then
      if stateData.winddownTimer == config.getParameter("sgsurvivorendgamePunchAttack.winddownTime") then
        sgsurvivorendgamePunchAttack.punch(targetDir)
        animator.playSound("punch")
      end
      stateData.winddownTimer = stateData.winddownTimer - dt
    else
      return true
    end
  end


  return false
end

function sgsurvivorendgamePunchAttack.punch(direction)
  local projectileType = config.getParameter("sgsurvivorendgamePunchAttack.projectile.type")
  local projectileConfig = config.getParameter("sgsurvivorendgamePunchAttack.projectile.config")
  local projectileOffset = config.getParameter("sgsurvivorendgamePunchAttack.projectile.offset")
  
  if projectileConfig.power then
    projectileConfig.power = projectileConfig.power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  end

  world.spawnProjectile(projectileType, monster.toAbsolutePosition(projectileOffset), entity.id(), {direction, 0}, true, projectileConfig)
end

function sgsurvivorendgamePunchAttack.leavingState(stateData)
  monster.setActiveSkillName("")
end
