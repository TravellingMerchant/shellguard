sgarenabossrocket = {}

--------------------------------------------------------------------------------
function sgarenabossrocket.enter()
  if not hasTarget() then return nil end

  return {
    windupTimer = config.getParameter("sgarenabossrocket.windupTime"),
    winddownTimer = config.getParameter("sgarenabossrocket.winddownTime"),
    distanceRange = config.getParameter("sgarenabossrocket.distanceRange"),
    skillTimer = 0,
    skillDuration = config.getParameter("sgarenabossrocket.skillDuration"),
    angleCycle = config.getParameter("sgarenabossrocket.angleCycle"),
    fireTimer = 0,
    fireInterval = config.getParameter("sgarenabossrocket.fireInterval"),
    fireAngle = 0,
    maxFireAngle = config.getParameter("sgarenabossrocket.maxFireAngle"),
    lastFacing = mcontroller.facingDirection(),
    facingTimer = 0
  }
end

--------------------------------------------------------------------------------
function sgarenabossrocket.enteringState(stateData)
  animator.setAnimationState("movement", "idle")

  monster.setActiveSkillName("sgarenabossrocket")
end

--------------------------------------------------------------------------------
function sgarenabossrocket.update(dt, stateData)
  if not hasTarget() then return true end

  local toTarget = world.distance(self.targetPosition, mcontroller.position())
  local targetDir = util.toDirection(toTarget[1])

  if stateData.windupTimer > 0 then
    if stateData.windupTimer == config.getParameter("sgarenabossrocket.windupTime") then
      animator.setAnimationState("flamethrower", "windup")
    end
    stateData.windupTimer = stateData.windupTimer - dt
    return false
  end

  mcontroller.controlParameters({
    walkSpeed = config.getParameter("sgarenabossrocket.moveSpeed"),
    runSpeed = config.getParameter("sgarenabossrocket.moveSpeed")  
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
      if stateData.winddownTimer == config.getParameter("sgarenabossrocket.winddownTime") then
        animator.setAnimationState("flamethrower", "winddown")
      end
      stateData.winddownTimer = stateData.winddownTimer - dt
      return false
    end

    return true
  end

  animator.setAnimationState("flameSound", "on")
  sgarenabossrocket.controlFace(dt, stateData, targetDir)

  stateData.skillTimer = stateData.skillTimer + dt
  local aimAngle = math.sin((stateData.skillTimer / stateData.angleCycle) * math.pi * 2) * stateData.maxFireAngle

  stateData.fireTimer = stateData.fireTimer - dt
  if stateData.fireTimer <= 0 then
    local aimVector = vec2.rotate({mcontroller.facingDirection(), 0}, aimAngle)
    sgarenabossrocket.fire(aimVector)

    stateData.fireTimer = stateData.fireTimer + stateData.fireInterval
  end

  stateData.lastFacing = mcontroller.facingDirection()

  return false
end

function sgarenabossrocket.controlFace(dt, stateData, direction)
  if direction ~= mcontroller.facingDirection() and stateData.facingTimer > 0 then
    stateData.facingTimer = stateData.facingTimer - dt
  else
    stateData.facingTimer = config.getParameter("sgarenabossrocket.changeFacingTime")
    mcontroller.controlFace(direction)
  end
end

function sgarenabossrocket.fire(aimVector)
  local projectileType = config.getParameter("sgarenabossrocket.projectile.type")
  local projectileConfig = config.getParameter("sgarenabossrocket.projectile.config")
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

function sgarenabossrocket.leavingState(stateData)
  animator.setAnimationState("flameSound", "off")
  animator.setAnimationState("flamethrower", "winddown")
  
  monster.setActiveSkillName("")
end
