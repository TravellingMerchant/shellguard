function meleeInit()
	self.meleeTimer = config.getParameter("meleeTimer")
	self.maxMeleeTimer = config.getParameter("maxMeleeTimer")
	self.meleeDashTime = config.getParameter("meleeDashTime")
	self.meleeHorizontalForceMultiplier = config.getParameter("meleeHorizontalForceMultiplier")
	self.meleeInProgress = false
end

function meleeLoop()
	if self.meleeTimer > 0 then
		self.meleeTimer = self.meleeTimer - self.dt
	end
	if self.meleeInProgress then
		meleeTrigger()
		return false
	end
	if vehicle.controlHeld("drivingSeat","Special1") and self.meleeTimer <= 0 then
		self.meleeInProgress = true
		self.meleeDirection = self.facingDirection
		self.directionLock = self.facingDirection
		self.meleeTimer = self.maxMeleeTimer
	end
end

function meleeTrigger()
	if vehicle.controlHeld("drivingSeat","Special1") and self.meleeTimer >= (self.maxMeleeTimer - self.meleeDashTime) and not self.isFalling then
		mcontroller.addMomentum({self.meleeDirection*self.meleeHorizontalForceMultiplier,0})
		if self.directionLock == 1 then
			vehicle.setDamageSourceEnabled("sgraiderlegright",true)
		else
			vehicle.setDamageSourceEnabled("sgraiderlegleft",true)
		end
	else
		if self.directionLock == 1 then
			vehicle.setDamageSourceEnabled("sgraiderlegright",false)
		else
			vehicle.setDamageSourceEnabled("sgraiderlegleft",false)
		end
		self.meleeInProgress = false
		self.directionLock = nil
	end
end