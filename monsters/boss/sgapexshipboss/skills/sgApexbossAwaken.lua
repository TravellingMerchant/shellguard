--------------------------------------------------------------------------------
sgApexbossAwaken = {}

function sgApexbossAwaken.enter()
  if not hasTarget() then return nil end
  if self.hasAwoken then return nil end
  
  self.awakenTime = config.getParameter("sgApexbossAwaken.awakenTime", 1)
  self.timer = 0
  
  self.hasAwoken = false
  
  local newPosition = vec2.add(mcontroller.position(), config.getParameter("sgApexbossAwaken.startOffset", {0, 13}))
  self.spawnPosition = newPosition
  
  self.flyTime = config.getParameter("sgApexbossAwaken.startOffset", {0, 13})[2] / (mcontroller.baseParameters().flySpeed / 10)

  return {
    projectileType = config.getParameter("sgApexbossAwaken.projectileType", "dragonblockbuster"),
    projectileParameters = config.getParameter("sgApexbossAwaken.projectileParameters", {}),
    trackSourceEntity = config.getParameter("sgApexbossAwaken.trackSourceEntity", false)
  }
end

function sgApexbossAwaken.onInit()
end

function sgApexbossAwaken.onUpdate(dt)
end

function sgApexbossAwaken.enteringState(stateData)
  monster.setActiveSkillName("sgApexbossAwaken")
  animator.setAnimationState("head", "visible")
end

function sgApexbossAwaken.update(dt, stateData)
  self.timer = math.min(self.awakenTime, self.timer + dt)

  if self.timer == self.awakenTime then
    self.hasAwoken = true
	if self.flyTime > 0 then
      animator.setAnimationState("thrusters", "on")
      animator.setAnimationState("head", "visible")
      flyTo(self.spawnPosition)
	  self.flyTime = self.flyTime - dt
	else
      mcontroller.controlFly({ 0, 0 })
	  return true
    end
  end
end