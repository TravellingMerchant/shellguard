require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.aimPositionName = "aimingSeat"
  self.projectileType = config.getParameter("projectileType")
  self.projectileParameters = config.getParameter("projectileParameters", {})
  self.maxGunRotationAngle = math.rad(config.getParameter("maxGunRotationAngle"))
  self.minGunRotationAngle = math.rad(config.getParameter("minGunRotationAngle"))
  self.angleApproachFactor = math.rad(config.getParameter("angleApproachFactor"))
  
  self.justFired = false
  self.angle = 0
end

function update(args)
  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end
  
  if vehicle.controlHeld("aimingSeat", "primaryFire") and animator.animationState("firing") == "idle" then
	animator.setAnimationState("firing", "charge")
	self.justFired = false
  end
  
  if animator.animationState("firing") == "fire" and not self.justFired then
    fireProjectile()
    self.justFired = true   
  end
  
  updateAim()
end

function updateAim()
  if vehicle.entityLoungingIn(self.aimPositionName) then
    animator.resetTransformationGroup("gun")
	
	local aimPosition = vehicle.aimPosition(self.aimPositionName)
	local startPosition = vec2.add(mcontroller.position(), animator.partPoint("gun", "rotationCenter"))
	local angle = vec2.angle(world.distance(aimPosition, startPosition))
	
	-- angle correction
	if angle > math.pi then
		angle = angle - 2 * math.pi
	end
	angle = util.clamp(angle, self.minGunRotationAngle, self.maxGunRotationAngle)
	
	if math.abs(angle - self.angle) > self.angleApproachFactor then
	  self.angle = self.angle + self.angleApproachFactor * util.toDirection(angle - self.angle)
	end
    animator.rotateTransformationGroup("gun", self.angle, animator.partPoint("gun", "rotationCenter"))
  end
end

function fireProjectile()
	local firePosition = animator.partPoint("gun", "firePosition")
	local angle = vec2.angle(vec2.sub(firePosition, animator.partPoint("gun", "rotationCenter")))
	--[[
	if self.facingDirection < 0 then
		angle = angle + math.pi
	end
	]]--
	world.spawnProjectile(self.projectileType, 
		vec2.add(mcontroller.position(), firePosition), 
		entity.id(), 
		vec2.rotate({1, 0}, angle), 
		false, 
		self.projectileParameters)
end