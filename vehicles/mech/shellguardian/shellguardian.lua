require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
	self.Oh = 0
	self.A = 1
	self.B = 1
	self.Ok = 0
	self.C = 0.5
	self.T = 2
	self.t2 = 0
	self.E = 1
	
	self.time = 0
	
	message.setHandler("changeParameter", function(_, _, args)
		self[args.key] = args.value
	end)
end

function update()
	self.time = self.time + script.updateDt()
	
	local layers = {
		"front", "back"
	}
	
	local offset = 0
	for _, layer in ipairs(layers) do
		animator.resetTransformationGroup(layer .. "LegUp")
		animator.resetTransformationGroup(layer .. "LegLow")
		animator.resetTransformationGroup(layer .. "Foot")
		
		local hipAngle, kneeAngle, footAngle
		if (currentInterval(self.time) == 1 and offset == 0) or (currentInterval(self.time) ~= 1 and offset ~= 0) then
			hipAngle = self.Oh + self.A * math.sin(2 * math.pi * self.time / self.T + offset)
			kneeAngle = self.Ok + self.C * math.sin(2 * math.pi * (self.time - self.t2) / self.T + offset)
			footAngle = self.E * math.sin(2 * math.pi * self.time / (self.T / 2.0) + offset)
		else
			hipAngle = self.Oh + self.B * math.sin(2 * math.pi * self.time / self.T + offset)
			kneeAngle = self.Ok
			footAngle = - hipAngle
		end
		
		animator.rotateTransformationGroup(layer .. "LegUp", hipAngle, animator.partPoint(layer .. "LegUp", "rotationCenter"))
		animator.rotateTransformationGroup(layer .. "LegLow", kneeAngle, {1.375, 0.125})
		animator.rotateTransformationGroup(layer .. "Foot", footAngle, {1.875, 0.625})
		offset = offset + math.pi
	end
end

function currentInterval(time)
	return (time % self.T) < self.T / 2.0 and 1 or 2
end

function uninit()

end