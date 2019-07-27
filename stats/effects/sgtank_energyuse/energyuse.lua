-- vehicle energy use status script 
--  xsm custom version
-- LoPhatKao Aug/sep 2016

function init()
  self.owner = effect.sourceEntity()
  self.ownerUid = world.entityUniqueId(self.owner)
  self.blocked = not status.resourceLocked("energy")
  self.ownerPos = world.entityPosition(self.owner)
  message.setHandler("vehicle_useSeatEnergy", v_useSeatEnergy)
  
  self.energyScale = function ()
    local maxEnergy = status.stat("maxEnergy")
    local minEnergy = effect.getParameter("minEnergy",100)
    local planetBonus = effect.getParameter("planetLevelBonus",10)*world.threatLevel()
    return (minEnergy+planetBonus+maxEnergy)/maxEnergy
  end
  self.statMods = effect.addStatModifierGroup({
      {stat = "maxEnergy", effectiveMultiplier = self.energyScale()},
      {stat = "energyRegenPercentageRate", amount = effect.getParameter("regenRateMultiplier",5)},
      {stat = "energyRegenBlockTime", effectiveMultiplier = effect.getParameter("regenLockMultiplier",2)}
    })

  self.vehicleID = nil
  self.ownerProtection = status.stat("protection")
  self.ownerHealth = status.stat("maxHealth")
  self.ownerPowerMult = status.stat("powerMultiplier")
  message.setHandler("vehicle_queryProtection", v_queryProtection)
--  sb.logInfo("%s",status.stat("powerMultiplier"))
end

function update(dt)
 
  if status.resourceLocked("energy") then
    if not self.blocked then
      self.blocked = true
      v_setEnergyLocked(true)
    end
  else
    if self.blocked then
      self.blocked = false
      v_setEnergyLocked(false)
    end
  end
  if self.ownerProtection ~= status.stat("protection") 
    or self.ownerPowerMult ~= status.stat("powerMultiplier") 
    or self.ownerHealth ~= status.stat("maxHealth") then
    self.ownerPowerMult = status.stat("powerMultiplier")
    self.ownerProtection = status.stat("protection")
    self.ownerHealth = status.stat("maxHealth")
    v_setProtection(self.ownerProtection)
    effect.removeStatModifierGroup(self.statMods)
    self.statMods = effect.addStatModifierGroup({
      {stat = "maxEnergy", effectiveMultiplier = self.energyScale()},
      {stat = "energyRegenPercentageRate", amount = effect.getParameter("regenRateMultiplier",5)},
      {stat = "energyRegenBlockTime", effectiveMultiplier = effect.getParameter("regenLockMultiplier",2)}
    })
  end
 
  self.ownerPos = self.owner and world.entityPosition(self.owner) or self.ownerPos
  world.debugText("%s / %s\n%s",status.resource("energy"),status.stat("maxEnergy"),self.ownerProtection,self.ownerPos,"green")
end

function uninit()
--  v_setEnergyLocked(false) 
--  v_setProtection(0)  
end

function v_sendVehicleMessage(mType,mParams)
if self.vehicleID then
    world.sendEntityMessage(self.vehicleID, mType, mParams)
else
  local vehicleIds = world.entityQuery(self.ownerPos, 5, {includedTypes = {"vehicle"}, order = "nearest"})
  for _,vId in pairs(vehicleIds) do
    world.sendEntityMessage(vId, mType, mParams)
  end
end
end

function v_useSeatEnergy(_,_,args)
  if args.ownerUid and args.ownerUid == self.ownerUid then -- its ours
  if not status.resourceLocked("energy") then -- not regenning from empty
    status.overConsumeResource("energy", args.amount)
  end
  end
end

function v_setEnergyLocked(block)
  v_sendVehicleMessage("vehicle_setEnergyLocked", {ownerUid = self.ownerUid, block = block})
end

function v_queryProtection(_,_,args)
  if args.ownerUid and args.ownerUid == self.ownerUid then -- its ours
    if args.vId and self.vehicleID ~= args.vId then self.vehicleID = args.vId end
--    sb.logInfo(args.vId)
    v_setProtection(self.ownerProtection)
  end
end

function v_setProtection(pval)
local hpMulti = (status.stat("maxHealth")/100)
local damMult = math.max((status.stat("powerMultiplier")-1)/2,1) -- 1..3
  v_sendVehicleMessage("vehicle_setProtection", {ownerUid = self.ownerUid, pv = pval, mh = hpMulti, dm = damMult})
end

--[[   funcs of effect
[22:16:46.176] [Info] function : modifyDuration()
[22:16:46.176] [Info] function : setParentDirectives()
[22:16:46.176] [Info] function : getParameter()
[22:16:46.176] [Info] function : addStatModifierGroup()
[22:16:46.176] [Info] function : expire()
[22:16:46.177] [Info] function : removeStatModifierGroup()
[22:16:46.177] [Info] function : duration()
[22:16:46.177] [Info] function : setStatModifierGroup()
[22:16:46.177] [Info] function : sourceEntity()

]]
