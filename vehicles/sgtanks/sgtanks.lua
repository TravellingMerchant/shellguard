require "/scripts/vec2.lua"
require "/scripts/util.lua"

function configParameter(name,default)
  if vehicle.configParameter then
    return vehicle.configParameter(name,default)--Glad
  else
    return config.getParameter(name,default)--Cheerful
  end
end

function projectilePowerAdjust(pPower)
  if vehicle.configParameter then
    return root.evalFunction("gunDamageLevelMultiplier", self.level) * pPower * self.damageMulti
  else
    return root.evalFunction("weaponDamageLevelMultiplier", self.level) * pPower * self.damageMulti
  end
end

function healthLevelAdjust(hp_or_armor)
  return root.evalFunction("shieldLevelMultiplier", self.level) * hp_or_armor
end


function init()
  
  self.specialLast = false
  self.active = false
  self.fireTimer = 0
  animator.rotateGroup("guns", 0, true)
  self.facingDirection = 1
  self.movingDirection = 1
  self.level = world.threatLevel() or configParameter("mechLevel", 6)
  self.groundFrames = 1
  self.driver = false
  self.vacTimer = 0
  
  self.priFireTimer = 0
  self.altFireTimer = 0
  -- body rotation
  self.angle = 0
  self.maxGroundSearchDistance = configParameter("maxGroundSearchDistance")

  local bounds = mcontroller.localBoundBox()
  local midp = bounds[1] +(bounds[3]-bounds[1])/2
  local quar = (bounds[3]-bounds[1])/4
  
  self.frontGroundTestPoint={bounds[1]-1,bounds[2]+(bounds[4]-bounds[2])/5}
  self.fronthalfGroundTestPoint={bounds[1]+quar,bounds[2]+(bounds[4]-bounds[2])/5}
  self.centerGroundTestPoint={midp,bounds[2]+(bounds[4]-bounds[2])/5}
  self.backhalfGroundTestPoint={bounds[3]-quar,bounds[2]+(bounds[4]-bounds[2])/5}
  self.backGroundTestPoint={bounds[3]+1,bounds[2]+(bounds[4]-bounds[2])/5}

  -- required for damaging
  self.maxHealth = healthLevelAdjust(configParameter("maxHealth",1000))
  self.protection = healthLevelAdjust(configParameter("protection",50))
  self.materialKind = configParameter("materialKind","robotic")

  if storage.health == nil then
    local storedHP = configParameter("startHealthFactor")

    if (storedHP == nil) then
        storage.health = self.maxHealth
    else
       storage.health = math.min(storedHP * self.maxHealth, self.maxHealth)
    end    
    self.warpPosition = mcontroller.position()
    animator.setAnimationState("movement", "warpIn")
    animator.setAnimationState("frontFiring", "off")
  else
    animator.setAnimationState("movement", "idle")
  end
    
  --this comes in from the controller.
  self.ownerKey = configParameter("ownerKey")
  vehicle.setPersistent(self.ownerKey)

   --setup the store functionality  
  message.setHandler("store",
    function(_, _, ownerKey)

      if (self.ownerKey and self.ownerKey == ownerKey and self.driver == nil and animator.animationState("movement")=="idle") then
        self.warpPosition = mcontroller.position()
        animator.setAnimationState("movement", "warpOut")
--                          vehicle.destroy()
        return {storable = true, healthFactor = storage.health / self.maxHealth}
      else
        return {storable = false, healthFactor = storage.health / self.maxHealth}
      end
    end
  )

-- kao_energy_use
  self.energyToUse = {} -- <seatname : val> use val energy from seatname
  self.energyLocked = {} -- <seatname : bool> true when seat out of energy til regenerated
  self.seats = {}
  
  local configseats = configParameter("loungePositions",{})
  for s,_ in pairs(configseats) do
    if not self.energyToUse[s] then self.energyToUse[s] = 0 end 
    if not self.seats[s] then table.insert(self.seats,s) end 
    
  end

  message.setHandler("vehicle_setEnergyLocked",
    function(_,_,args) 
--      local seats = {"driverseat","turretseat"} -- rename to your seatname, add more seats if needed
      local ent = nil
      for _,s in ipairs(self.seats) do
        ent = vehicle.entityLoungingIn(s)
        if ent and world.entityUniqueId(ent) == args.ownerUid then 
          self.energyLocked[s] = args.block 
          return
        end
      end
    end
  )
    
  self.useSeatEnergy = function (seat, amountToUse) -- usage: self.useSeatEnergy("seat",9001)
    if amountToUse <= 0 then return end
    local ent = vehicle.entityLoungingIn(seat)
    if not ent then return end
    world.sendEntityMessage(ent,"vehicle_useSeatEnergy",{ownerUid = world.entityUniqueId(ent),amount = amountToUse})
  end
  
   
  -- player armor & health extra
  -- dont forget update line at entityInSeat check
  self.baseProtection = self.protection
  self.baseMaxHealth = self.maxHealth
  self.damageMulti = 1
  
  message.setHandler("vehicle_setProtection",
    function(_,_,args)
--      local seats = {"driverseat","turretseat"}
      local ent = nil
      for _,s in ipairs(self.seats) do
        ent = vehicle.entityLoungingIn(s)
        if ent and ent == self.driver and world.entityUniqueId(ent) == args.ownerUid then 
--sb.logInfo("%s %s %s",args.pv,args.mh, args.dm)
          self.protection = math.min(99.9,math.max(args.pv, self.baseProtection))--pv:player protection value
          self.damageMulti = math.max(args.dm,1)--dm: (player damage multiplier - 1)/2
          local hpratio = storage.health/self.maxHealth
          self.maxHealth = math.max(args.mh*self.baseMaxHealth,self.baseMaxHealth)--mh:player maxhealth/100
          storage.health = self.maxHealth * hpratio
          return
        end
      end
    end
  )
  
  self.setPilotProtection = function(entityInSeat)
    if entityInSeat then -- piloted, query player values
    world.sendEntityMessage(entityInSeat,"vehicle_queryProtection",{ownerUid = world.entityUniqueId(entityInSeat),vId=entity.id()})
    else -- unpiloted, reset values
    local hpr = storage.health/self.maxHealth
    self.maxHealth = self.baseMaxHealth
    storage.health = self.baseMaxHealth * hpr
    self.protection = self.baseProtection
    self.damageMulti = 1
    end
  end

end

--------------------------------------------------------------------------------

function update()
-- warp first
  local warpAni = animator.animationState("movement")
  if warpAni == "warpOutEnd" then
    vehicle.destroy()
    return
  elseif warpAni == "warpIn" or warpAni == "warpOut" then
    world.debugText("warping",mcontroller.position(),"red")
    animator.setAnimationState("frontFiring", "off")
    animator.setAnimationState("hatch", "off")

    --lock it solid whilst spawning/despawning
--    mcontroller.setPosition(self.warpPosition)
    mcontroller.setVelocity({0,0})
    return
  end
  
  local mechAimLimit = configParameter("mechAimLimit") * math.pi / 180
  local mechHorizontalMovement = configParameter("mechHorizontalMovement")
  local mechJumpVelocity = configParameter("mechJumpVelocity")
  local offGroundFrames = configParameter("offGroundFrames")

  local mechCollisionPoly = mcontroller.collisionPoly()
  local position = mcontroller.position()

  local aimSeat = "driverseat"
  local entityInDriver = vehicle.entityLoungingIn("driverseat")
 
  local entityInTurret = vehicle.entityLoungingIn("turretseat")
  if entityInTurret then
    animator.setAnimationState("hatch", "open")
    aimSeat = "turretseat"
  else
    animator.setAnimationState("hatch", "closed")
  end

  local entityInSeat = entityInDriver or entityInTurret
  if entityInSeat ~= self.driver then
    self.driver = entityInSeat
    animator.setLightActive("dashGlow",not entityInSeat)
    self.setPilotProtection(entityInSeat)
  end
  if not entityInSeat then
    vehicle.setDamageTeam({type = "passive"})
    animator.rotateGroup("guns", -mechAimLimit*self.facingDirection)
    animator.setAnimationState("movement", "idle")
  else
    vehicle.setDamageTeam(world.entityDamageTeam(entityInSeat))
  end
  
---- movement + animation
  animator.resetTransformationGroup("flip")--body/treads
  animator.resetTransformationGroup("turret")--gunner/guns
  animator.resetTransformationGroup("rotation")--terrain
  local aimSeatPart = configParameter("loungePositions."..aimSeat..".part")
  local aimSeatPartPos = configParameter("loungePositions."..aimSeat..".partAnchor")
  local aimSeatPos = animator.partPoint(aimSeatPart,aimSeatPartPos)
  aimSeatPos[1] = math.abs(aimSeatPos[1])<1 and 0 or aimSeatPos[1]*self.facingDirection*self.movingDirection
  aimSeatPos = vec2.add(mcontroller.position(),aimSeatPos)
  local diff = world.distance(vehicle.aimPosition(aimSeat), aimSeatPos)
  local aimAngle = math.atan(diff[2], diff[1]*self.movingDirection)
  local facingDirection = (aimAngle > math.pi / 2 or aimAngle < -math.pi / 2) and -1 or 1

  local targAngle=calcGroundCollisionAngle(self.maxGroundSearchDistance)
  
  self.angle = self.angle + (targAngle - self.angle) * 0.05
--world.debugText("%s",self.angle,vec2.add({0,-1},mcontroller.position()),"red")
  animator.rotateTransformationGroup("rotation", self.angle)
  animator.rotateTransformationGroup("turret", self.angle*-1*facingDirection)
  mcontroller.setRotation(self.angle)

  if self.movingDirection < 0 then
    animator.scaleTransformationGroup("flip", {-1, 1})
  end
--  world.debugText("%s",aimAngle,mcontroller.position(),"red")

  if facingDirection < 0 then
--    animator.setFlipped(true)
    animator.scaleTransformationGroup("turret", {-1, 1})
    
    if aimAngle > 0 then
      aimAngle = -math.max(aimAngle, math.pi - 2*mechAimLimit)
    else
      aimAngle = -math.min(aimAngle, -math.pi + mechAimLimit)
    end

    if self.driver then
    animator.rotateGroup("guns", math.pi - aimAngle,true)
    end
  else
--    animator.setFlipped(false)
    animator.scaleTransformationGroup("turret", {1, 1})

    if aimAngle > 0 then
      aimAngle = math.min(aimAngle, 2*mechAimLimit)
    else
      aimAngle = math.max(aimAngle, -mechAimLimit)
    end

    if self.driver then
    animator.rotateGroup("guns", aimAngle,true)
    end
  end
  self.facingDirection = facingDirection
  self.aimAngle = aimAngle

  local onGround = mcontroller.onGround()
  local movingDirection = 0

  if self.driver == entityInTurret and vehicle.controlHeld("turretseat", "left")
    or vehicle.controlHeld("driverseat","left") then
    mcontroller.setXVelocity(-mechHorizontalMovement)
    movingDirection = -1
  end

  if self.driver == entityInTurret and vehicle.controlHeld("turretseat", "right") 
    or vehicle.controlHeld("driverseat","right") then
    mcontroller.setXVelocity(mechHorizontalMovement)
    movingDirection = 1
  end

  --world.debugText("f:%s || m:%s || %s",self.facingDirection,self.movingDirection,self.facingDirection-self.movingDirection,mcontroller.position(),"red")
  if self.facingDirection-self.movingDirection ~= 0 then
    animator.setGlobalTag("facing","left")
  else
    animator.setGlobalTag("facing","")
  end

  if self.driver == entityInTurret and vehicle.controlHeld("turretseat", "down")  
    or vehicle.controlHeld("driverseat","down") then
    mcontroller.applyParameters({ignorePlatformCollision=true})
  else
    if mcontroller.parameters().ignorePlatformCollision then
      mcontroller.applyParameters({ignorePlatformCollision=false})
    end
  end

  
  if self.vacTimer <=0 and onGround and (vehicle.controlHeld("turretseat", "jump") or vehicle.controlHeld("driverseat", "jump")) then
--lpk:change jump to item vacuum
    local bounds = mcontroller.localBoundBox()
    local vh = (bounds[4]-bounds[2])
    local bl = vec2.add(position,{bounds[1],bounds[2]-0.5})
    local tr = vec2.add(position,{bounds[3],bounds[2]+1})
--    util.debugRect(bounds,{255,180,0,255})
    local oids = world.itemDropQuery(bl,tr,{boundMode = "metaboundbox"})
    for _,oid in pairs(oids) do
      local item = world.takeItemDrop(oid,entity.id())
      if item then
      world.spawnItem(item.name,position,item.count or 1,item.parameters or {})
      end
    end
    self.vacTimer = 1
    -- mcontroller.setXVelocity(mechJumpVelocity[1] * movingDirection)
    -- mcontroller.setYVelocity(mechJumpVelocity[2])
    -- animator.setAnimationState("movement", "jump")
    -- self.groundFrames = 0
  else
    self.vacTimer = self.vacTimer - script.updateDt()
  end

  if onGround then
    self.groundFrames = offGroundFrames
  else
    self.groundFrames = self.groundFrames - 1
  end
  
  local emote = self.lastEmote
  local dance = self.lastDance
  local curhp = math.ceil((storage.health/self.maxHealth)*4)
  if self.groundFrames <= 0 then
    if mcontroller.velocity()[2] > 0 then
      animator.setAnimationState("movement", "jump")
    else
      animator.setAnimationState("movement", "fall")
    end
    dance = "panic" -- off ground panic
  elseif movingDirection ~= 0 then
    self.movingDirection = movingDirection
--    if facingDirection ~= movingDirection then
--      animator.setAnimationState("movement", "backWalk")
--    else
      animator.setAnimationState("movement", "walk")
--    end
    local emotes = {"annoyed","neutral","happy","laugh"}
    dance = "typing" -- push/pull lever action
    emote = emotes[curhp]--"laugh"
  elseif onGround then
    animator.setAnimationState("movement", "idle")
    local emotes = {"sad","sad","annoyed","happy"}
    dance = "flipswitch" -- arms at sides
    emote = emotes[curhp]--"annoyed"
  end

  if emote ~= self.lastEmote then vehicle.setLoungeEmote("turretseat",emote) self.lastEmote = emote end
  if dance ~= self.lastDance then vehicle.setLoungeDance("turretseat",dance) self.lastDance = dance end
  
  if self.priFireTimer <= 0 and vehicle.controlHeld(aimSeat, "primaryFire") and not self.energyLocked[aimSeat] then
  --LMB
    self.priFireTimer = configParameter("mainFireCycle",1)
    local pName = configParameter("mainProjectile")
    local pLevel = math.max(0.5,world.threatLevel())
    local pPower = projectilePowerAdjust(configParameter("mainProjectileConfig.power",1))
    local launchpoint = vec2.add(mcontroller.position(),animator.partPoint("backGun","firePoint"))
--    local launchdir = {math.cos((self.angle+self.aimAngle)*self.facingDirection)*self.movingDirection,math.sin(self.angle+self.aimAngle)*self.facingDirection}
    local launchdir = {math.cos((self.aimAngle)*self.facingDirection)*self.movingDirection,math.sin((self.aimAngle))*self.facingDirection}
    launchdir = vec2.rotate(launchdir,self.angle)
    world.spawnProjectile(pName, launchpoint, entity.id(), launchdir, false, {power=pPower})
    animator.setAnimationState("rearFiring", "fire")
    self.energyToUse[aimSeat] = self.energyToUse[aimSeat] + pPower-- kao_energy_use
  else
    self.priFireTimer = math.max(-1,self.priFireTimer - script.updateDt())
--    animator.setAnimationState("rearFiring", "off")
  end
  
  if self.altFireTimer <= 0 and vehicle.controlHeld(aimSeat, "altFire") and not self.energyLocked[aimSeat] then
  --RMB
    self.altFireTimer = configParameter("altFireCycle",1)
    local pName = configParameter("altProjectile")
    local pPower = projectilePowerAdjust(configParameter("altProjectileConfig.power",1))
    local launchpoint = vec2.add(mcontroller.position(), animator.partPoint("frontGun", "firePoint"))
    local launchdir = {math.cos((self.aimAngle)*self.facingDirection)*self.movingDirection,math.sin((self.aimAngle))*self.facingDirection}
    launchdir = vec2.rotate(launchdir,self.angle)
    world.spawnProjectile(pName, launchpoint, entity.id(), launchdir, true, {power=pPower})
    animator.setAnimationState("frontFiring", "fire")
    self.energyToUse[aimSeat] = self.energyToUse[aimSeat] + pPower-- kao_energy_use
  else
    self.altFireTimer = math.max(-1,self.altFireTimer - script.updateDt())
    if animator.animationState("frontFiring") == "off" then
      animator.setAnimationState("frontFiring", "idle")
    end
  end
  
  -- kao_energy_use
  for seat,_ in pairs(self.energyToUse) do
  if self.energyToUse[seat] and self.energyToUse[seat] > 0 then
--   sb.logInfo("tank: %s",self.energyToUse)
    self.useSeatEnergy(seat,self.energyToUse[seat])
    self.energyToUse[seat] = 0
  end
  end
  
  updateVehicleDamage() -- damage visuals
  
  world.debugText("%s/%s\n%s",storage.health,self.maxHealth,self.protection,mcontroller.position(),"red")
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- damage to vehicle
function applyDamage(damageRequest)
  local damage = 0
  if damageRequest.damageType == "Damage" or damageRequest.damageType == "IgnoresDef" then
    damage = damage + root.evalFunction2("protection", damageRequest.damage, self.protection)
  elseif damageRequest.damageType == "IgnoresDef" then
    damage = damage + damageRequest.damage
  else
    return {}
  end
  
if damage > 0 then
  updateVehicleHitDamage()
  storage.health = storage.health - damage
end

  if vehicle.getParameter then -- glad
  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damage = damage,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = self.materialKind,
    killed = storage.health <= 0
  }}
  else -- cheerful
  return {{
    sourceEntityId = damageRequest.sourceEntityId,
    targetEntityId = entity.id(),
    position = mcontroller.position(),
    damageDealt = damage,
    healthLost = damage,
    hitType = "Hit",
    damageSourceKind = damageRequest.damageSourceKind,
    targetMaterialKind = self.materialKind,
    killed = storage.health <= 0
  }}
  end
end

--------------------------------------------------------------------------------
-- damage visuals
function updateVehicleDamage()  -- called per frame, randomize smoke/fire 
local curhealth = storage.health/self.maxHealth
  if curhealth > 0.5 or math.random() < curhealth then return end  -- undamaged, gtfo
  
  bbox = mcontroller.localBoundBox()
  ubox = {bbox[1]+(bbox[3]-bbox[1])*0.2,0,bbox[3]-(bbox[3]-bbox[1])*0.2,bbox[4]}
  lbox = {bbox[1]+(bbox[3]-bbox[1])*0.25,-1.5,bbox[3]-(bbox[3]-bbox[1])*0.25,bbox[4]}
  animator.setParticleEmitterOffsetRegion("smoke",ubox)
  animator.setParticleEmitterOffsetRegion("smoke2",ubox)
  animator.setParticleEmitterOffsetRegion("fire",lbox)
  animator.setParticleEmitterOffsetRegion("fire2",lbox)
  
  if curhealth <= 0.5 and math.random() > curhealth then    -- 1 smoke
    animator.burstParticleEmitter("smoke")    
  end
  if curhealth <= 0.4 and math.random() > curhealth then    -- 1 smoke
    animator.burstParticleEmitter("smoke")    
  end
  if curhealth <= 0.3 and math.random() > curhealth then
    animator.burstParticleEmitter("smoke")    
  end
  if curhealth <= 0.25 and math.random() > curhealth then
   -- 1 smoke 1 fire
    animator.burstParticleEmitter("smoke2")    
    animator.burstParticleEmitter("fire")
  end
  if curhealth <= 0.15 and math.random() > curhealth then
    -- 2 fire
    animator.burstParticleEmitter("fire")
    animator.burstParticleEmitter("fire2")
  end

end

function updateVehicleHitDamage() -- called when hit, spit out damage shards / explode when 0 hp

  animator.burstParticleEmitter("damageShards")
  if storage.health <= 0 then -- blow chunks and EXPLOSIONS!
    local projectileConfig = {
      damageTeam = { type = "indiscriminate" },
      power = configParameter("explosionDamage"),
      onlyHitTerrain = false,
      timeToLive = 0.1,
      actionOnReap = {
        {
          action = "config",
          file =  configParameter("explosionConfig")
        }
      }
    }
    world.spawnProjectile("invisibleprojectile", mcontroller.position(), 0, {0, 0}, false, projectileConfig)

    animator.burstParticleEmitter("wreckage")
    animator.burstParticleEmitter("damageShards")

    vehicle.destroy()  -- your head asplode!
  end
  
end
--------------------------------------------------------------------------------

function calcGroundCollisionAngle(waterSurface)

  local centerDistance = math.min(distanceToGround(self.centerGroundTestPoint),waterSurface)
  local frontDistance  = math.min(distanceToGround(self.frontGroundTestPoint),waterSurface)
  local frontqDistance  = math.min(distanceToGround(self.fronthalfGroundTestPoint),waterSurface)
  local backqDistance  = math.min(distanceToGround(self.backhalfGroundTestPoint),waterSurface)
  local backDistance  = math.min(distanceToGround(self.backGroundTestPoint),waterSurface)



  if frontDistance == self.maxGroundSearchDistance 
  and frontqDistance == self.maxGroundSearchDistance
  and centerDistance == self.maxGroundSearchDistance
  and backqDistance == self.maxGroundSearchDistance
  and backDistance == self.maxGroundSearchDistance then
      return 0
  else
    if frontDistance == self.maxGroundSearchDistance then frontDistance = self.maxGroundSearchDistance/1.3 end
    if frontqDistance == self.maxGroundSearchDistance then frontqDistance = self.maxGroundSearchDistance/1.3 end
    if centerDistance == self.maxGroundSearchDistance then centerDistance = self.maxGroundSearchDistance/1.3 end
    if backqDistance == self.maxGroundSearchDistance then backqDistance = self.maxGroundSearchDistance/1.3 end
    if backDistance == self.maxGroundSearchDistance then backDistance = self.maxGroundSearchDistance/1.3 end
--    local rgroundAngle=-math.atan(backDistance - backqDistance)
--    local rqgroundAngle=-math.atan(backqDistance - centerDistance)
    local rhgroundAngle=-math.atan(backDistance - frontqDistance)--centerDistance)
    local cgroundAngle=-math.atan(backqDistance - frontqDistance)
    local fhgroundAngle=-math.atan(backqDistance - frontDistance)--centerDistance - frontDistance)
--    local fqgroundAngle=-math.atan(centerDistance - frontqDistance)
--    local fgroundAngle=-math.atan(frontqDistance - frontDistance)
    
--    local groundAngle = (rgroundAngle+rqgroundAngle+rhgroundAngle+cgroundAngle+fhgroundAngle+fqgroundAngle+fgroundAngle)/7
    local groundAngle = (rhgroundAngle+cgroundAngle+fhgroundAngle)/3
    return groundAngle
  end
end

function distanceToGround(point)
  -- to worldspace
  point = vec2.rotate(point, self.angle)
  point = vec2.add(point, mcontroller.position())

  local endPoint = vec2.add(point, {0, -self.maxGroundSearchDistance})
  world.debugLine(point, endPoint, {255, 0, 255, 255})
  local intPoint = world.lineCollision(point, endPoint)

  if intPoint then
    world.debugPoint(intPoint, {255, 255, 0, 255})
    return point[2] - intPoint[2]
  else
    world.debugPoint(endPoint, {255, 0, 0, 255})
    return self.maxGroundSearchDistance
  end

end
--------------------------------------------------------------------------------
--[[
--prints tables
function printTable(indent, value)
    local tabs = "";
    for i=1,indent,1 do
        tabs = tabs.."    ";
    end
    table.sort(value)
    for k,v in pairs(value) do
        world.logInfo(tabs..getValueOutput(k,v));
        if type(v) == "table" then
            if tostring(k) == "utf8" then
                world.logInfo("    "..tabs.."SKIPPING UTF8")-- SINCE IT SEEMS TO HAVE NO END AND JUST BE FILLED WITH TABLES OF TABLES
            else
                if tableLen(v) == 0 then
                    world.logInfo("    "..tabs.."EMPTY TABLE")
                else
                    printTable(indent+1,v);
                 
                end
            end
            world.logInfo(" ");
        end
    end
 
end

function tableLen(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

--Required for printTable
function getValueOutput(key ,value)
    if type(value) == "table" then
        return "table : "..key;
    elseif type(value) == "function" then
        return "function : "..key.."()"
    elseif type(value) == "string" then
        return "string : "..key.." - \""..tostring(value).."\"";
    else
        return type(value).." : "..key.." - "..tostring(value);
    end
end
]]