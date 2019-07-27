require "/scripts/util.lua"

-- if this code looks familiar then you're right
-- thankfully the base mod is free for the taking soo

function init()
  local partConfig = config.getParameter("partConfig", {"/items/active/weapons/ranged/sg_built/partConfig.config","/items/active/weapons/ranged/sg_built/partConfigMerchant.config","/items/active/weapons/ranged/sg_built/partConfigSkaianDLC.config"})
  self.partConfig = {}
  
  for k, v in pairs(partConfig) do
    self.partConfig = util.mergeTable(self.partConfig, root.assetJson(v))
  end
  
  for k, v in pairs(config.getParameter("addonTypes", {"Alpha", "Beta"})) do
    self.partConfig["baseAddon"..v] = self.partConfig.baseAddon
  end
  
  self.name = nil
  
  self.first = true
  
  --sb.logInfo("%s", storage)
  
  if storage.inventory == nil then storage.inventory = {} end
  if storage.lastInventory == nil then storage.lastInventory = {} end
  
  message.setHandler("nameItem", nameItem)
  message.setHandler("closed", closed)
end

function update(dt)
  if self.first then
    self.first = false
    if world.containerItemAt(entity.id(), 1) and world.containerItemAt(entity.id(), 6) then
      containerTakeItem(6)
    end
  end
end

function die()
  containerTakeItem(6)
end

function nameItem(callback, isLocal, name)
  self.name = name
  containerSlotsChanged({1})
end

--[[
function closed(callback, isLocal)
  for i = 0, 5 do
    world.spawnItem(containerTakeItem(i), entity.position())
  end
  containerTakeItem(6)
end
]]

function containerSlotsChanged(slots)
  --sb.logInfo("%s", slots)
  
  if slots[1] == 6 then
    if world.containerItemAt(entity.id(), 6) and not storage.lastInventory[7] then
      for i = 0, 5 do
        local item = containerTakeItem(i)
        if item then
          world.spawnItem(item, entity.position())
        end
      end
    end
    for i = 0, 5 do
      containerTakeItem(i)
    end
  end
  if slots[1] == 0 or slots[1] == 1 or slots[1] == 2 or slots[1] == 3 or slots[1] == 4 or slots[1] == 5 then
    if not storage.lastInventory[1]
    and not storage.lastInventory[2]
    and not storage.lastInventory[3]
    and not storage.lastInventory[4]
    and not storage.lastInventory[5]
    and not storage.lastInventory[6] then
      local item = containerTakeItem(6)
      if item then
        world.spawnItem(item, entity.position())
      end
    end
    containerTakeItem(6)
  end

  local parts = breakIntoParts()
  if parts then
    if world.containerItemAt(entity.id(), 0) == nil
      and world.containerItemAt(entity.id(), 1) == nil
      and world.containerItemAt(entity.id(), 2) == nil
      and world.containerItemAt(entity.id(), 3) == nil
      and world.containerItemAt(entity.id(), 4) == nil
      and world.containerItemAt(entity.id(), 5) == nil then
      for i = 0, 5 do
        containerPutItem(parts[i+1], i)
      end
    end
    return
  end

  local weapon = craftGun(getParts())
  if weapon and world.containerItemAt(entity.id(), 6) == nil then
    containerPutItem(weapon, 6)
    return
  end
end


-- urility functions

function containerCallback()
  --sb.logInfo("%s", storage.inventory)
  
  local slots = {}
  for i = 0, 6 do
    storage.lastInventory[ i + 1 ] = storage.inventory[ i + 1 ]
    if inventorySlotChanged(i) then
      table.insert(slots, i)
    end
  end

  containerSlotsChanged(slots)
end

function inventorySlotChanged(slot)
  --sb.logInfo("%s", storage.inventory)
  --sb.logInfo("%s:%s:%s", slot+1, storage.inventory[slot+1], world.containerItemAt(entity.id(), slot))
  
  if not compare(storage.inventory[slot + 1], world.containerItemAt(entity.id(), slot)) then
    storage.inventory[slot+1] = world.containerItemAt(entity.id(), slot)
    return true
  end
  return false
end

function getParts()
  local data = {}
  for i = 0, 5 do
    data[i+1] = world.containerItemAt(entity.id(), i)
  end
  return data
end

function containerTakeItem(slot)
  storage.inventory[slot+1] = nil
  if world.containerItemAt(entity.id(), slot) then
    return world.containerTakeAt(entity.id(), slot)
  end
end

function containerPutItem(item, slot)
  world.containerPutItemsAt(entity.id(), item, slot)
  storage.inventory[slot+1] = world.containerItemAt(entity.id(), slot)
end

-- actual princess code beyond this point

function breakIntoParts()
  local gun = world.containerItemAt(entity.id(), 6)
  if not gun then return end
  local build = gun.parameters.build
  if not build then return end
  local data = {}
  for k, v in pairs(build) do
    local i = 0
    if k == "stock" then i = 1 end
    if k == "receiver" then i = 2 end
    if k == "barrel" then i = 3 end
    if k == "baseAddonAlpha" then
      i = 4
      k = "baseAddon"
    end
    if k == "baseAddonBeta" then
      i = 5
      k = "baseAddon"
    end
    if k == "underbarrelAddon" then i = 6 end
    if v ~= "null" then
      data[i] = root.createItem(string.format("sg_%s_%s", k, v))
    end
  end
  return data
end

function craftGun(items)
  --sb.logInfo("%s",items)
  --order: stock - receiver - barrel - underbarrel addon - addons alpha - beta
  local itemStorage = {}
  for i, item in pairs(items) do
    itemStorage[i] = getFullItem(item)
  end
  local build = {}
  for i, item in pairs(itemStorage) do
    build[i] = value(item, "build")
    if build[i] == nil then return --[[sb.logInfo("FAILURE")]] end
  end
  
  if not buildValid(build) then return --[[sb.logInfo("FAILURE")]] end
  
  local incompat = {}
  local partConfig = {}
  for i, item in pairs(build) do
    local typeConfig = self.partConfig[item.type]
    partConfig[i] = typeConfig[item.id]
    if partConfig[i].incompatibleWith then
      for j, incompatType in pairs(partConfig[i].incompatibleWith) do
        if incompat[incompatType] then return --[[sb.logInfo("FAILURE")]] end
      end
    end
    if partConfig[i].type then
      incompat[partConfig[i].type] = true
    end
  end
  
  if partConfig[2].addons == 1 and items[5] then return --[[sb.logInfo("FAILURE")]] end
  
  local returnBuild = {
    stock = build[1].id,
    receiver = build[2].id,
    barrel = build[3] and build[3].id or "null",
    baseAddonAlpha = build[4] and build[4].id or nil,
    baseAddonBeta = build[5] and build[5].id or nil,
    underbarrelAddon = build[6] and build[6].id or nil
  }
  
  local gun = {
      name = config.getParameter("gunItem", "shellguardmodularrifle"),
      count = 1,
      parameters = {build = returnBuild, name = self.name}
    }

  return gun
end

function buildValid(build)
  --sb.logInfo("%s",build)
  if build[1] then 
    if build[1].type ~= "stock" then return false end
  else return false end
  if build[2] then 
    if build[2].type ~= "receiver" then return false end
  else return false end
  if build[3] then 
    if build[3].type ~= "barrel" then return false end
  end
  if build[4] then 
    if build[4].type ~= "baseAddon" then return false end
    if build[4].slot and build[4].slot ~= "alpha" then return false end
  end
  if build[5] then 
    if build[5].type ~= "baseAddon" then return false end
    if build[5].slot and build[5].slot ~= "beta" then return false end
  end
  if build[6] then 
    if build[6].type ~= "underbarrelAddon" then return false end
  end
  return true
end

function value(item, id)
  return item.parameters[id] or item.config[id] or nil
end

function getFullItem(item)
  return root.itemConfig(item)
end