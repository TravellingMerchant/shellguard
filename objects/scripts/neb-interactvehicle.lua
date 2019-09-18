function init()
  if not storage.vehicleHasSpawned then
    object.setInteractive(true)
    animator.setAnimationState("objectState", "ready")
		storage.vehicleHasSpawned = false
  else
    animator.setAnimationState("objectState", "charging")
		object.setInteractive(false)
  end
  
	--Vehicle--
  self.vehicleType = config.getParameter("vehicleType")
	self.vehicleOverrideParameters = config.getParameter("vehicleOverrideParameters", {})
	self.vehicleSpawnOffset = config.getParameter("vehicleSpawnOffset", {0,1})
	
	--Cooldown--
	self.cooldown = config.getParameter("cooldown", 1)
	self.cooldownTimer = self.cooldown
	
	--Floating--
  self.useFloatingObject = config.getParameter("useFloatingObject", false)
  self.floatingObjectCycle = config.getParameter("floatingObjectCycle", 1.0) / (2 * math.pi)
  self.floatingObjectMaxTransform = config.getParameter("floatingObjectMaxTransform", 1.0)
end

function update(dt)
  --Optionally make the ship float up and down
  if self.useFloatingObject then
		self.timer = self.timer + dt
		local offset = math.sin(self.timer / self.floatingObjectCycle) * self.floatingObjectMaxTransform
		
		animator.resetTransformationGroup("floatingShip")
		animator.translateTransformationGroup("floatingShip", {0, offset})
  end
	
	--Prevent the player from spamming the ship spawner
	if storage.vehicleHasSpawned then
		self.cooldownTimer = self.cooldownTimer - dt
		if self.cooldownTimer <= 0 then
			storage.vehicleHasSpawned = false
			object.setInteractive(true)
			self.cooldownTimer = self.cooldown
		end
	end
end

function activate()
  animator.setAnimationState("objectState", "buttonpress")
	if not storage.vehicleId then
		storage.vehicleId = world.vehicle(self.vehicleType, vec2.add(entity.position(), self.vehicleSpawnOffset), self.vehicleOverrideParameters)
	elseif world.entityExists(storage.vehicleId) then
		world.sendEntityMessage(storage.vehicleId, "terminateSelf") 
		storage.vehicleId = world.vehicle(self.vehicleType, vec2.add(entity.position(), self.vehicleSpawnOffset), self.vehicleOverrideParameters)
	end
  storage.vehicleHasSpawned = true
  object.setInteractive(false)
end

function onInteraction(args)
  if storage.vehicleHasSpawned == false then
    activate()
  end
end
