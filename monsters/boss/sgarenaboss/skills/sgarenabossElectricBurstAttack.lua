sgarenabossElectricBurstAttack = {}

--------------------------------------------------------------------------------
function sgarenabossElectricBurstAttack.initialStateData()
  return {
    riseHeight = config.getParameter("sgarenabossElectricBurstAttack.riseHeight"),
    riseSpeed = config.getParameter("sgarenabossElectricBurstAttack.riseSpeed"),
    firing = false,
    skillTimer = 0,
    skillDuration = config.getParameter("sgarenabossElectricBurstAttack.skillDuration"),
    angleCycle = config.getParameter("sgarenabossElectricBurstAttack.angleCycle"),
    fireTimer = 0,
    fireInterval = config.getParameter("sgarenabossElectricBurstAttack.fireInterval"),
    fireAngle = 0,
    maxFireAngle = config.getParameter("sgarenabossElectricBurstAttack.maxFireAngle"),
    projectileCount = config.getParameter("sgarenabossElectricBurstAttack.projectileCount"),
    winddownTimer = config.getParameter("sgarenabossElectricBurstAttack.winddownTime")
  }
end

function sgarenabossElectricBurstAttack.enter()
  if not hasTarget() or currentPhase() < 4 then return nil end

  return sgarenabossElectricBurstAttack.initialStateData()
end


function sgarenabossElectricBurstAttack.enterWith(args)
  if not args or not args.enteringPhase then return nil end

  return sgarenabossElectricBurstAttack.initialStateData()
end

--------------------------------------------------------------------------------
function sgarenabossElectricBurstAttack.enteringState(stateData)
  animator.setAnimationState("movement", "idle")

  monster.setActiveSkillName("sgarenabossElectricBurstAttack")

  stateData.lastToSpawn = world.distance(self.spawnPosition, mcontroller.position())
end

--------------------------------------------------------------------------------
function sgarenabossElectricBurstAttack.update(dt, stateData)
  if not hasTarget() then return true end


  local toSpawn = world.distance(self.spawnPosition, mcontroller.position())
  if math.abs(toSpawn[1]) > 1 then
    --Approach spawn position
    if toSpawn[1] * stateData.lastToSpawn[1] < 0 then
      local position = mcontroller.position()
      mcontroller.setPosition({self.spawnPosition[1], position[2]})
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

    local approachPosition = {self.spawnPosition[1], self.spawnPosition[2] + stateData.riseHeight}
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

        sgarenabossElectricBurstAttack.fire(angle, stateData.projectileCount)

        stateData.fireTimer = stateData.fireTimer + stateData.fireInterval
      end
    --Wind down floating to the ground before leaving the state
    else
      local toSpawn = world.distance(self.spawnPosition, mcontroller.position())
      if stateData.winddownTimer == config.getParameter("sgarenabossElectricBurstAttack.winddownTime") then
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

function sgarenabossElectricBurstAttack.fire(angle, count)
  local projectileType = config.getParameter("sgarenabossElectricBurstAttack.projectile.type")
  local projectileConfig = config.getParameter("sgarenabossElectricBurstAttack.projectile.config")
  local projectileCenterOffset = config.getParameter("sgarenabossElectricBurstAttack.projectile.centerOffset")
  projectileCenterOffset[1] = projectileCenterOffset[1] * mcontroller.facingDirection()

  if projectileConfig.power then
    projectileConfig.power = projectileConfig.power * root.evalFunction("monsterLevelPowerMultiplier", monster.level())
  end

  local innerRadius = config.getParameter("sgarenabossElectricBurstAttack.projectile.innerRadius")

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

function sgarenabossElectricBurstAttack.leavingState(stateData)
  animator.setAnimationState("electricBurst", "off")

  monster.setActiveSkillName("")
end
