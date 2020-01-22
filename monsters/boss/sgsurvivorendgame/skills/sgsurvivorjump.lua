sgsurvivorjump = {}

--------------------------------------------------------------------------------
function sgsurvivorjump.initialStateData()
  return {
    riseHeight = config.getParameter("sgsurvivorjump.riseHeight"),
    riseSpeed = config.getParameter("sgsurvivorjump.riseSpeed"),
    firing = false,
    skillTimer = 0,
    skillDuration = config.getParameter("sgsurvivorjump.skillDuration"),
    angleCycle = config.getParameter("sgsurvivorjump.angleCycle"),
    fireTimer = 0,
    fireInterval = config.getParameter("sgsurvivorjump.fireInterval"),
    fireAngle = 0,
    maxFireAngle = config.getParameter("sgsurvivorjump.maxFireAngle"),
    projectileCount = config.getParameter("sgsurvivorjump.projectileCount"),
    winddownTimer = config.getParameter("sgsurvivorjump.winddownTime")
  }
end

function sgsurvivorjump.enter()
  if not hasTarget() then return nil end

  return sgsurvivorjump.initialStateData()
end


function sgsurvivorjump.enterWith(args)
  if not args or not args.enteringPhase then return nil end

  return sgsurvivorjump.initialStateData()
end

--------------------------------------------------------------------------------
function sgsurvivorjump.enteringState(stateData)
  animator.setAnimationState("movement", "idle")

  monster.setActiveSkillName("sgsurvivorjump")

  stateData.lastToSpawn = world.distance(self.spawnPosition, mcontroller.position())
end

--------------------------------------------------------------------------------
function sgsurvivorjump.update(dt, stateData)
  if not hasTarget() then return true end


  local toSpawn = {0, 0}
  if math.abs(toSpawn[1]) > 1 then
    --Approach spawn position
    if toSpawn[1] * stateData.lastToSpawn[1] < 0 then
      local position = mcontroller.position()
      mcontroller.setPosition(position)
      mcontroller.setVelocity({0,0})
    else
      animator.setAnimationState("movement", "move")
      mcontroller.controlMove(util.toDirection(toSpawn[1]), true)
    end
    stateData.lastToSpawn = toSpawn
  elseif not stateData.firing then
    --Float up to get into firing position
    animator.setAnimationState("electricBurst", "on")
    if not stateData.woundUp then 
      animator.setAnimationState("movement", "windup")
      stateData.woundUp = true
    end

    mcontroller.controlParameters({ gravityEnabled = false })
    mcontroller.controlApproachXVelocity(0, 50)

    local approachPosition = {mcontroller.position()[1], self.spawnPosition[2] + stateData.riseHeight}
    flyTo(approachPosition, stateData.riseSpeed)

    local approachDistance = world.magnitude(approachPosition, mcontroller.position())
    if approachDistance < 1 then
      stateData.firing = true
    end
  --In firing position
  else
    mcontroller.controlParameters({ gravityEnabled = false })

    --Fire electricity until skill duration runs out
    if stateData.skillTimer < stateData.skillDuration then
      mcontroller.controlFly({0, 0})

      stateData.skillTimer = stateData.skillTimer + dt
      local angle = math.sin((stateData.skillTimer / stateData.angleCycle) * math.pi * 2) * stateData.maxFireAngle

      stateData.fireTimer = stateData.fireTimer - dt
      if stateData.fireTimer <= 0 then
        animator.playSound("electricBurst")

        sgsurvivorjump.fire(angle, stateData.projectileCount)

        stateData.fireTimer = stateData.fireTimer + stateData.fireInterval
      end
    --Wind down floating to the ground before leaving the state
    else
      local toSpawn = world.distance({mcontroller.position()[1], self.spawnPosition[2]}, mcontroller.position())
      if stateData.winddownTimer == config.getParameter("sgsurvivorjump.winddownTime") then
        animator.setAnimationState("movement", "winddown")
      end
      mcontroller.controlApproachYVelocity(toSpawn[2] / stateData.winddownTimer, 40)

      stateData.winddownTimer = stateData.winddownTimer - dt
      if stateData.winddownTimer <= 0 then
        return true
      end
    end
  end

  return false
end

function sgsurvivorjump.fire(angle, count)
  local projectileType = config.getParameter("sgsurvivorjump.projectile.type")
  local projectileConfig = config.getParameter("sgsurvivorjump.projectile.config")
  local projectileCenterOffset = config.getParameter("sgsurvivorjump.projectile.centerOffset")
  projectileCenterOffset[1] = projectileCenterOffset[1] * mcontroller.facingDirection()

  if projectileConfig.power then
    projectileConfig.power = projectileConfig.power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  end

  local innerRadius = config.getParameter("sgsurvivorjump.projectile.innerRadius")

  local angleInterval = math.pi * 2 / count

  for x = 1, count do
    local projectileAngle = angle + (x - 1) * angleInterval
    local offset = {innerRadius, 0}
    offset = vec2.rotate(offset, projectileAngle)

    local fireVector = {math.cos(projectileAngle), math.sin(projectileAngle)}
    local firePosition = vec2.add(vec2.add(mcontroller.position(), projectileCenterOffset), offset)
    world.spawnProjectile(projectileType, firePosition, entity.id(), fireVector, false, projectileConfig)
  end

end

function sgsurvivorjump.leavingState(stateData)
  animator.setAnimationState("electricBurst", "off")

  monster.setActiveSkillName("")
end
