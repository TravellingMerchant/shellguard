--This is not really an attack, just a state to show the crystal boss has been hurt
sgcrystalShatterAttack = {}

function sgcrystalShatterAttack.enterWith(args)
  if not args or not args.enteringPhase then return nil end

  return {
    timer = config.getParameter("sgcrystalShatterAttack.skillTime", 1),
    rotateInterval = config.getParameter("sgcrystalShatterAttack.rotateInterval", 0.2),
    rotateAngle = config.getParameter("sgcrystalShatterAttack.rotateAngle", 0.05),
    bleedAmount = config.getParameter("sgcrystalShatterAttack.bleedAmount", 100)
  }
end

function sgcrystalShatterAttack.enteringState(stateData)
  animator.setAnimationState("shell", "stage"..currentPhase())
  animator.setAnimationState("eye", "hurt")

  animator.playSound("shatter")
  animator.playSound("hurt")

  --Spawn crystal shards
  for i = 1, 10 do
    local randAngle = math.random() * math.pi * 2
    local spawnPosition = vec2.add(mcontroller.position(), vec2.rotate({8, 0}, randAngle))
    local aimVector = {math.cos(randAngle), math.sin(randAngle)}
    local projectile = "crystalshard"..math.random(1,6)
    world.spawnProjectile(projectile, spawnPosition, entity.id(), aimVector, false, {
      speed = 10 + math.random() * 30,
      power = 0, 
      timeToLive = 3 + math.random() * 3
    })
  end
end

function sgcrystalShatterAttack.update(dt, stateData)
  stateData.timer = stateData.timer - dt

  local duration = config.getParameter("sgcrystalShatterAttack.skillTime", 1) - stateData.timer
  local angle = sgcrystalShatterAttack.angleFactorFromTime(stateData.timer, stateData.rotateInterval) * stateData.rotateAngle - stateData.rotateAngle / 2
  animator.rotateGroup("all", angle, true)

  if stateData.timer <= 0 then
    return true
  end
end

--basic triangle wave
function sgcrystalShatterAttack.angleFactorFromTime(timer, interval)
  local modTime = timer % interval
  if modTime < interval / 2 then
    return modTime / (interval / 2)
  else
    return (interval - modTime) / (interval / 2) 
  end
end

function sgcrystalShatterAttack.leavingState(stateData)
  animator.rotateGroup("all", 0, true)
  animator.setAnimationState("eye", "idle")
end
