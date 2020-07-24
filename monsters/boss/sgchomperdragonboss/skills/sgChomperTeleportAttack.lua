sgChomperTeleportAttack = {}

function sgChomperTeleportAttack.enter()
  if self.targetPosition == nil then return nil end

  sgChomperTeleportAttack.reappeared = false
  animator.burstParticleEmitter("teleport")
  animator.playSound("teleportOut")
  return { 
    timer = config.getParameter("sgChomperTeleportAttack.skillTime")
  }
end

function sgChomperTeleportAttack.enteringState(stateData)
  monster.setActiveSkillName("sgChomperTeleportAttack")
end

function sgChomperTeleportAttack.update(dt, stateData)
  mcontroller.controlFace(1)
  status.addEphemeralEffect("invulnerable")

  if stateData.timer > config.getParameter("sgChomperTeleportAttack.skillTime") - 0.55 then
    mcontroller.controlFly({ 0, 0 })
  elseif stateData.timer > 0 then
    if animator.animationState("movement") ~= "invisible" then
      animator.setAnimationState("movement", "invisible")
	  animator.setAnimationState("head", "invisible")
	  animator.setAnimationState("thrusters", "invisible")
    end

    if self.targetPosition ~= nil then
      flyTo({
        self.targetPosition[1],
        self.spawnPosition[2]
      })
    else
      mcontroller.controlFly({ 0, 1 })
    end

    if stateData.timer < 0.3 and not sgChomperTeleportAttack.reappeared then
      sgChomperTeleportAttack.reappeared = true
      animator.burstParticleEmitter("teleport")
      animator.playSound("teleportIn")
    end
  else
    return true
  end

  stateData.timer = stateData.timer - dt
  return false
end

function sgChomperTeleportAttack.leavingState(stateData)
  status.removeEphemeralEffect("invulnerable")
  mcontroller.setVelocity({ 0, 0 })
  mcontroller.controlFly({ 0, 0 })
  animator.setAnimationState("movement", "visible")
  animator.setAnimationState("head", "visible")
  animator.setAnimationState("thrusters", "on")
end
