function boosterInit()
	self.boosterCooldown = config.getParameter("boosterCooldown",0)
	self.maxBoosterCooldown = config.getParameter("maxBoosterCooldown",4)
	self.boosterStrength = config.getParameter("boosterStrength",{0,50})
end

function boosters()
	self.boosterCooldown = math.max(0,self.boosterCooldown-self.dt)
	if not self.lastJumping and self.isFalling and self.boosterCooldown == 0 and vehicle.controlHeld("drivingSeat","jump") then
		mcontroller.addMomentum(vec2.rotate(self.boosterStrength,self.angle))
		self.boosterCooldown = self.maxBoosterCooldown
		world.spawnProjectile("sgspidersolidfuelbooster", vec2.add(mcontroller.position(), vec2.rotate({0, -4.25},self.angle)), entity.id(), vec2.rotate({0,-1},self.angle), false)
	end
	if vehicle.controlHeld("drivingSeat","jump") then
		self.lastJumping = true
	else
		self.lastJumping = false
	end
end