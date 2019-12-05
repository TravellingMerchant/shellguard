sgsurvivorendgameFlamethrowerAttackAim = {}

--------------------------------------------------------------------------------
function sgsurvivorendgameFlamethrowerAttackAim.enter()
  if not hasTarget() then return nil end

  return {
    windupTimer = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.windupTime"),
    winddownTimer = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.winddownTime"),
    distanceRange = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.distanceRange"),
    skillTimer = 0,
    skillDuration = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.skillDuration"),
    angleCycle = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.angleCycle"),
    fireTimer = 0,
    fireInterval = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.fireInterval"),
    fireAngle = 0,
    maxFireAngle = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.maxFireAngle"),
    lastFacing = mcontroller.facingDirection(),
    facingTimer = 0
  }
end

--------------------------------------------------------------------------------
function sgsurvivorendgameFlamethrowerAttackAim.enteringState(stateData)
  animator.setAnimationState("movement", "idle")

  monster.setActiveSkillName("sgsurvivorendgameFlamethrowerAttackAim")
end

--------------------------------------------------------------------------------
function sgsurvivorendgameFlamethrowerAttackAim.update(dt, stateData)
  if not hasTarget() then return true end

  local toTarget = world.distance(self.targetPosition, mcontroller.position())
  local targetDir = util.toDirection(toTarget[1])

  if stateData.windupTimer > 0 then
    if stateData.windupTimer == config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.windupTime") then
      animator.setAnimationState("flamethrower", "windup")
    end
    stateData.windupTimer = stateData.windupTimer - dt
    return false
  end

  mcontroller.controlParameters({
    walkSpeed = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.moveSpeed"),
    runSpeed = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.moveSpeed")  
  })

  if math.abs(toTarget[1]) > stateData.distanceRange[1] + 4 then
    animator.setAnimationState("movement", "move")
    mcontroller.controlMove(util.toDirection(toTarget[1]), true)
  elseif math.abs(toTarget[1]) < stateData.distanceRange[1] then
    mcontroller.controlMove(util.toDirection(-toTarget[1]), false)
    animator.setAnimationState("movement", "move")
  else
    animator.setAnimationState("movement", "idle")
  end

  if stateData.skillTimer > stateData.skillDuration then
    animator.setAnimationState("flameSound", "off")
    if stateData.winddownTimer > 0 then
      if stateData.winddownTimer == config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.winddownTime") then
        animator.setAnimationState("flamethrower", "winddown")
      end
      stateData.winddownTimer = stateData.winddownTimer - dt
      return false
    end

    return true
  end

  animator.setAnimationState("flameSound", "on")
  sgsurvivorendgameFlamethrowerAttackAim.controlFace(dt, stateData, targetDir)

  stateData.skillTimer = stateData.skillTimer + dt

  stateData.fireTimer = stateData.fireTimer - dt
  if stateData.fireTimer <= 0 then
    local aimVector = vec2.sub(self.targetPosition, mcontroller.position())
    sgsurvivorendgameFlamethrowerAttackAim.fire(aimVector)

    stateData.fireTimer = stateData.fireTimer + stateData.fireInterval
  end

  stateData.lastFacing = mcontroller.facingDirection()

  return false
end

function sgsurvivorendgameFlamethrowerAttackAim.controlFace(dt, stateData, direction)
  if direction ~= mcontroller.facingDirection() and stateData.facingTimer > 0 then
    stateData.facingTimer = stateData.facingTimer - dt
  else
    stateData.facingTimer = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.changeFacingTime")
    mcontroller.controlFace(direction)
  end
end

function sgsurvivorendgameFlamethrowerAttackAim.fire(aimVector)
  local projectileType = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.projectile.type")
  local projectileConfig = config.getParameter("sgsurvivorendgameFlamethrowerAttackAim.projectile.config")
  local sourcePosition = config.getParameter("projectileSourcePosition")
  local sourceOffset = config.getParameter("projectileSourceOffset")

  if projectileConfig.power then
    projectileConfig.power = projectileConfig.power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  end

  local animationAngle = math.atan(-aimVector[2], math.abs(aimVector[1])) --Because flipped sprite
  animator.rotateGroup("projectileAim", animationAngle)

  local currentRotationAngle = animator.currentRotationAngle("projectileAim")
  currentRotationAngle = math.atan(-math.sin(currentRotationAngle), math.cos(currentRotationAngle)) --Because flipped sprite

  sourceOffset = vec2.rotate(sourceOffset, currentRotationAngle)
  sourcePosition = vec2.add(sourcePosition, sourceOffset)

  world.spawnProjectile(projectileType, monster.toAbsolutePosition(sourcePosition), entity.id(), aimVector, true, projectileConfig)
end

function sgsurvivorendgameFlamethrowerAttackAim.leavingState(stateData)
  animator.setAnimationState("flameSound", "off")
  animator.setAnimationState("flamethrower", "winddown")
  
  monster.setActiveSkillName("")
end
