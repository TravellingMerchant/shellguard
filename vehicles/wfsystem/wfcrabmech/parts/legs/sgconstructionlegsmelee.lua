function meleeInit()
	self.meleeTimer = config.getParameter("meleeTimer")
	self.maxMeleeTimer = config.getParameter("maxMeleeTimer")
	self.meleeValidLegs = config.getParameter("meleeValidLegs")
	self.meleeHorizontalForceMultiplier = config.getParameter("meleeHorizontalForceMultiplier")
	self.startMelee = false
	self.attackLeg = nil
	self.meleeInProgress = false
	self.attackTime = 0
end

function meleeLoop()
	if self.attackTime > 0 then
		self.attackTime = self.attackTime - self.dt
		vehicle.setDamageSourceEnabled("sgconstructionleg"..self.attackingSide,true)
	elseif self.attackingSide then
		vehicle.setDamageSourceEnabled("sgconstructionleg"..self.attackingSide,false)
		self.attackingSide = nil
	end
	self.meleeTimer = math.max(0,self.meleeTimer - self.dt)
	if self.meleeTimer > 0 then
		return false
	end
	if self.meleeInProgress then
		meleeTrigger()
		return false
	end
	if vehicle.controlHeld("drivingSeat","Special1") then
		local aimVector = world.distance(vehicle.aimPosition("drivingSeat"), mcontroller.position())
		if vec2.mag(aimVector) < 5 then
			return false
		end
		self.meleeInProgress = true
		local bestLeg = nil
		for _,leg in ipairs(self.meleeValidLegs) do
			if math.abs(aimVector[1] - self.legSeeds[leg]) <= math.abs(aimVector[1] - self.legSeeds[bestLeg or leg]) and self.legStatus[self.legPairs[leg]].state == "stable" and vec2.mag(vec2.sub(aimVector, self.chassisOffsets[leg])) > 3 then
				bestLeg = leg
			end
		end
		self.attackLeg = bestLeg
	end
end

function meleeTrigger()
	local leg = self.attackLeg
	if not leg then
		self.meleeInProgress = false
		return false
	end
	local aimVector = world.distance(vehicle.aimPosition("drivingSeat"), vec2.add(self.chassisOffsets[leg], mcontroller.position()))
	local aimLength = vec2.mag(aimVector)
	local aimAngle = vecToAngle(aimVector)
	local angleAdjust = 0.2
	if vehicle.controlHeld("drivingSeat","Special1") then
		aimLength = math.max(math.min(aimLength/3, 1.6*self.legOverreach), 1.1*self.legOverreach)
		if string.sub(leg,1,1) == "l" then
			aimAngle = math.max(math.min(aimAngle, 10*math.pi/6), 5.5*math.pi/6) + angleAdjust
		else
			if aimAngle <= 0.5*math.pi/6 then
				aimAngle = aimAngle - angleAdjust
			elseif aimAngle >= 8*math.pi/6 then
				aimAngle = aimAngle - angleAdjust
			elseif aimAngle <= math.pi then
				aimAngle = 0.5*math.pi/6 - angleAdjust
			else
				aimAngle = 8*math.pi/6 - angleAdjust
			end
		end
		if self.legStatus[leg].state ~= "attackReady" then 
			self.legStatus[leg].state = "attackReady" 
			makeLegStack(leg, self.legStatus[leg].anchor, vec2.add(self.chassisOffsets[leg], vec2.rotate({aimLength, 0}, aimAngle)), 30, 0, {0,0}, true)
		elseif #self.legStatus[leg].stack <= 1 then
			self.legStatus[leg].stack[1] = vec2.add(self.chassisOffsets[leg], vec2.rotate({aimLength, 0}, aimAngle))
		end
	else
		--animator.playSound("melee")
		self.legAttackBlacklist = {}
		self.storedPointsForLegShockwave = nil
		local maxRange = 0.99*(self.lowerLegLength+self.upperLegLength)
		if vec2.mag(aimVector) ~= maxRange then
			aimVector = vec2.mul(vec2.norm(aimVector), maxRange)
		end
		local arc = {0,0}
		if string.sub(leg,1,1) == "l" then
			self.attackingSide = "left"
			aimAngle = math.max(math.min(aimAngle, 10*math.pi/6), 2*math.pi/6)
			arc = vec2.mul(vec2.rotate({1,0}, aimAngle + math.pi/2),5)
		else
			self.attackingSide = "right"
			if aimAngle <= 4*math.pi/6 then
			elseif aimAngle >= 8*math.pi/6 then
			elseif aimAngle <= math.pi then
				aimAngle = 4*math.pi/6
			else
				aimAngle = 8*math.pi/6
			end
			arc = vec2.mul(vec2.rotate({1,0}, aimAngle - math.pi/2),5)
		end
		self.attackTime = 0.3
		self.legStatus[leg].state = "attacking"
		self.attackLegShockwavePending = true
		self.meleeInProgress = false
		makeLegStack(leg, self.legStatus[leg].anchor, vec2.add(self.chassisOffsets[leg], vec2.rotate({maxRange, 0}, aimAngle)), 10, 10, arc, true)
		self.meleeTimer = self.maxMeleeTimer
	end
end