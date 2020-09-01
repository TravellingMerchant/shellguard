require "/scripts/vec2.lua"
require "/scripts/util.lua"
require "/scripts/poly.lua"

function init()
	self.autopilot = config.getParameter("autopilot",false)
	self.autopilotInitial = self.autopilot
	self.commander = config.getParameter("commander")
	if self.autopilot then
		self.outOfSight = {}
		self.wallhacks = false
		self.targets = {}
		self.queryRange = config.getParameter("queryRange", 100)
		self.keepTargetInRange = config.getParameter("keepTargetInRange", 200)
		self.baseAutopilotBottomCheck = {{-4.5,-6.5},{-4,-4},{4,-4},{4.5,-6.5}}
		self.autopilotBottomCheck = copy(self.baseAutopilotBottomCheck)
		self.baseAutopilotTopCheck = {{-3.5,3},{-3.5,2},{3.5,2},{3.5,3}}
		self.autopilotTopCheck = copy(self.baseAutopilotTopCheck)
	end

	pcall(require,config.getParameter("boosterScript"))
	if boosterInit then
		boosterInit()
	end
	pcall(require,config.getParameter("meleeScript"))
	if meleeInit then
		meleeInit()
	end
	animator.setGlobalTag("paletteSwaps",config.getParameter("colorSwaps"))
	animator.setGlobalTag("globalDirectives","?setcolor=FFFFFF?border=2;FF0000CC;FF000055")
	self.gunnery = config.getParameter("gunnery")
	if self.gunnery then
		for seat,arsenal in pairs(self.gunnery) do
			for arsenalTrigger,subarsenal in pairs(arsenal) do
				for gunName,gun in pairs(subarsenal) do
					gun.cooldown = gun.initialCooldown or gun.fireTime
					gun.activeCooldown = 0
					gun.weakActiveCooldown = 0
					gun.aimAngle = gun.emptyAim or 0
					if gun.chain ~= nil then
						gun.chain.sourcePart = gunName
					end
					if gun.burstCount then
						gun.burstTracker = 1
					end
				end
			end
		end
	end
	self.fadeOutTimer = 0
	self.lastMajorFadeout = 0
	self.facingDirection = config.getParameter("spawnFacingDirection",1)
	self.angle = 0
	self.protection = config.getParameter("protection",25)
	self.maxHealth = config.getParameter("maxHealth",0)
	
	--this comes in from the controller.
	self.ownerKey = config.getParameter("ownerKey")
	vehicle.setPersistent(self.ownerKey)
	
	--assume maxhealth
	if not (storage.health) then
		local startHealthFactor = config.getParameter("startHealthFactor")

		if (startHealthFactor == nil) then
			storage.health = self.maxHealth
		else
			storage.health = math.min(startHealthFactor * self.maxHealth, self.maxHealth)
		end
		animator.setAnimationState("movement", "warpInPart1")
	end

	--setup the store functionality
	message.setHandler("store",
			function(_, _, ownerKey)
				if self.deployTimer < 0 and (self.ownerKey and self.ownerKey == ownerKey and self.driver == nil) then
					animator.playSound("returnvehicle")
					self.fadeOut = true
					return {storable = true, healthFactor = storage.health / self.maxHealth}
				else
					return {storable = false, healthFactor = storage.health / self.maxHealth}
				end
			end)
			
	--setup the kms functionality
	message.setHandler("terminateSelf",
			function(_,_)
				animator.setAnimationState("movement", "warpOutPart1")
				animator.playSound("returnvehicle")
				vehicle.destroy()
			end)
			
	self.materialKind = config.getParameter("materialKind")
	self.powerJump = false
	self.crouchTimer = 0
	self.hasJumpSounded = 0
	self.size = config.getParameter("size",1)
	legScale = {self.size,self.size}
	self.upperLegLength = config.getParameter("upperLegLength",6)*self.size
	self.lowerLegLength = config.getParameter("lowerLegLength",7.5)*self.size
	self.legOverreach = math.abs(self.upperLegLength - self.lowerLegLength)+1
	self.maxExtension = config.getParameter("maxExtensionMultiplier",1)*(self.lowerLegLength+self.upperLegLength)
	self.vertEquilibrium = config.getParameter("vertEquilibrium",6)*self.size
	self.baseHorizForce = config.getParameter("baseHorizForce",14)
	self.movesLast = {["up"] = false, ["down"] = false, ["left"] = false, ["right"] = false, ["jump"] = false, ["special1"] = false, ["special2"] = false, ["special3"] = false}
	self.legAttacking = false
	self.movementDirection = "none"
	self.manualVertForce = 0
	self.chassisMotion = {0,0}
	self.dt = script.updateDt()
	self.storedPointsForLegShockwave = {}
	self.deployTimer = 2
	self.lastMajorDeploy = self.deployTimer
	self.deactivateTimer = 0
	self.tileDamageBlacklist = {}
	self.selfDamageNotifications = {}
	self.angle = 0
	self.powerJumpForce = config.getParameter("powerJumpForce",{0,6.5})
	self.standardJumpForce = config.getParameter("standardJumpForce",{0,3.5})
	self.swimForce = config.getParameter("swimForce",{0,2.5})
	self.legLocks = {
	["lB"] = false,
	["lF"] = false,
	["rB"] = false,
	["rF"] = false,
	["any"] = false
	}
	self.baseLegFromGroundJoints = {
	["lB"] = {-2.25, self.vertEquilibrium},
	["lF"] = {-2.25, self.vertEquilibrium-1.25},
	["rB"] = {2.5, self.vertEquilibrium},
	["rF"] = {2.5, self.vertEquilibrium-1.25}
	--[[["lB"] = {-2, self.vertEquilibrium},
	["lF"] = {-4, self.vertEquilibrium},
	["rB"] = {2, self.vertEquilibrium},
	["rF"] = {4, self.vertEquilibrium}]]
	}
	self.baseLegFallPositions = config.getParameter("baseLegFallPositions",{
	["lB"] = {-2.5,-1*self.maxExtension},
	["lF"] = {-5,-1*self.maxExtension},
	["rB"] = {2.5,-1*self.maxExtension},
	["rF"] = {5,-1*self.maxExtension}
	})
	self.baseLegStepZones = config.getParameter("baseLegStepZones",{
	["lB"] = {-22,0},
	["lF"] = {-22,0},
	["rB"] = {0,22},
	["rF"] = {0,22}
	})
	self.baseLegSeeds = {
	["lB"] = -5,
	["lF"] = -15,
	["rB"] = 5,
	["rF"] = 15
	}
	self.legColors = {
	["lB"] = {160,0,0,255},
	["lF"] = {255,0,0,255},
	["rB"] = {0,0,160,255},
	["rF"] = {0,0,255,255}
	}
	self.legs = config.getParameter("legs",{"lB", "rB", "lF", "rF"})
	self.legPairs = config.getParameter("legPairs",{
	["lB"] = "lF",
	["lF"] = "lB",
	["rB"] = "rF",
	["rF"] = "rB"
	})
	--status: anchor, leg state(falling, stable, moving, searching, attackReady, attacking), current stack, search cooldown
	self.legStatus = {}
	for i, leg in ipairs(self.legs) do
		self.legStatus[leg] = {["anchor"] = "none", ["state"] = "falling", ["stack"] = {}, ["cd"] = 0}
	end
	self.baseChassisOffsets = config.getParameter("baseChassisOffsets",{
	["lB"] = {-3, -4.5},
	["lF"] = {-3, -4.75},
	["rB"] = {3,-4.5},
	["rF"] = {3,-4.75}
	})
	self.chassisOffsets = copy(self.baseChassisOffsets)
	self.legFallPositions = copy(self.baseLegFallPositions) 
	self.legFromGroundJoints = copy(self.baseLegFromGroundJoints)
	self.legStepZones = copy(self.baseLegStepZones)
	self.legSeeds = copy(self.baseLegSeeds)
	self.checkPolyParam = config.getParameter("checkPolyParam",{13,16,1.0,1.2,21})
	self.landingPoly = config.getParameter("landingPoly",{{-0.75, -18}, {0.75, -18}, {0.75, 0}, {-0.75, 0}})
	self.baseCheckPolySweepL = {}
	self.baseCheckPolySweepR = {}
	self.baseCheckPolyRec = {}
	self.checkPolySweepL ={}
	self.checkPolySweepR ={}
	self.checkPolyRec = {}
	self.checkPolyAnchor = config.getParameter("checkPolyAnchor",{{0,0.25},{-0.25,0},{0,-0.5},{0.25,0}})
	self.chassisForce = config.getParameter("chassisForce",{120,300})
	local checkRadius = self.maxExtension - self.checkPolyParam[3]
	local checkAngle = math.pi/6 + 1*(math.pi/self.checkPolyParam[5])
	local checkNode1 = vec2.rotate( vec2.mul( {0,1} , checkRadius) , checkAngle)
	local checkNode2 = {0,0}
	table.insert(self.checkPolySweepL, checkNode1)
	for i = 1, self.checkPolyParam[2] do
		checkAngle = math.pi/6 + i*(math.pi/self.checkPolyParam[5])
		checkNode1 = vec2.rotate( vec2.mul( {0,1} , checkRadius) , checkAngle)
		checkAngle = math.pi/6 + (i+1)*(math.pi/self.checkPolyParam[5])
		checkNode2 = vec2.rotate( vec2.mul( {0,1} , checkRadius) , checkAngle)
		table.insert(self.checkPolySweepL, checkNode2)
	end
	--Inner edge
	checkRadius = self.maxExtension - self.checkPolyParam[3] * self.checkPolyParam[1]
	checkAngle = math.pi/6 + (self.checkPolyParam[2]+1)*(math.pi/self.checkPolyParam[5])
	checkNode1 = {0,0}
	checkNode2 = vec2.rotate( vec2.mul( {0,1} , checkRadius) , checkAngle)
	table.insert(self.checkPolySweepL, checkNode2)
	for i = self.checkPolyParam[2], 1, -1 do
		checkAngle = math.pi/6 + i*(math.pi/self.checkPolyParam[5])
		checkNode1 = vec2.rotate( vec2.mul( {0,1} , checkRadius) , checkAngle)
		checkAngle = math.pi/6 + (i+1)*(math.pi/self.checkPolyParam[5])
		checkNode2 = vec2.rotate( vec2.mul( {0,1} , checkRadius) , checkAngle)
		table.insert(self.checkPolySweepL, checkNode1)
	end
	--Right poly is reflection of left
	for _,node in ipairs(self.checkPolySweepL) do
		table.insert(self.checkPolySweepR, {-node[1], node[2]})
	end
	
	--Rectangular Poly
	table.insert(self.checkPolyRec, {-(self.checkPolyParam[1]-1)/2, 1-self.checkPolyParam[4]})
	table.insert(self.checkPolyRec, {(self.checkPolyParam[1]-1)/2, 1-self.checkPolyParam[4]})
	table.insert(self.checkPolyRec, {(self.checkPolyParam[1]-1)/2, 1-self.checkPolyParam[4]*self.checkPolyParam[2]})
	table.insert(self.checkPolyRec, {-(self.checkPolyParam[1]-1)/2, 1-self.checkPolyParam[4]*self.checkPolyParam[2]})

	for _,node in ipairs(self.checkPolySweepL) do
		table.insert(self.baseCheckPolySweepL, node)
	end
	for _,node in ipairs(self.checkPolySweepR) do
		table.insert(self.baseCheckPolySweepR, node)
	end
	for _,node in ipairs(self.checkPolyRec) do
		table.insert(self.baseCheckPolyRec, node)
	end
end

function update(args)
	mainLoop(args)
	updateAnchors()
	updateMotion(args)
	updateGuns()
	renderLegs()
	boosters()
	meleeLoop()
end

function boosters()
end

function meleeLoop()
end

function updateGuns()
	if self.gunnery then
		for seat,arsenal in pairs(self.gunnery) do
			self.Special1Held = vehicle.controlHeld(seat,"Special1")
			self[seat.."Entity"] = vehicle.entityLoungingIn(seat)
			for arsenalTrigger,subarsenal in pairs(arsenal) do
				for gunName,gun in pairs(subarsenal) do
					if gun.activeMelee then
						vehicle.setDamageSourceEnabled(gun.activeMelee,false)
					end
					gun.cooldown = math.max(gun.cooldown - script.updateDt(),0)
					if gun.firingType == "laser" then	
						gun.activeCooldown = math.max(gun.activeCooldown - script.updateDt(),0)
						if gun.activeCooldown == 0 then
							gun.weakActiveCooldown = math.max(gun.weakActiveCooldown - script.updateDt(),0)
							for i,damageSource in ipairs(gun.damageSourceList) do
								vehicle.setDamageSourceEnabled(damageSource,false)
							end
							if not gun.weakChain or gun.weakActiveCooldown == 0 then
								vehicle.setAnimationParameter("chains", {})
							else
								local chains = {}
								table.insert(chains, gun.weakChain)
								vehicle.setAnimationParameter("chains", chains)
							end
						elseif self[seat.."Entity"] then
							local chains = {}
							table.insert(chains, gun.chain)
							vehicle.setAnimationParameter("chains", chains)
						end
					end
					if not (self.Special1Held and gun.special1AimLock) then
						if self.autopilot and self.target and world.entityExists(self.target) then
							aimOffset = world.distance(world.entityPosition(self.target),vec2.add(mcontroller.position(),vec2.rotate(vec2.mul(gun.gunCenter,{self.facingDirection,1}),self.angle)))
							gun.aimAngle = math.atan(aimOffset[2],aimOffset[1]) - self.angle
						elseif self[seat.."Entity"] then
							aimOffset = world.distance(vehicle.aimPosition(seat),vec2.add(mcontroller.position(),vec2.rotate(vec2.mul(gun.gunCenter,{self.facingDirection,1}),self.angle)))
							gun.aimAngle = math.atan(aimOffset[2],aimOffset[1]) - self.angle
						elseif gun.emptyAim then
							gun.aimAngle = self.facingDirection > 0 and gun.emptyAim/180*math.pi or util.wrapAngle(-gun.emptyAim/180*math.pi-math.pi)
						else
							gun.aimAngle = 0
						end
					end
					if gun.slavedTo then
						gun.aimAngle = subarsenal[gun.slavedTo].aimAngle or gun.aimAngle or 0
					elseif gun.aimMinMax then
						if self.facingDirection > 0 then
							gun.aimAngle = util.clamp(gun.aimAngle,(gun.aimMinMax[1]-self.angle)/180*math.pi,(gun.aimMinMax[2]-self.angle)/180*math.pi)
						else
							gun.aimAngle = util.clamp(util.wrapAngle(gun.aimAngle),util.wrapAngle(-math.pi-(gun.aimMinMax[2]-self.angle)/180*math.pi),util.wrapAngle(-math.pi-(gun.aimMinMax[1]-self.angle)/180*math.pi))
						end
					end
					if gun.slaves then
						for i,slave in ipairs(gun.slaves) do
							subarsenal[slave].aimAngle = gun.aimAngle
						end
					end
					if not gun.noGroup and not (gun.laserRotationLock and (gun.activeCooldown > 0 or gun.weakActiveCooldown > 0)) then
						animator.resetTransformationGroup(gun.gunName or gunName)
						animator.rotateTransformationGroup(gun.gunName or gunName,(gun.aimAngle-0.5*math.pi)*self.facingDirection+0.5*math.pi,gun.gunCenter)
					end
					if gun.burstTracker and gun.burstTracker > 1 then
						fireSubarsenal(seat,subarsenal,gunName,gun,true)
					end
				end
			end
		end
	end
	if self.gunnery then
		for seat,arsenal in pairs(self.gunnery) do
			for arsenalTrigger,subarsenal in pairs(arsenal) do
				if (self.autopilot and self.target and world.entityExists(self.target)) or (vehicle.controlHeld(seat, arsenalTrigger)) then
					for gunName,gun in pairs(subarsenal) do
						fireSubarsenal(seat,subarsenal,gunName,gun,gun.punishSlaves)
						if gun.activeMelee then
							vehicle.setDamageSourceEnabled(gun.activeMelee,true)
						end
					end
				end
			end
		end
		for seat,arsenal in pairs(self.gunnery) do
			for arsenalTrigger,subarsenal in pairs(arsenal) do
				if (self.autopilot and self.target and world.entityExists(self.target)) or (vehicle.controlHeld(seat, arsenalTrigger)) then
					for gunName,gun in pairs(subarsenal) do
						fireSubarsenal(seat,subarsenal,gunName,gun,not gun.punishSlaves)
					end
				end
			end
		end
	end
end

function applyDamage(damageRequest)
	local damage = 0
	if damageRequest.damageType == "Damage" then
		damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
	elseif damageRequest.damageType == "IgnoresDef" then
		damage = damage + damageRequest.damage
	else
		return {}
	end

	local healthLost = math.min(damage, storage.health)
	storage.health = storage.health - healthLost

	return {{
		sourceEntityId = damageRequest.sourceEntityId,
		targetEntityId = entity.id(),
		position = mcontroller.position(),
		damageDealt = damage,
		healthLost = healthLost,
		hitType = "Hit",
		damageSourceKind = damageRequest.damageSourceKind,
		targetMaterialKind = self.materialKind,
		killed = storage.health <= 0
	}}
end

function selfDamageNotifications()
	local sdn = self.selfDamageNotifications
	self.selfDamageNotifications = {}
	return sdn
end

function fireProjectile(projectileType, projectileParams, inaccuracy, firePosition, projectileCount, cooldown, aimAngle)
	local params = sb.jsonMerge(self.projectileParameters, projectileParams or {})
	params.speed = util.randomInRange(params.speed)

	if not projectileType then
		projectileType = self.projectileType
	end
	if type(projectileType) == "table" then
		projectileType = projectileType[math.random(#projectileType)]
	end
	
	local projectileId = 0
	for i = 1, (projectileCount or self.projectileCount) do
		if params.timeToLive then
			params.timeToLive = util.randomInRange(params.timeToLive)
		end
	
		if params.speedInaccuracy then
			params.speed = math.max(0,(params.speed or root.projectileConfig(projectileType).speed) + sb.nrand(params.speedInaccuracy, 0))
		end
	
		if params.timeInaccuracy then
			params.timeToLive = math.max(0,(params.timeToLive or root.projectileConfig(projectileType).timeToLive)+sb.nrand(params.timeInaccuracy, 0))
		end
	
		projectileId = world.spawnProjectile(
				projectileType,
				firePosition,
				entity.id(),
				aimVector(inaccuracy or self.inaccuracy or 0,aimAngle),
				false,
				params
			)
	end
	self.cooldown = cooldown
	return projectileId
end

function aimVector(inaccuracy,aimAngle)
	local aimVector = vec2.rotate({1, 0}, aimAngle + sb.nrand(inaccuracy, 0))
	return aimVector
end

function fireSubarsenal(seat,subarsenal,gunName,gun,condition)
	if gun.cooldown == 0 and condition then
		gun.projectileParams = gun.projectileParams or {}
		local gunCenter = vec2.add(mcontroller.position(),vec2.rotate(vec2.mul(gun.gunCenter,{self.facingDirection,1}),self.angle))
		local gunTip = vec2.add(gunCenter,vec2.rotate({gun.gunLength,0},gun.aimAngle+self.angle))
		local baseOffset = {0,0}
		if gun.burstTracker and gun.burstOffsets then
			baseOffset = gun.burstOffsets[gun.burstTracker]
		end
		if gun.firingType == "flak" then
			local speed = gun.projectileParams.speed or root.projectileConfig(gun.projectileType).speed
			gun.projectileParams.timeToLive = world.magnitude(gunTip,(self.autopilot and self.target and world.entityExists(self.target) and world.entityPosition(self.target)) or vehicle.aimPosition(seat)) / speed
		end
		if gun.firingType == "laser" and gun.activeCooldown == 0 then
			gun.activeCooldown = gun.activeTime
			gun.cooldown = gun.fireTime
			gun.weakActiveCooldown = gun.weakActiveTime or 0
			for i,damageSource in ipairs(gun.damageSourceList) do
				vehicle.setDamageSourceEnabled(damageSource,true)
			end
		elseif gun.firingType ~= "laser" then
			if gun.barrels then
				for barrelI,barrelOffset in ipairs(gun.barrels) do
					fireProjectile(gun.projectileType,gun.projectileParams,gun.inaccuracy,vec2.add(gunTip,vec2.rotate(vec2.mul(vec2.add(barrelOffset,baseOffset),{1,self.facingDirection}),gun.aimAngle+self.angle)),gun.projectileCount,gun.fireTime,util.wrapAngle(gun.aimAngle+self.angle))
				end
			else
				fireProjectile(gun.projectileType,gun.projectileParams,gun.inaccuracy,vec2.add(gunTip,vec2.rotate(vec2.mul(baseOffset,{1,self.facingDirection}),gun.aimAngle+self.angle)),gun.projectileCount,gun.fireTime,util.wrapAngle(gun.aimAngle+self.angle))
			end
			gun.cooldown = gun.fireTime
		end
		if gun.punishSlaves then
			for slave,punishment in pairs(gun.punishSlaves) do
				if subarsenal[slave] then
					subarsenal[slave].cooldown = punishment
				else
					for slaveName,slaveGun in pairs(subarsenal) do
						if slaveGun.gunName == slave then
							slaveGun.cooldown = punishment
						end
					end
				end
			end
		end
		if gun.playSounds and not (gun.singleSoundBurst and gun.burstTracker and gun.burstTracker > 1) then
			for i,sound in ipairs(gun.playSounds) do
				animator.playSound(sound)
			end
		end
		if gun.kickback then
			mcontroller.addMomentum(vec2.rotate(gun.kickback,vec2.angle(world.distance(gunTip,gunCenter))))
		end
		if gun.setAnimationStates then
			for animation,state in pairs(gun.setAnimationStates) do
				animator.setAnimationState(animation,type(state) == "table" and state[1] or state,type(state) == "table" and state[2] or false)
			end
		end
		if gun.burstCount then
			if gun.burstTracker < gun.burstCount then
				gun.cooldown = gun.burstTime
				gun.burstTracker = gun.burstTracker + 1
			else
				gun.burstTracker = 1
			end
		end
	end
end

function rotateChassisTables()
	if self.autopilot then
		for i,j in pairs(self.autopilotBottomCheck) do
			self.autopilotBottomCheck[i] = vec2.rotate(self.baseAutopilotBottomCheck[i], self.angle)
		end
		for i,j in pairs(self.autopilotTopCheck) do
			self.autopilotTopCheck[i] = vec2.rotate(self.baseAutopilotTopCheck[i], self.angle)
		end
	end
	for i,j in pairs(self.chassisOffsets) do
		self.chassisOffsets[i] = vec2.rotate(self.baseChassisOffsets[i], self.angle)
	end
	for i,j in pairs(self.legFallPositions) do
		self.legFallPositions[i] = vec2.rotate(self.baseLegFallPositions[i], self.angle)
	end
	for i,j in pairs(self.legFromGroundJoints) do
		self.legFromGroundJoints[i] = vec2.rotate(self.baseLegFromGroundJoints[i], self.angle)
	end
	
	for i,j in pairs(self.legStepZones) do
		self.legStepZones[i] = {}
		for n,m in pairs(j) do
			self.legStepZones[i][n] = vec2.rotate({self.baseLegStepZones[i][n], -12},self.angle)[1]
		end
	end
	for i,j in pairs(self.legSeeds) do
		self.legSeeds[i] = self.baseLegSeeds[i]*math.cos(self.angle)
	end
	
	for i,j in pairs(self.checkPolySweepL) do
		self.checkPolySweepL[i] = vec2.rotate(self.baseCheckPolySweepL[i], self.angle)
	end
	for i,j in pairs(self.checkPolySweepR) do
		self.checkPolySweepR[i] = vec2.rotate(self.baseCheckPolySweepR[i], self.angle)
	end
	for i,j in pairs(self.checkPolyRec) do
		self.checkPolyRec[i] = vec2.rotate(self.baseCheckPolyRec[i], self.angle)
	end
end

function updateMotion(args)	
	--Calculate the summed suspension force for legs with anchors
	local suspensionForce = {0,0}
	local gravityAdjust = math.min(math.max((world.gravity(mcontroller.position())-80)/10, 0), 4)
	local vertWeights = {}
	local horizWeights = {}
	for _,leg in ipairs(self.legs) do
		local basePos = vec2.add(mcontroller.position(), self.chassisOffsets[leg])
		local currentAnchor = self.legStatus[leg].anchor
		if (self.legStatus[leg].state == "stable" or self.legStatus[leg].state == "moving") and not self.legLocks["any"] then 
			vertWeights[leg] = self.vertEquilibrium - gravityAdjust - world.distance(basePos, currentAnchor)[2]
			horizWeights[leg] = -world.distance(basePos, currentAnchor)[1]
		else
			vertWeights[leg] = nil
			horizWeights[leg] = nil
		end
	end
	
	--determine chassis tilt
	local nullLegAdjust = -9
	local leftVertForce = (vertWeights["lB"] or nullLegAdjust) + (vertWeights["lF"] or nullLegAdjust)
	local rightVertForce = (vertWeights["rB"] or nullLegAdjust) + (vertWeights["rF"] or nullLegAdjust)
	local tiltForce = rightVertForce - leftVertForce
	--self.angle = math.min(math.max(self.angle + tiltForce*0.03*self.dt, -0.2), 0.1)
	self.newAngle = 0.035*tiltForce
	if self.poweringDown then self.newAngle = 0 end
	if self.angle < self.newAngle then
		self.angle = math.min(self.newAngle, self.angle + self.dt*(self.newAngle-self.angle))
	else
		self.angle = math.max(self.newAngle, self.angle - self.dt*(self.angle-self.newAngle))
	end
	--self.angle = self.angle + tiltForce*0.1*self.dt
	rotateChassisTables()
	--animator.resetTransformationGroup("mechBody")
	--animator.rotateTransformationGroup("mechBody", self.angle)
	animator.resetTransformationGroup("flip")
	if self.facingDirection < 0 then
		animator.scaleTransformationGroup("flip", {-1, 1})
	end
	animator.resetTransformationGroup("rotation")
	animator.rotateTransformationGroup("rotation", self.angle)
	mcontroller.setRotation(self.angle)	
	
	--Horizontal movement base
	if self.movementDirection == "left" then
		self.manualHorizForce = -self.baseHorizForce
	elseif self.movementDirection == "right" then
		self.manualHorizForce = self.baseHorizForce
	else
		self.manualHorizForce = 0
	end


	--if one end is unsupported, we are 'falling'
	self.isFalling = false
	for _,leg in pairs(self.legs) do
		if vertWeights[leg] == nil and vertWeights[self.legPairs[leg]] == nil then
			self.isFalling = true 
			break
		end
		suspensionForce[2] = suspensionForce[2] + (vertWeights[leg] or 0)
	end			
	for _,leg in pairs(self.legs) do
		local soloAdjust = 0.2
		if horizWeights[leg] == nil and horizWeights[self.legPairs[leg]] == nil then
			suspensionForce[1] = 0
			break
		elseif horizWeights[leg] ~= nil and horizWeights[self.legPairs[leg]] == nil then
			soloAdjust = 2*soloAdjust
		end
		suspensionForce[1] = suspensionForce[1] + (horizWeights[leg] or 0) * soloAdjust
	end
	if self.isFalling then
		mcontroller.applyParameters({gravityEnabled=true})
	end
	
	self.chassisMotion[1] = suspensionForce[1] + self.manualHorizForce + (self.bossHorizForce or 0)
	self.chassisMotion[2] = suspensionForce[2] + self.manualVertForce + (self.bossVertForce or 0)
	
	local tiltSuspensionMult = 0.10
	if tiltForce*self.chassisMotion[1] < 0 then
		self.chassisMotion[2] = self.chassisMotion[2] + math.max(tiltForce*self.chassisMotion[1]*tiltSuspensionMult, -28)
	end

	world.debugLine(mcontroller.position(), vec2.add(mcontroller.position(), suspensionForce), {255,255,255,255})
	
	if not self.legLocks.any then
		self.chassisMotion = vec2.add(self.chassisMotion, self.recoilForce or {0,0})
		self.recoilForce = {0,0}
		
		if math.abs(self.chassisMotion[1]) < 2 then self.chassisMotion[1] = 0 end
		
		mcontroller.approachXVelocity(self.chassisMotion[1],self.chassisForce[1])
		
		--boosting and falling override the suspension force
		if not self.isFalling then
			if math.abs(self.chassisMotion[2]) < 0.5 then self.chassisMotion[2] = 0 end
		end
		if not self.isJumping and not self.isFalling then
			mcontroller.approachYVelocity(self.chassisMotion[2], self.chassisForce[2])
		end
	end
end


function mainLoop(args)
	if storage.health <= 0 then
		vehicle.destroy()
	end
	
	if self.autopilot then
		if #self.targets == 0 then
			local newTargets = world.entityQuery(mcontroller.position(), self.queryRange, {withoutEntityId = entity.id(), includedTypes = {"vehicle","monster","npc"}})
			table.sort(newTargets, function(a, b)
				return world.magnitude(world.entityPosition(a), mcontroller.position()) < world.magnitude(world.entityPosition(b), mcontroller.position())
			end)
			for _,entityId in pairs(newTargets) do
				if (self.wallhacks or entity.entityInSight(entityId)) and world.entityCanDamage(entity.id(),entityId) then
					table.insert(self.targets, entityId)
				end
			end
		end

		repeat
			self.target = self.targets[1]
			if self.target == nil then break end

			local target = self.target
			if not world.entityExists(target)
				 or world.magnitude(world.entityPosition(target), mcontroller.position()) > self.keepTargetInRange then
				table.remove(self.targets, 1)
				self.target = nil
			end

			if self.target and not (self.wallhacks or entity.entityInSight(target)) then
				local timer = self.outOfSight[target] or 5.0
				timer = timer - self.dt
				if timer <= 0 then
					table.remove(self.targets, 1)
					self.target = nil
				else
					self.outOfSight[target] = timer
				end
			end

			if not self.target then
				self.outOfSight[target] = nil
			end
		until #self.targets <= 0 or self.target
	end
	
	if self.fadeOut then
		self.fadeOutTimer = self.fadeOutTimer + self.dt
		if self.fadeOutTimer - self.lastMajorFadeout >= 0.125 then
			animator.setGlobalTag("globalDirectives","?fade=FFFFFF="..math.min(1,math.max(0,self.fadeOutTimer*2)).."?border=2;FF0000CC;FF000055")
			self.lastMajorFadeout = self.lastMajorFadeout + 0.125
		end
		if self.fadeOutTimer > 0.55 then
			vehicle.destroy()
		end
	end
	
	if self.deployTimer > 0 then
		self.deployTimer = self.deployTimer - self.dt
		if self.deployTimer > 1.5 and self.lastMajorDeploy - self.deployTimer >= 0.125 then
			animator.setGlobalTag("globalDirectives","?fade=FFFFFF="..math.max(0,(self.deployTimer-1.5)*2).."?border=2;FF0000CC;FF000055")
			self.lastMajorDeploy = self.lastMajorDeploy - 0.125
		end
		if self.deployTimer <= 1.5 then
			animator.setGlobalTag("globalDirectives","")
		end
	end

	local driverThisFrame = vehicle.entityLoungingIn("drivingSeat")

	if (driverThisFrame ~= nil) then
		self.autopilot = false
		vehicle.setDamageTeam(world.entityDamageTeam(driverThisFrame))
		if not self.special1ShipFlipLock then
			if world.distance(vehicle.aimPosition("drivingSeat"),mcontroller.position())[1] > 0 then
				self.facingDirection = 1
			else
				self.facingDirection = -1
			end
		end
	elseif self.autopilot and self.commander and world.entityExists(self.commander) then
		vehicle.setDamageTeam(world.entityDamageTeam(self.commander))
	elseif self.autopilotInitial then
		self.autopilot = true
	else
		vehicle.setDamageTeam({type = "passive"})
	end
	--Basic activation mechanism
	if not vehicle.controlHeld("drivingSeat","primaryFire") and vec2.mag(world.distance(vehicle.aimPosition("drivingSeat"), mcontroller.position())) <= 1.5 then 
		self.flashlightHighlight = true
	elseif not vehicle.controlHeld("drivingSeat","primaryFire") then
		self.flashlightHighlight = false
	end
	if not self.autopilot then
		if self.directionLock == -1 or (vehicle.controlHeld("drivingSeat","left") and not vehicle.controlHeld("drivingSeat","right")) then
			self.movementDirection = "left"
		elseif self.directionLock == 1 or (vehicle.controlHeld("drivingSeat","right") and not vehicle.controlHeld("drivingSeat","left")) then
			self.movementDirection = "right"
		else
			self.movementDirection = "none"
		end
	elseif self.target and world.entityExists(self.target) then
		self.targetPosition = world.entityPosition(self.target)
		local myPos = mcontroller.position()
		local targetDistance = world.distance(myPos,self.targetPosition)
		if targetDistance[1] > 20 then
			self.movementDirection = "left"
			self.facingDirection = -1
		elseif targetDistance[1] < -20 then
			self.movementDirection = "right"
			self.facingDirection = 1
		elseif targetDistance[1] < 0 then
			self.movementDirection = "none"
			self.facingDirection = 1
		else
			self.movementDirection = "none"
			self.facingDirection = -1
		end
	elseif self.commander and world.entityExists(self.commander) then
		self.commanderPosition = world.entityPosition(self.commander)
		local myPos = mcontroller.position()
		local targetDistance = world.distance(myPos,self.commanderPosition)
		if targetDistance[1] > 0.75 then
			self.movementDirection = "left"
			self.facingDirection = -1
		elseif targetDistance[1] < -0.75 then
			self.movementDirection = "right"
			self.facingDirection = 1
		else
			self.movementDirection = "none"
		end
	else
		self.movementDirection = "none"
	end
	
	self.isCrouching = false
	if not self.autopilot then
		if vehicle.controlHeld("drivingSeat","up") and not vehicle.controlHeld("drivingSeat","down") then
			if self.crouchTimer > 0 then
				self.crouchTimer = 0
				animator.stopAllSounds("jumpCharge")
			end
			self.crouchTimer = self.crouchTimer - self.dt
			if self.crouchTimer < -1 and self.powerJump and not self.isJumping then
				self.powerJump = false
			end
			self.manualVertForce = self.vertEquilibrium * 2
			if world.liquidAt(mcontroller.position()) then
				mcontroller.addMomentum(self.swimForce)
			end
		elseif vehicle.controlHeld("drivingSeat","down") and not vehicle.controlHeld("drivingSeat","up") and not self.isFalling then
			self.manualVertForce = self.vertEquilibrium * -2
			self.isCrouching = true
			if self.crouchTimer <= 0 then
				self.crouchTimer = 0
				animator.playSound("jumpCharge")
			end
			if self.crouchTimer >= 2.2 then
				self.powerJump = true
			end
			self.crouchTimer = self.crouchTimer + self.dt
		else
			self.manualVertForce = 0
			if self.crouchTimer > 0 then
				self.crouchTimer = 0
				animator.stopAllSounds("jumpCharge")
			end
			self.crouchTimer = self.crouchTimer - self.dt
			if self.crouchTimer < -1 and self.powerJump and not self.isJumping then
				self.powerJump = false
			end
		end
	elseif self.target or self.commander then
		if world.polyCollision(self.autopilotTopCheck,mcontroller.position(),{"Null", "Block", "Dynamic"}) and not self.isFalling then
			self.manualVertForce = self.vertEquilibrium * -2
			self.isCrouching = true
			if self.crouchTimer <= 0 then
				self.crouchTimer = 0
			end
			if self.crouchTimer >= 2.2 then
				self.powerJump = true
			end
			self.crouchTimer = self.crouchTimer + self.dt
		elseif world.polyCollision(self.autopilotBottomCheck,mcontroller.position(),{"Null", "Block", "Dynamic"}) then
			if self.crouchTimer > 0 then
				self.crouchTimer = 0
			end
			self.crouchTimer = self.crouchTimer - self.dt
			if self.crouchTimer < -1 and self.powerJump and not self.isJumping then
				self.powerJump = false
			end
			self.manualVertForce = self.vertEquilibrium * 2
			if world.liquidAt(mcontroller.position()) then
				mcontroller.addMomentum(self.swimForce)
			end
		else
			self.manualVertForce = 0
			if self.crouchTimer > 0 then
				self.crouchTimer = 0
			end
			self.crouchTimer = self.crouchTimer - self.dt
			if self.crouchTimer < -1 and self.powerJump and not self.isJumping then
				self.powerJump = false
			end
		end
	else
		self.manualVertForce = 0
		if self.crouchTimer > 0 then
			self.crouchTimer = 0
			animator.stopAllSounds("jumpCharge")
		end
		self.crouchTimer = self.crouchTimer - self.dt
		if self.crouchTimer < -1 and self.powerJump and not self.isJumping then
			self.powerJump = false
		end
	end
	
	if vehicle.controlHeld("drivingSeat","jump") and not self.isFalling then
		self.isJumping = true
		if self.hasJumpSounded == 0 then
			animator.playSound("jump")
			self.hasJumpSounded = 1
		end
		if self.powerJump then
			mcontroller.addMomentum(vec2.rotate(self.powerJumpForce,self.angle))
			self.powerJump = true
		else
			mcontroller.addMomentum(vec2.rotate(self.standardJumpForce,self.angle))
		end
	else
		self.hasJumpSounded = math.max(self.hasJumpSounded - self.dt,0)
		self.isJumping = false
	end
end

function smackImpactPoint(point)
		if mcontroller.yVelocity() < -20 then
	world.spawnProjectile("sgcrabfootstep", vec2.add(point, {0, 0.5}), entity.id(), {0,0}, false, {
		periodicActions = {{
	action = "actions",
		["repeat"] = false,
		time = 0.01,
	list = {
		{
			action = "loop",
			count = 8,
			body = {
				{
					action = "spark"
				}
		}
		},
		{
			action = "projectile",
			inheritDamageFactor = 0.1,
			type = "sgcrabshrapnelblastsmall",
			fuzzAngle = 360
		},
		{
			action = "sound",
			--options = { "/vehicles/wfsystem/wfcrabmech/heavyfootsteptest.ogg" }
		options = { "/sfx/crabmech/footsteps/sgspiderjumpheavylanding.ogg" }

	},
		{
			action = "explosion",
			foregroundRadius = 3,
			backgroundRadius = 2,
			explosiveDamageAmount = 0.5,
			delaySteps = 2
		}
	}}}, power = 5})
	else
	world.spawnProjectile("sgcrabfootstep", vec2.add(point, {0, 0.5}), entity.id(), {0,0}, false, {
		periodicActions = {{
	action = "actions",
		["repeat"] = false,
		time = 0.01,
	list = {
		{
			action = "loop",
			count = 8,
			body = {
				{
					action = "spark"
				}
		}
		},
		{
			action = "sound",
		options = { "/sfx/crabmech/footsteps/sgspiderstep1.ogg", "/sfx/crabmech/footsteps/sgspiderstep2.ogg", "/sfx/crabmech/footsteps/sgspiderstep3.ogg", "/sfx/crabmech/footsteps/sgspiderstep4.ogg" }

	},
		{
			action = "explosion",
			foregroundRadius = 1,
			backgroundRadius = 0,
			explosiveDamageAmount = 0.5,
			delaySteps = 2
		}
	}}}, power = 5})
	end
end

function checkPoly(poly, center, solidOnly)
	if not solidOnly then
		return world.polyCollision(poly, center, {"Null", "Block", "Dynamic", "Platform"})
	else
		return world.polyCollision(poly, center, {"Null", "Block", "Dynamic"})
	end
end

function updateAnchors(onGround)
	--sb.logInfo("updateAnchors() begin")
	for _,leg in ipairs(self.legs) do
		local currentAnchor = self.legStatus[leg].anchor
		local basePos = vec2.add(mcontroller.position(), self.chassisOffsets[leg])
		--just a quick adjustment for when firing up
		if onGround then
			basePos = vec2.add(mcontroller.position(), legFromGroundJoints[leg])
		end
		local checkParameters = self.checkPolyParam
		local newAnchor = nil
		local checkDirection = self.movementDirection
		local legDirection = "none"
		if string.sub(leg, 1, 1) == "l" then legDirection = "left" 
		elseif string.sub(leg, 1, 1) == "r" then legDirection = "right" end
		--many possible conditions to force an anchor change! 
		if isLegReadyToSearch(leg) and not self.legLocks[leg] then
			if self.legStatus[leg].state == "searching" or
			 self.legStatus[leg].state == "falling" or 
			 self.legStatus[leg].state == "attacking" or
			 type(self.legStatus[leg].anchor) ~= "table" or
			 vec2.mag(world.distance(basePos, currentAnchor)) > self.maxExtension or
			 not checkPoly(self.checkPolyAnchor, currentAnchor, self.isCrouching) or
			 (self.legStepZones[leg][1] > world.distance(currentAnchor, basePos)[1]) or
			 (self.legStepZones[leg][2] < world.distance(currentAnchor, basePos)[1]) or
			 vec2.mag(vec2.sub(currentAnchor, basePos)) <= self.legOverreach or
			 not renderLeg(leg, currentAnchor, false, true) then
				--first make sure there is something in the region
				if (legDirection == "left" and checkDirection == "left" and checkPoly(self.checkPolySweepL, basePos, false)) or
				 (legDirection == "right" and checkDirection == "right" and checkPoly(self.checkPolySweepR, basePos, false)) or
				 (legDirection == "left" and checkDirection == "right" and checkPoly(self.checkPolyRec, vec2.add(basePos, vec2.rotate({-math.ceil(checkParameters[1]/2), 0}, self.angle)), false)) or
				 (legDirection == "right" and checkDirection == "left" and checkPoly(self.checkPolyRec, vec2.add(basePos, vec2.rotate({math.ceil(checkParameters[1]/2), 0},self.angle)), false)) or 
				 (checkDirection == "none" and checkPoly(self.checkPolyRec, vec2.add(mcontroller.position(), {self.legSeeds[leg],self.chassisOffsets[leg][2]}), false)) then					local checkAngle = 0
					local checkRadius = self.maxExtension
					local checkNode1 = {0,0}
					local checkNode2 = {0,0}			
					--various geometries
					if checkDirection == "left" or checkDirection == "right" then
						for n = 1, checkParameters[1] do
							checkRadius = checkRadius - checkParameters[3]
							for i = 1, checkParameters[2] do
								if checkDirection == legDirection then
									local angleBase = math.pi/6
									local angleIncrement = math.pi/checkParameters[5]
									if self.isCrouching then
										angleBase = math.pi/3
										angleIncrement = (angleIncrement*checkParameters[1] - 1/6)/(angleIncrement*checkParameters[1])*angleIncrement
									end
									if checkDirection == "left" then
										checkAngle = angleBase + i*angleIncrement
									elseif checkDirection == "right" then
										checkAngle = -angleBase - i*angleIncrement
									end
									checkNode1 = vec2.add(basePos, vec2.rotate( vec2.mul( vec2.rotate({0,1},self.angle) , checkRadius) , checkAngle))
									if checkDirection == "left" then
										checkAngle = angleBase + (i+1)*angleIncrement
									elseif checkDirection == "right" then
										checkAngle = -angleBase - (i+1)*angleIncrement
									end
									checkNode2 = vec2.add(basePos, vec2.rotate( vec2.mul( vec2.rotate({0,1},self.angle) , checkRadius) , checkAngle))
								elseif checkDirection == "none" then
									checkNode1 = vec2.rotate(vec2.add(mcontroller.position(), {self.baseLegSeeds[leg]+math.floor(n/2)*((-1)^(n)), 1 - checkParameters[4]*i}),self.angle)
									checkNode2 = vec2.add(checkNode1, vec2.rotate({0, -checkParameters[4]},self.angle))
								elseif checkDirection == "right" and legDirection == "left" then
									checkNode1 = vec2.add(basePos, vec2.rotate({-n, 1 -checkParameters[4]*i},self.angle))
									checkNode2 = vec2.add(basePos, vec2.rotate({-n, 1 -checkParameters[4]*(i+1)},self.angle))
								elseif checkDirection == "left" and legDirection == "right" then
									checkNode1 = vec2.add(basePos, vec2.rotate({n, 1 -checkParameters[4]*i},self.angle))
									checkNode2 = vec2.add(basePos, vec2.rotate({n, 1 -checkParameters[4]*(i+1)},self.angle))
								end
								world.debugLine(checkNode1, checkNode2, {0,200,0,180})
								local checkCollisions = {}
								if self.isCrouching then
									checkCollisions = world.collisionBlocksAlongLine(checkNode1, checkNode2, {"Null", "Block", "Dynamic"}, 1)
								else
									checkCollisions = world.collisionBlocksAlongLine(checkNode1, checkNode2, {"Null", "Block", "Dynamic", "Platform"}, 1)
								end
								if #checkCollisions > 0 and vec2.mag(vec2.sub(vec2.add(checkCollisions[1], {0.5,1}), basePos)) > self.legOverreach then
									local checkCollisions2 = world.collisionBlocksAlongLine(vec2.add(checkCollisions[1],{0.5,1.5}), vec2.add(checkCollisions[1], {0.5, 3.5}), {"Null", "Block", "Dynamic"}, 1)
									if #checkCollisions2 == 0 and 
										renderLeg(leg, vec2.add(checkCollisions[1], {0.5,1}), false, true) and
										(type(self.legStatus[self.legPairs[leg]].anchor) ~= "table" or vec2.mag(world.distance(vec2.add(checkCollisions[1], {0.5,1}), self.legStatus[self.legPairs[leg]].anchor)) >= 5) and
										checkCollisions[1][2] - mcontroller.position()[2] <= 10 then
										newAnchor = vec2.add(checkCollisions[1], {0.5,1})
									end
								end
								if newAnchor ~= nil then break end
							end
							if newAnchor ~= nil then break end
						end
					else
						for n = 1, checkParameters[1] do
							checkNode1 = vec2.add(mcontroller.position(), vec2.rotate({self.baseLegSeeds[leg]+math.floor(n/2)*((-1)^(n)), 1},self.angle))
							checkNode2 = vec2.add(checkNode1, vec2.rotate({0, -checkParameters[4]*checkParameters[2]},self.angle))
							local checkCollisions = {}
							if self.isCrouching then
								checkCollisions = world.collisionBlocksAlongLine(checkNode1, checkNode2, {"Null", "Block", "Dynamic"}, 1)
							else
								checkCollisions = world.collisionBlocksAlongLine(checkNode1, checkNode2, {"Null", "Block", "Dynamic", "Platform"}, 1)
							end
							for _,block in ipairs(checkCollisions) do
								if vec2.mag(vec2.sub(vec2.add(block, {0.5,1}), basePos)) > self.legOverreach and 
									#world.collisionBlocksAlongLine(vec2.add(block,{0.5,1.5}), vec2.add(block, {0.5, 3.5}), {"Null", "Block", "Dynamic"}, 1) == 0 and
									renderLeg(leg, vec2.add(block, {0.5,1}), false, true) and
									(type(self.legStatus[self.legPairs[leg]].anchor) ~= "table" or vec2.mag(world.distance(vec2.add(checkCollisions[1], {0.5,1}), self.legStatus[self.legPairs[leg]].anchor)) >= 5) then
									newAnchor = vec2.add(block, {0.5,1})
								end
								if newAnchor ~= nil then break end
							end
							if newAnchor ~= nil then break end
						end
					end
					if newAnchor ~= nil then
						assignNewAnchor(leg, newAnchor, onGround)
					else
						assignNewAnchor(leg, "none", onGround)
					end
				else
					assignNewAnchor(leg, "none", onGround)
				end
			end
		end
	end
end

function isLegReadyToSearch(leg)
	if self.legStatus[leg].state == "attackReady" then return false end
	if self.legStatus[leg].state == "attacking" and #self.legStatus[leg].stack > 1 then return false end
	if self.legStatus[leg].cd > 0 then
		self.legStatus[leg].cd = self.legStatus[leg].cd - 1
		return false
	elseif self.legStatus[leg].state == "stable" or self.legStatus[leg].state == "moving" then
		return true
	elseif self.legStatus[leg].state == "falling" then
		self.legStatus[leg].cd = 5
		return true
	elseif self.legStatus[leg].state == "searching" then
		self.legStatus[leg].cd = 3
		return true
	else 
		return true
	end
end

function assignNewAnchor(leg, anchor, baseInstant)
	local instant = baseInstant
	local oldPos = self.legStatus[leg].anchor
	if type(oldPos) ~= "table" then
		instant = true
	end
	local fallingPos = vec2.add(vec2.add(mcontroller.position(), self.chassisOffsets[leg]), {self.legSeeds[leg],-self.vertEquilibrium})
	if type(anchor) == "table" then 
		self.legStatus[leg].cd = 0
		if instant then
			self.legStatus[leg].anchor = anchor
			self.legStatus[leg].state = "stable"
			self.legStatus[leg].stack = {}
		else
			self.legStatus[leg].anchor = anchor
			local arc = 0
			local frameFactor = 27 - vec2.mag(mcontroller.velocity())
			if self.legStatus[leg].state == "stable" then
				arc = 4
				frameFactor = math.ceil(1*frameFactor)
			else
				arc = 1
				frameFactor = math.ceil(0.4*frameFactor)
			end
			frameFactor = math.min(math.max(frameFactor, 4), 25)
			makeLegStack(leg, oldPos, anchor, frameFactor, 0, {0, arc}, false)
			self.legStatus[leg].state = "moving"
		end
	else
		if self.isFalling and self.legStatus[leg].state ~= "falling" then
			self.legStatus[leg].state = "falling"
			self.legStatus[leg].cd = math.random(5)
			if instant then
				self.legStatus[leg].anchor = vec2.add(mcontroller.position(), self.legFallPositions[leg])	
				self.legStatus[leg].stack = {self.legFallPositions[leg]}
			else
				makeLegStack(leg, self.legStatus[leg].anchor, self.legFallPositions[leg], 5, 0, {0,0}, true)
			end
		elseif not self.isFalling and self.legStatus[leg].state ~= "searching" then 
			self.legStatus[leg].state = "searching"
			self.legStatus[leg].cd = math.random(3)
			if instant then
				self.legStatus[leg].anchor = vec2.add(vec2.add(mcontroller.position(), self.chassisOffsets[leg]), {self.legSeeds[leg], -self.vertEquilibrium})
				self.legStatus[leg].stack = {}
			else
				self.legStatus[leg].stack = {}
			end
		end
	end
end

function makeLegStack(leg, rawOldPos, rawNewPos, frames, lingerFrames, rawArc, relative)
	--to get from A to B with style
	local newPos = rawNewPos
	local oldPos = rawOldPos
	if relative then
		oldPos = world.distance(rawOldPos, mcontroller.position())
		newPos = rawNewPos
	end
	local newStack = {}
	local newLine = world.distance(newPos, oldPos)
	local arc = {0,0}
	if vec2.mag(rawArc) > 0.4 then
		arc = vec2.mul(rawArc, math.min(vec2.mag(rawArc), vec2.mag(newLine)/2)/vec2.mag(rawArc))
	end
	for i=1,frames do
		local disp = vec2.mul(arc, (1-(1-2*i/frames)^2))
		table.insert(newStack, 1, vec2.add(vec2.add(oldPos ,vec2.mul(newLine , i/frames)), disp))
	end
	if lingerFrames > 0 then
		for i=1,lingerFrames do
			table.insert(newStack, 1, newPos)
		end
	end
	self.legStatus[leg].stack = newStack
end

function renderLegs()
	--different legs doing different things
	--sb.logInfo("States: %s, %s, %s, %s", self.legStatus[legs[1]].state,self.legStatus[legs[2]].state,self.legStatus[legs[3]].state,self.legStatus[legs[4]].state)
	for _,leg in ipairs(self.legs) do
		if storage.isWarpingOut then
			if #self.legStatus[leg].stack > 0 then 
				--sb.logInfo("I am leg stack! %s, %s", leg, self.legStatus[leg].stack)
				renderLeg(leg, vec2.add( mcontroller.position(), table.remove(self.legStatus[leg].stack)), false, false, true)
			end
		elseif self.legLocks[leg] then
		elseif self.legStatus[leg].state == "stable" then 
			--"stable" legs are stable
			renderLeg(leg, self.legStatus[leg].anchor)
		elseif self.legStatus[leg].state == "falling" or self.legStatus[leg].state == "attackReady" then
			--"falling" legs should head to their base root points and wait there
			if #self.legStatus[leg].stack > 1 then
				self.legStatus[leg].anchor = vec2.add(table.remove(self.legStatus[leg].stack), mcontroller.position())
			else
				if vec2.mag(world.distance(self.legStatus[leg].stack[1], self.legFallPositions[leg])) > 1 then
					self.legStatus[leg].stack[1] = vec2.add(self.legStatus[leg].stack[1], vec2.mul(world.distance(self.legFallPositions[leg], self.legStatus[leg].stack[1]), 0.1))
				end
				self.legStatus[leg].anchor = vec2.add(mcontroller.position(), self.legStatus[leg].stack[1] or self.legFallPositions[leg])
			end
			local drag = mcontroller.velocity()
			if vec2.mag(drag) > 1 then 
				drag = vec2.mul(vec2.norm(drag), -math.log(vec2.mag(drag)/10 + 1))
			else
				drag = {0,0}
			end
			--if leg == "lF" then sb.logInfo("Drag on %s: %s", leg, drag) end
			--world.debugLine(vec2.add(mcontroller.position(), self.legStatus[leg].anchor), vec2.add(mcontroller.position(), vec2.add(self.legStatus[leg].anchor, drag)), {0,200, 100, 255})
			renderLeg(leg, vec2.add(self.legStatus[leg].anchor, drag))
			if self.legStatus[leg].state == "attackReady" then
				self.recoilForce = {self.legStatus[leg].stack[1][1]*(-0.3), self.legStatus[leg].stack[1][2]*(-1.0)}
			end
		elseif self.legStatus[leg].state == "attacking" then
			if #self.legStatus[leg].stack == 0 then 
				renderLeg(leg, self.legStatus[leg].anchor, false, false, true)
				self.legAttackBlacklist = {}
				self.storedPointsForLegShockwave = nil
			elseif self.attackLegShockwavePending and vec2.eq(self.legStatus[leg].anchor, self.legStatus[leg].stack[#self.legStatus[leg].stack]) then
				self.legStatus[leg].anchor = vec2.add(table.remove(self.legStatus[leg].stack), mcontroller.position())
				renderLeg(leg, self.legStatus[leg].anchor, true, false, false)
				self.legAttackBlacklist = {}
				self.storedPointsForLegShockwave = nil
				--world.damageTileArea(self.legStatus[leg].anchor, 10, "foreground", mcontroller.position(), "plantish", 100, 0)
			else
				self.recoilForce = {0, self.legStatus[leg].stack[1][2]*0.7}
				mcontroller.addMomentum({self.legStatus[leg].stack[1][1]*(self.meleeHorizontalForceMultiplier or 0), 0})
				self.legStatus[leg].anchor = vec2.add(table.remove(self.legStatus[leg].stack), mcontroller.position())
				renderLeg(leg, self.legStatus[leg].anchor, true, false, true)
			end
		elseif self.legStatus[leg].state == "moving" then
			--"moving" legs transition through their arcs
			if #self.legStatus[leg].stack > 0 then 
				renderLeg(leg, table.remove(self.legStatus[leg].stack), false, false, true)
			else
				smackImpactPoint(self.legStatus[leg].anchor)
				self.legStatus[leg].state = "stable"
				renderLeg(leg, self.legStatus[leg].anchor, false, false, true)
			end
		elseif self.legStatus[leg].state == "searching" then
			--"searching" legs play a little twitchy game
			if #self.legStatus[leg].stack == 0 then 
				local newToPoint = {self.legSeeds[leg]+self.chassisOffsets[leg][1],self.chassisOffsets[leg][2] - self.vertEquilibrium + 2}
				newToPoint = vec2.add(newToPoint, vec2.rotate({4*math.random(),0}, math.random()*2*math.pi))
				makeLegStack(leg, self.legStatus[leg].anchor, newToPoint, 40, 40, {2*math.random(), 2*math.random()}, true)
				self.legStatus[leg].anchor = vec2.add(table.remove(self.legStatus[leg].stack), mcontroller.position())
				renderLeg(leg, self.legStatus[leg].anchor)
			else
				self.legStatus[leg].anchor = vec2.add(table.remove(self.legStatus[leg].stack), mcontroller.position())
				renderLeg(leg, self.legStatus[leg].anchor)
			end
		end
	end
	--sb.logInfo("renderLegs() end")
end

function renderLeg(leg, footPos, destructive, justChecking, noBounce)
	--sb.logInfo("renderLeg(%s) begin", leg)
	
	--if self.poweringDown then return nil end
	
	--there's only one way to fit bridge two points with a leg. find it first
	local rootPos = vec2.add(mcontroller.position(), self.chassisOffsets[leg])
	local jointPos = {0,0}
	local baseLine = world.distance(footPos, rootPos)
	local squeezeFactor = 1
	local rotateAngle = 0
	--if leg == "lF" then sb.logInfo("Rendering: %s, %s, %s", rootPos, footPos, baseLine) end
	if vec2.mag(baseLine) < self.upperLegLength + self.lowerLegLength and vec2.mag(baseLine) > self.lowerLegLength - self.upperLegLength then
		rotateAngle = math.acos((self.upperLegLength^2 + vec2.mag(baseLine)^2 - self.lowerLegLength^2)/(2 * self.upperLegLength * vec2.mag(baseLine)))
		if string.sub(leg, 1, 1) == "l" then rotateAngle = -rotateAngle end
		jointPos = vec2.add(mcontroller.position(), self.chassisOffsets[leg])
		jointPos = vec2.add(jointPos, vec2.rotate( vec2.mul( vec2.norm(baseLine) , self.upperLegLength), rotateAngle))
	else 
		--sb.logInfo("Bad renderLeg call - nonphysical joint position")
		-- sb.logInfo("footPos: "..footPos[1]..", "..footPos[2])
		-- sb.logInfo("rootPos: "..rootPos[1]..", "..rootPos[2])
		-- sb.logInfo("baseLine: "..baseLine[1]..", "..baseLine[2])
		-- sb.logInfo(vec2.mag(baseLine)..", "..self.upperLegLength + self.lowerLegLength)
		-- sb.logInfo("------")
		return false
	end
	local lowerLeg = world.distance(footPos, jointPos)
	local upperLeg = world.distance(jointPos, rootPos)

	local blockingBlocks1 = world.collisionBlocksAlongLine(rootPos, jointPos, {"Null", "Block", "Dynamic"})
	local blockingBlocks2 = world.collisionBlocksAlongLine(jointPos, footPos, {"Null", "Block", "Dynamic"})
	if #blockingBlocks1 > 1 or #blockingBlocks2 > 1 then
		if justChecking then
			return false
		end
	else
		if justChecking then
			return true
		end
		table.insert(blockingBlocks1, blockingBlocks2[1])
		for _,block in ipairs(blockingBlocks1) do
			local adjusts = {{0,1},{1,0},{-1,0},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}}
			local sideBlocks = {}
			for i,j in ipairs(adjusts) do
				local tile = vec2.add(block, j)
				if world.tileIsOccupied(tile, true) then
					table.insert(sideBlocks, j)
				end
			end
			if #sideBlocks == 1 or (#sideBlocks == 2 and vec2.mag(vec2.add(sideBlocks[1], sideBlocks[2])) <= 1) then 
				--world.damageTiles({block}, "foreground", mcontroller.position(), "explosive", 1000, 99)
			end
		end
		-- if #blockingBlocks1 > 0 then
			-- world.damageTiles(blockingBlocks1, "foreground", mcontroller.position(), "explosive", 1000, 99)
		-- end
		-- if #blockingBlocks2 > 0 then
			-- world.damageTiles(blockingBlocks2, "foreground", mcontroller.position(), "explosive", 1000, 99)
		-- end
	end

	--animator.setAnimationState("body", "idle")
	animateLeg(leg, rootPos, jointPos, footPos)
	
	--[[if leg == "rF" then
		if not noBounce and world.pointTileCollision(jointPos, {"Null", "Block", "Dynamic"}) and mcontroller.xVelocity() > 0 then 
			mcontroller.setXVelocity(0) 
			self.movementBlocked["right"] = true
		end
	elseif leg == "lF" then
		if not noBounce and world.pointTileCollision(jointPos, {"Null", "Block", "Dynamic"}) and mcontroller.xVelocity() < 0 then 
			mcontroller.setXVelocity(0) 
			self.movementBlocked["left"] = true
		end
	elseif leg == "rB" then
		if not noBounce and world.pointTileCollision(jointPos, {"Null", "Block", "Dynamic"}) and mcontroller.xVelocity() > 0 then 
			mcontroller.setXVelocity(0)
			self.movementBlocked["right"] = true
		end
	elseif leg == "lB" then
		if not noBounce and world.pointTileCollision(jointPos, {"Null", "Block", "Dynamic"}) and mcontroller.xVelocity() < 0 then 
			mcontroller.setXVelocity(0)
			self.movementBlocked["left"] = true
		end
	end]]--

	world.debugLine(rootPos, jointPos, self.legColors[leg])
	world.debugLine(jointPos, footPos, self.legColors[leg])
	--sb.logInfo("renderLeg(%s) end", leg)
end

function vecToAngle(vector)
	local angle = math.atan(vector[2], vector[1])
	if angle < 0 then angle = angle + 2 * math.pi end
	return angle
end

function animateLeg(leg, rootPos, jointPos, footPos)
	local upperLegAngle = vecToAngle(world.distance(jointPos, rootPos))
	local lowerLegAngle = vecToAngle(world.distance(footPos, jointPos))
	world.debugLine(rootPos, jointPos, self.legColors[leg])
	world.debugLine(jointPos, footPos, self.legColors[leg])
	animator.resetTransformationGroup(leg.."U")
	animator.resetTransformationGroup(leg.."L")
	animator.scaleTransformationGroup(leg.."U", legScale)
	animator.scaleTransformationGroup(leg.."L", legScale)
	animator.rotateTransformationGroup(leg.."U", upperLegAngle)
	animator.rotateTransformationGroup(leg.."L", lowerLegAngle)
	animator.translateTransformationGroup(leg.."U", world.distance(rootPos, mcontroller.position()))
	animator.translateTransformationGroup(leg.."L", world.distance(jointPos, mcontroller.position()))
end