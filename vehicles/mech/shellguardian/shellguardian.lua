require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
	self.Oh = config.getParameter("hipJointAngleOffset")
	self.A = config.getParameter("hipJointForwardAmplitude")
	self.B = config.getParameter("hipJointBackwardAmplitude")
	self.Ok = config.getParameter("kneeJointAngleOffset")
	self.C = config.getParameter("kneeJointForwardAmplitude")
	self.T = config.getParameter("cycleTime")
	self.t2 = config.getParameter("kneeLagTime")
	self.E = config.getParameter("feetJointForwardAmplitude")
	self.D1 = config.getParameter("shoulderJointForwardAmplitude")
	self.D2 = config.getParameter("shoulderJointBackwardAmplitude")
	
	self.mechHorizontalMovement = config.getParameter("mechHorizontalMovement")
	self.time = 0
	self.walking = false
	self.controlHeld = false
	message.setHandler("changeParameter", function(_, _, args)
		self[args.key] = args.value
	end)
end

function update()
	collectControls()
	animate()
	move()
end

function collectControls()
	if vehicle.controlHeld("seat", "left") then
		self.facingDirection = -1
		self.controlHeld = true
	elseif vehicle.controlHeld("seat", "right") then
		self.facingDirection = 1
		self.controlHeld = true
	else
		self.controlHeld = false
	end
end

function animate()
	if self.controlHeld then
		self.walking = true
		self.time = self.time + script.updateDt()
	else
		if self.time % (self.T / 2) > 0.01 then
			if (self.time % self.T) < self.T / 4.0 then
				self.time = self.time - script.updateDt()
			else
				self.time = self.time + script.updateDt()
			end
		else
			self.walking = false
			self.time = 0		
		end
	end

	animator.setFlipped(self.facingDirection == -1)
	
	local layers = {
		"front", "back"
	}
	
	if self.walking then
		local offset = 0
		for _, layer in ipairs(layers) do
			animator.resetTransformationGroup(layer .. "LegUp")
			animator.resetTransformationGroup(layer .. "LegLow")
			animator.resetTransformationGroup(layer .. "Foot")
			
			animator.resetTransformationGroup(layer .. "ArmUp")
			animator.resetTransformationGroup(layer .. "ArmLow")
			animator.resetTransformationGroup(layer .. "Hand")		
			
			local hipAngle, kneeAngle, footAngle, shoulderAngle, elbowAngle, handAngle
			if (currentInterval(self.time) == 1 and offset == 0) or (currentInterval(self.time) ~= 1 and offset ~= 0) then
				hipAngle = self.Oh + self.A * math.sin(2 * math.pi * self.time / self.T + offset)
				kneeAngle = self.Ok + math.min(self.C * math.sin(2 * math.pi * (self.time - self.t2) / self.T + offset), 0)
				footAngle = self.E * math.sin(2 * math.pi * self.time / (self.T) + offset)
				
				shoulderAngle = - self.D1 * math.sin(2 * math.pi * self.time / self.T  + offset)
			else
				hipAngle = self.Oh + self.B * math.sin(2 * math.pi * self.time / self.T + offset)
				kneeAngle = self.Ok
				footAngle = - hipAngle
				
				shoulderAngle = - self.D2 * math.sin(2 * math.pi * self.time / self.T  + offset)
			end
			
			animator.rotateTransformationGroup(layer .. "LegUp", hipAngle, animator.partProperty(layer .. "LegUp", "rotationCenter"))
			animator.rotateTransformationGroup(layer .. "LegLow", kneeAngle, {1.375, 0.125})
			animator.rotateTransformationGroup(layer .. "Foot", footAngle, {1.875, 0.625})
			
			animator.rotateTransformationGroup(layer .. "ArmUp", shoulderAngle, animator.partProperty(layer .. "ArmUp", "rotationCenter"))
			offset = offset + math.pi
		end
	end
end

function move()
	local layers = {"front", "back"}
	
	local poly = {}
	for _, layer in ipairs(layers) do
		world.debugLine(vec2.add(mcontroller.position(), animator.partPoint(layer .. "LegLow", "leftAnchor")), 
		vec2.add(mcontroller.position(), animator.partPoint(layer .. "Foot", "heel")), "red")
		
		world.debugLine(vec2.add(mcontroller.position(), animator.partPoint(layer .. "Foot", "heel")), 
		vec2.add(mcontroller.position(), animator.partPoint(layer .. "Foot", "toe")), "red")
		
		world.debugLine(vec2.add(mcontroller.position(), animator.partPoint(layer .. "Foot", "toe")), 
		vec2.add(mcontroller.position(), animator.partPoint(layer .. "LegLow", "rightAnchor")), "red")
		--[[
		local collisionPoint = world.lineCollision(vec2.add(mcontroller.position(), animator.partPoint(layer .. "Foot", "heel")), 
			vec2.add(mcontroller.position(), animator.partPoint(layer .. "Foot", "toe")))
		
		if collisionPoint then
			-- Find the top block
			local topBlock = world.lineCollision(vec2.add(collisionPoint, {0, 50}), collisionPoint)
			if topBlock then
				sb.setLogMap("TopBlock" .. layer, sb.print(topBlock))
				sb.setLogMap("CollisionPoint" .. layer, sb.print(collisionPoint))
				mcontroller.translate({0, math.abs(topBlock[2] - collisionPoint[2])})
				world.debugLine(topBlock, collisionPoint, "yellow")
			end
		end
		
		--]]
		table.insert(poly, animator.partPoint(layer .. "LegLow", "leftAnchor"))
		table.insert(poly, animator.partPoint(layer .. "Foot", "heel"))
		table.insert(poly, animator.partPoint(layer .. "Foot", "toe"))
		table.insert(poly, animator.partPoint(layer .. "LegLow", "rightAnchor"))
	end
	
	--test for changing the collision poly in runtime
	if vehicle.entityLoungingIn("seat") then
		mcontroller.applyParameters({
			collisionPoly = poly
		})
	else
		mcontroller.resetParameters()
	end
	
	if self.controlHeld then
		--if (self.time % self.T) < self.T / 2.0 then
			mcontroller.setXVelocity(self.mechHorizontalMovement * self.facingDirection)
		--end
	else
		mcontroller.setXVelocity(0)
	end
end

function currentInterval(time)
	return (time % self.T) < self.T / 2.0 and 1 or 2
end

function uninit()

end