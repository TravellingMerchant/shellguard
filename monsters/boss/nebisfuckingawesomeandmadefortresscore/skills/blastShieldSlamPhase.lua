--Blast shield slam transitional phase
blastShieldSlamPhase = {}

function blastShieldSlamPhase.enterWith(args)
  if not args or not args.enteringPhase then return nil end

  return {
    windupDuration = config.getParameter("blastShieldSlamPhase.windupDuration", 1),
		winddownDuration = config.getParameter("blastShieldSlamPhase.winddownDuration", 1),
    timer = config.getParameter("blastShieldSlam.skillTime", 1) + config.getParameter("blastShieldSlam.windupDuration", 1),
    rotateInterval = config.getParameter("blastShieldSlamPhase.rotateInterval", 0.2),
    rotateAngle = config.getParameter("blastShieldSlamPhase.rotateAngle", 0.05),
    prepareSlam = false,
    slam = false
  }
end

function blastShieldSlamPhase.enteringState(stateData)
  if animator.animationState("blastShield") == "open" then
  end
  if animator.animationState("blastShield") == "closed" then
    animator.setAnimationState("blastShield", "winddown")
	stateData.windupDuration = stateData.windupDuration * 1.25
  end
  
  animator.setAnimationState("stages", "stage"..currentPhase())
  animator.playSound("blastShieldSlamWindup")
end

function blastShieldSlamPhase.update(dt, stateData)
  stateData.timer = stateData.timer - dt

  local duration = config.getParameter("blastShieldSlamPhase.skillTime", 1) - stateData.timer
  local angle = blastShieldSlamPhase.angleFactorFromTime(stateData.timer, stateData.rotateInterval) * stateData.rotateAngle - stateData.rotateAngle / 2
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
function blastShieldSlamPhase.angleFactorFromTime(timer, interval)
  local modTime = timer % interval
  if modTime < interval / 2 then
    return modTime / (interval / 2)
  else
    return (interval - modTime) / (interval / 2) 
  end
end

function blastShieldSlamPhase.leavingState(stateData)
  animator.rotateGroup("core", 0, true)
  animator.setAnimationState("blastShield", "closed")
end