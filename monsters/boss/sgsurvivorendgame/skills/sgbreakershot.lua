require "/scripts/util.lua"

sgbreakershot = {}

--------------------------------------------------------------------------------
function sgbreakershot.enter()
  if not hasTarget() then return nil end

  return {
    windupTimer = config.getParameter("sgbreakershot.windupTime"),
    winddownTimer = config.getParameter("sgbreakershot.winddownTime"),
    distanceRange = config.getParameter("sgbreakershot.distanceRange"),
    skillTimer = 0,
    skillDuration = config.getParameter("sgbreakershot.skillDuration"),
    fireTimer = 0,
    fireInterval = config.getParameter("sgbreakershot.fireInterval"),
    lastFacing = mcontroller.facingDirection(),
    facingTimer = 0,
	inaccuracy = config.getParameter("sgbreakershot.inaccuracy")
  }
end

--------------------------------------------------------------------------------
function sgbreakershot.enteringState(stateData)
  animator.setAnimationState("movement", "idle")

  monster.setActiveSkillName("sgbreakershot")
end

--------------------------------------------------------------------------------
function sgbreakershot.update(dt, stateData)
  if not hasTarget() then return true end

  local toTarget = world.distance(self.targetPosition, mcontroller.position())
  local targetDir = util.toDirection(toTarget[1])

  if stateData.windupTimer > 0 then
    if stateData.windupTimer == config.getParameter("sgbreakershot.windupTime") then
      animator.setAnimationState("weapon", "windup")
    end
    stateData.windupTimer = stateData.windupTimer - dt
    return false
  end

  mcontroller.controlParameters({
    walkSpeed = config.getParameter("sgbreakershot.walkSpeed") or config.getParameter("sgbreakershot.moveSpeed"),
    runSpeed = config.getParameter("sgbreakershot.runSpeed") or config.getParameter("sgbreakershot.moveSpeed")
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
    if stateData.winddownTimer > 0 then
      if stateData.winddownTimer == config.getParameter("sgbreakershot.winddownTime") then
        animator.setAnimationState("weapon", "winddown")
      end
      stateData.winddownTimer = stateData.winddownTimer - dt
      return false
    end

    return true
  end

  sgbreakershot.controlFace(dt, stateData, targetDir)

  stateData.skillTimer = stateData.skillTimer + dt

  stateData.fireTimer = stateData.fireTimer - dt
  if stateData.fireTimer <= 0 then
    local aimVector = vec2.sub(self.targetPosition, mcontroller.position())
    sgbreakershot.fire(aimVector)

    stateData.fireTimer = stateData.fireTimer + stateData.fireInterval
  end

  stateData.lastFacing = mcontroller.facingDirection()

  return false
end

function sgbreakershot.controlFace(dt, stateData, direction)
  if direction ~= mcontroller.facingDirection() and stateData.facingTimer > 0 then
    stateData.facingTimer = stateData.facingTimer - dt
  else
    stateData.facingTimer = config.getParameter("sgbreakershot.changeFacingTime")
    mcontroller.controlFace(direction)
  end
end

function sgbreakershot.fire(aimVector)
  local projectileType = config.getParameter("sgbreakershot.projectile.type")
  local projectileCount = config.getParameter("sgbreakershot.projectileCount")
  local projectileConfig = config.getParameter("sgbreakershot.projectile.config")
  local sourcePosition = config.getParameter("projectileSourcePosition")
  local sourceOffset = config.getParameter("projectileSourceOffset")
    
  if type(projectileCount) == "table" then
    projectileCount = projectileCount[util.randomInRange(projectileCount)]
  end
  
  if type(projectileType) == "table" then
    projectileType = projectileType[math.random(#projectileType)]
  end

  if projectileConfig.power then
    projectileConfig.power = projectileConfig.power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  end

  local animationAngle = math.atan(-aimVector[2], math.abs(aimVector[1])) - math.pi/2 --Because flipped sprite
  animator.rotateGroup("projectileAim", animationAngle)

  local currentRotationAngle = animator.currentRotationAngle("projectileAim")
  currentRotationAngle = math.atan(-math.sin(currentRotationAngle), math.cos(currentRotationAngle)) --Because flipped sprite

  sourceOffset = vec2.rotate(sourceOffset, currentRotationAngle)
  sourcePosition = vec2.add(sourcePosition, sourceOffset)

  animator.playSound("fireSound2")
  
  for i = 1, (projectileCount or stateData.projectileCount) do
    world.spawnProjectile(
        projectileType,
        mcontroller.position(),	--monster.toAbsolutePosition(sourcePosition),
        entity.id(),
        aimVector,
        true,
        projectileConfig
      )
  end
end

function sgbreakershot.leavingState(stateData)
  animator.setAnimationState("weapon", "winddown")
  
  monster.setActiveSkillName("")
end
