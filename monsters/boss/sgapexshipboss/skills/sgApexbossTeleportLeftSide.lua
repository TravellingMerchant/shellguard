sgApexbossTeleportLeftSide = {}

function sgApexbossTeleportLeftSide.enter()
  if self.targetPosition == nil then return nil end
  
  self.testPoly = config.getParameter("sgApexbossTeleportLeftSide.testPoly", {})

  sgApexbossTeleportLeftSide.reappeared = false
  animator.burstParticleEmitter("teleport")
  animator.playSound("teleportOut")
  return { 
    timer = config.getParameter("sgApexbossTeleportLeftSide.skillTime")
  }
end

function sgApexbossTeleportLeftSide.enteringState(stateData)
  monster.setActiveSkillName("sgApexbossTeleportLeftSide")
end

function sgApexbossTeleportLeftSide.update(dt, stateData)
  mcontroller.controlFace(1)
  status.addEphemeralEffect("invulnerable")

  if stateData.timer > config.getParameter("sgApexbossTeleportLeftSide.skillTime") - 0.55 then
    mcontroller.controlFly({ 0, 0 })
  elseif stateData.timer > 0 then
    if animator.animationState("movement") ~= "invisible" then
      animator.setAnimationState("movement", "invisible")
	  animator.setAnimationState("head", "invisible")
	  animator.setAnimationState("thrusters", "invisible")
    end
	
    local position = vec2.add(self.spawnPosition, {-500, 0})
	
    local wallCollision = world.lineTileCollisionPoint(self.spawnPosition, position)
    if wallCollision then
      local wallPos, normal = wallCollision[1], wallCollision[2]
	  position = world.resolvePolyCollision(self.testPoly, wallPos, 5)
    end

    if position ~= nil then
      flyTo({
        position[1],
        self.spawnPosition[2]
      })
    else
      mcontroller.controlFly({ 0, 1 })
    end

    if stateData.timer < 0.3 and not sgApexbossTeleportLeftSide.reappeared then
      sgApexbossTeleportLeftSide.reappeared = true
      animator.burstParticleEmitter("teleport")
      animator.playSound("teleportIn")
    end
  else
    return true
  end

  stateData.timer = stateData.timer - dt
  return false
end

function sgApexbossTeleportLeftSide.leavingState(stateData)
  status.removeEphemeralEffect("invulnerable")
  mcontroller.setVelocity({ 0, 0 })
  mcontroller.controlFly({ 0, 0 })
  animator.setAnimationState("movement", "visible")
  animator.setAnimationState("head", "visible")
  animator.setAnimationState("thrusters", "on")
end
