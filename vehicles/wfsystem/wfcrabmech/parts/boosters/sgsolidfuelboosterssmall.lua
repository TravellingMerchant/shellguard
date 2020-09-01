function boosterInit()
	self.boosterCooldown = config.getParameter("boosterCooldown",0)
	self.maxBoosterCooldown = config.getParameter("maxBoosterCooldown",5)
	self.maxBoosterActiveTime = config.getParameter("maxBoosterActiveTime",3)
	self.boosterStrength = config.getParameter("boosterStrength",{0,5})
	self.boosterActiveTime = 0
end

function boosters()
	self.boosterCooldown = math.max(0,self.boosterCooldown-self.dt)
	if not self.lastJumping and self.isFalling and self.boosterCooldown == 0 and self.boosterActiveTime == 0 and vehicle.controlHeld("drivingSeat","jump") then
		self.holdBoost = true
		self.boosterActiveTime = self.maxBoosterActiveTime
		self.lastJumping = true
	end
	if self.lastJumping and self.holdBoost and self.boosterActiveTime > 0 then
		mcontroller.addMomentum(vec2.rotate(self.boosterStrength,self.angle))
		self.boosterActiveTime = math.max(0,self.boosterActiveTime-self.dt)
		world.spawnProjectile("sgspidersolidfuelboostersmall", vec2.add(mcontroller.position(), vec2.rotate({0, -4.25},self.angle)), entity.id(), vec2.rotate({0,-1},self.angle), false)
	elseif self.holdBoost then
		self.holdBoost = false
		self.boosterActiveTime = 0
		self.boosterCooldown = self.maxBoosterCooldown
	end
	if vehicle.controlHeld("drivingSeat","jump") then
		self.lastJumping = true
	else
		self.lastJumping = false
	end
end