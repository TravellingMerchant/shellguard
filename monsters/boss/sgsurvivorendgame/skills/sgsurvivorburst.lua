sgsurvivorburst = {}

--------------------------------------------------------------------------------
function sgsurvivorburst.enter()
  if not hasTarget() then return nil end

  return {
    windupTimer = config.getParameter("sgsurvivorburst.windupTime"),
    winddownTimer = config.getParameter("sgsurvivorburst.winddownTime"),
    distanceRange = config.getParameter("sgsurvivorburst.distanceRange"),
    skillTimer = 0,
    skillDuration = config.getParameter("sgsurvivorburst.skillDuration"),
    angleCycle = config.getParameter("sgsurvivorburst.angleCycle"),
    fireTimer = 0,
    fireInterval = config.getParameter("sgsurvivorburst.fireInterval"),
    fireAngle = 0,
    maxFireAngle = config.getParameter("sgsurvivorburst.maxFireAngle"),
    lastFacing = mcontroller.facingDirection(),
    facingTimer = 0
  }
end

--------------------------------------------------------------------------------
function sgsurvivorburst.enteringState(stateData)
  animator.setAnimationState("movement", "idle")

  monster.setActiveSkillName("sgsurvivorburst")
end

--------------------------------------------------------------------------------
function sgsurvivorburst.update(dt, stateData)
  if not hasTarget() then return true end

  local toTarget = world.distance(self.targetPosition, mcontroller.position())
  local targetDir = util.toDirection(toTarget[1])

  if stateData.windupTimer > 0 then
    if stateData.windupTimer == config.getParameter("sgsurvivorburst.windupTime") then
      animator.setAnimationState("flamethrower", "windup")
    end
    stateData.windupTimer = stateData.windupTimer - dt
    return false
  end

  mcontroller.controlParameters({
    walkSpeed = config.getParameter("sgsurvivorburst.moveSpeed"),
    runSpeed = config.getParameter("sgsurvivorburst.moveSpeed")  
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
      if stateData.winddownTimer == config.getParameter("sgsurvivorburst.winddownTime") then
        animator.setAnimationState("flamethrower", "winddown")
      end
      stateData.winddownTimer = stateData.winddownTimer - dt
      return false
    end

    return true
  end

  animator.setAnimationState("flameSound", "on")
  sgsurvivorburst.controlFace(dt, stateData, targetDir)

  stateData.skillTimer = stateData.skillTimer + dt

  stateData.fireTimer = stateData.fireTimer - dt
  if stateData.fireTimer <= 0 then
    local aimVector = vec2.sub(self.targetPosition, mcontroller.position())
    sgsurvivorburst.fire(aimVector)

    stateData.fireTimer = stateData.fireTimer + stateData.fireInterval
  end

  stateData.lastFacing = mcontroller.facingDirection()

  return false
end

function sgsurvivorburst.controlFace(dt, stateData, direction)
  if direction ~= mcontroller.facingDirection() and stateData.facingTimer > 0 then
    stateData.facingTimer = stateData.facingTimer - dt
  else
    stateData.facingTimer = config.getParameter("sgsurvivorburst.changeFacingTime")
    mcontroller.controlFace(direction)
  end
end

function sgsurvivorburst.fire(aimVector)
  local projectileType = config.getParameter("sgsurvivorburst.projectile.type")
  local projectileConfig = config.getParameter("sgsurvivorburst.projectile.config")
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

function sgsurvivorburst.leavingState(stateData)
  animator.setAnimationState("flameSound", "off")
  animator.setAnimationState("flamethrower", "winddown")
  
  monster.setActiveSkillName("")
end
