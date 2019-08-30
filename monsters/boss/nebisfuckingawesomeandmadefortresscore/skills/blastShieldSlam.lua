--Blast shield slam transitional phase
blastShieldSlam = {}

function blastShieldSlam.enterWith(args)
  if not args or not args.enteringPhase then return nil end

  return {
    windupDuration = config.getParameter("blastShieldSlam.windupDuration", 1),
	winddownDuration = config.getParameter("blastShieldSlam.winddownDuration", 1),
    timer = config.getParameter("blastShieldSlam.skillTime", 1),
    rotateInterval = config.getParameter("blastShieldSlam.rotateInterval", 0.2),
    rotateAngle = config.getParameter("blastShieldSlam.rotateAngle", 0.05),
    prepareSlam = false,
    slam = false
  }
end

function blastShieldSlam.enteringState(stateData)
  if animator.animationState("blastShield") == "open" then
  end
  if animator.animationState("blastShield") == "closed" then
    animator.setAnimationState("blastShield", "winddown")
	stateData.windupDuration = stateData.windupDuration * 1.25
  end
  
  animator.setAnimationState("stages", "stage"..currentPhase())
  animator.playSound("blastShieldSlamWindup")
end

function blastShieldSlam.update(dt, stateData)
  stateData.timer = stateData.timer - dt

  local duration = config.getParameter("blastShieldSlam.skillTime", 1) - stateData.timer
  local angle = blastShieldSlam.angleFactorFromTime(stateData.timer, stateData.rotateInterval) * stateData.rotateAngle - stateData.rotateAngle / 2
  animator.rotateGroup("core", angle, true)

  if stateData.windupDuration > 0 then
    stateData.windupDuration = stateData.windupDuration - dt

    if stateData.windupDuration <= 0 then
      animator.setAnimationState("blastShield", "slam")
      animator.burstParticleEmitter("slam")
      animator.playSound("blastShieldSlam")
    end
  end
  
  if animator.animationState("blastShield") == "slam" then
    monster.setDamageOnTouch(true)
  else
    monster.setDamageOnTouch(false)
  end

  if stateData.timer <= 0 then
    return true
  end
end

--basic triangle wave
function blastShieldSlam.angleFactorFromTime(timer, interval)
  local modTime = timer % interval
  if modTime < interval / 2 then
    return modTime / (interval / 2)
  else
    return (interval - modTime) / (interval / 2) 
  end
end

function blastShieldSlam.leavingState(stateData)
  animator.rotateGroup("core", 0, true)
  animator.setAnimationState("blastShield", "closed")
end