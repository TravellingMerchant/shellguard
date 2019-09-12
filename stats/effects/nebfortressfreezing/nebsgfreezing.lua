function init()
  animator.setParticleEmitterOffsetRegion("icetrail", mcontroller.boundBox())
  animator.setParticleEmitterActive("icetrail", true)
  effect.setParentDirectives("fade=00BBFF=0.15")

  script.setUpdateDelta(5)
  effect.addStatModifierGroup({
    {stat = "jumpModifier", amount = -0.15}
  })
  
  self.groundMovementModifier = 1
  self.airJumpModifier = 1
  self.speedModifier = 1
  self.activeTimer = 0
end

function update(dt)
  self.activeTimer = self.activeTimer + dt
  
  mcontroller.controlModifiers({
	groundMovementModifier = self.groundMovementModifier - dt * 2,
	speedModifier = self.speedModifier - dt * 1.5,
	airJumpModifier = self.airJumpModifier - dt
  })
  
  world.debugText(self.activeTimer, mcontroller.position(), "red")
  
  if self.activeTimer >= config.getParameter("timeToFreeze", 5) then
	status.addEphemeralEffect("nebsgfrozen", config.getParameter("freezeDuration", 5), effect.sourceEntity())
	effect.expire()
  end
end

function onExpire()
  status.addEphemeralEffect("frostslow", config.getParameter("freezeDuration", 5), effect.sourceEntity())
end

function uninit()

end
