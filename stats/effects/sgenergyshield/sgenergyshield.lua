require "/scripts/util.lua"
require "/scripts/vec2.lua"

--A status that upon activation, spawns some drones to behave similarly to mech drones with similar mechanics
--Made by Nebulox
function init()
	--Drone Config
	self.droneType = config.getParameter("droneType", "mechshielddrone")
	self.droneParameters = config.getParameter("droneParameters", {})
	self.respawnTime = config.getParameter("droneRespawnTime", 5)
	self.droneMax = config.getParameter("droneCount", 4)
	self.droneCount = config.getParameter("droneCount", 4)
	self.droneOrbitDistance = config.getParameter("droneOrbitDistance", 5)
	self.droneOrbitRate = config.getParameter("droneOrbitRate", 0.5)
  self.droneIds = {}
	self.respawnTimer = 0.125
	
  if self.droneOrbitRate then
    self.droneOrbitAngle = 0
  end
end

function update(dt)
  updateDrones()
	
	--Double check if drone spawned
	if #self.droneIds < self.droneCount then
		--Count down the timer
		if not self.respawnTimer then
			self.respawnTimer = self.respawnTime
		else
			self.respawnTimer = self.respawnTimer - dt
		end
		
		if self.respawnTimer <= 0 then
      deployDrone()
			self.respawnTimer = nil
		end
	end
	
	--Debug
	world.debugText("Time until Respawn: " .. sb.printJson(self.respawnTimer, 1), vec2.add(mcontroller.position(), {-5, 0}), "red")
	world.debugText("Drones active: " .. sb.printJson(#self.droneIds, 1), vec2.add(mcontroller.position(), {-5, 2}), "red")
	world.debugText("Drone movement type: " .. sb.printJson(self.droneParameters.movementMode, 1), vec2.add(mcontroller.position(), {-5, 3}), "red")
end

--Deploy the drones
function deployDrone()
	self.droneCount = self.droneMax - (#self.droneIds or 0)
	
	if not self.droneParameters.movementMode then
		self.droneParameters.movementMode = "Orbit"
	end
  self.droneParameters.parentEntity = entity.id()
  self.droneParameters.initialVelocity = mcontroller.velocity()

  for i = 1, self.droneCount do
		local insPos = 1
		if self.droneParameters.movementMode == "Orbit" then
			if #self.droneIds > 0 then
				local currentAngles = droneAngles(#self.droneIds)
				local deployAngle = vec2.angle(mcontroller.position())
				local bestDiff = 8

				for i, angle in ipairs(currentAngles) do
					local diff = util.angleDiff(angle, deployAngle)
					if math.abs(diff) < bestDiff then
						bestDiff = math.abs(diff)
						insPos = i
						if diff < 0 then
							insPos = i
						else
							insPos = i + 1
						end
					end
				end
			else
				
			end
		end

		local targetOffset = {self.droneOrbitDistance, 0}
		targetOffset[1] = targetOffset[1] * mcontroller.facingDirection()
		self.droneParameters.targetOffset = targetOffset

		local droneId = world.spawnMonster(self.droneType, mcontroller.position(), self.droneParameters)
		table.insert(self.droneIds, insPos, droneId)
	end
end

--Update drones, to ensure they behave correctly
function updateDrones()
  self.droneIds = util.filter(self.droneIds, function(dId)
		if world.entityExists(dId) then
			return true
		end
		return false
	end)

  if self.droneOrbitRate and #self.droneIds > 0 then
    self.droneOrbitAngle = util.wrapAngle(self.droneOrbitAngle + self.droneOrbitRate * script.updateDt())
    local angles = droneAngles(#self.droneIds)
    for i, angle in ipairs(angles) do
      local targetOffset = vec2.rotate({self.droneOrbitDistance, 0}, angle)
      world.sendEntityMessage(self.droneIds[i], "setTargetOffset", targetOffset)
    end
  end
end

--Calculate Angles for the drones to spawn
function droneAngles(droneCount)
  if droneCount <= 1 then
    return {self.droneOrbitAngle}
  end

  local interval = (math.pi * 2) / droneCount
  local angle = self.droneOrbitAngle
  local angles = {}
  while #angles < droneCount do
    table.insert(angles, angle)
    angle = angle + interval
  end
  return angles
end

function uninit()
	--Cull drones upon removal of status
  for _, drone in ipairs(self.droneIds) do
		world.sendEntityMessage(drone, "despawn")
	end
end
