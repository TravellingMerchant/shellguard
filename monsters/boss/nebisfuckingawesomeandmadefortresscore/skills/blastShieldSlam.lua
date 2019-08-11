----------Blast shield slam attack, mostly for entering phases--------
blastShieldSlam = {}

function blastShieldSlam.enter(args)
  if not args or not args.enteringPhase then return nil end
  
  return {
    windupDuration = config.getParameter("blastShieldSlam.windupDuration", 1),
	winddownDuration = config.getParameter("blastShieldSlam.winddownDuration", 1),
	timer = config.getParameter("blastShieldSlam.windupDuration", 1),
	winddown = config.getParameter("blastShieldSlam.winddown", false),
    prepareSlam = false,
    slam = false
  }
end

function blastShieldSlam.enteringState(stateData)
  if stateData.winddown == true then
    --monster.setActiveSkillName("blastShieldSlam")
  end
  animator.setAnimationState("blastShield", "open")
  animator.playSound("blastShieldSlamWindup")
end

function blastShieldSlam.update(dt, stateData)
  stateData.timer = stateData.timer - dt
  mcontroller.controlFly({0,0})

  if stateData.windupDuration > 0 then
    stateData.windupDuration = stateData.windupDuration - dt

    if stateData.windupDuration < 0 then
      animator.setAnimationState("blastShield", "slam")
      animator.playSound("blastShieldSlam")
    end

    return false
  end

  if animator.animationState("blastShield") == "closed" and stateData.winddownDuration > 0 and stateData.winddown == true then
	stateData.winddownDuration = stateData.winddownDuration - dt
	
    if stateData.winddownDuration < 0 then
      animator.setAnimationState("blastShield", "winddown")
    end
	

    return false
  end

  if animator.animationState("blastShield") == "slam" or animator.animationState("blastShield") == "closed" then
    monster.setDamageOnTouch(true)
  else
    monster.setDamageOnTouch(false)
  end
  
  
  if stateData.timer <= 0 then
    return true
  else
    return false
  end
end

function blastShieldSlam.leavingState(stateData)
end