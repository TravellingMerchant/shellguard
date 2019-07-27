require "/scripts/util.lua"
require "/scripts/vec2.lua"
require "/scripts/versioningutils.lua"
require "/scripts/staticrandom.lua"
require "/items/buildscripts/abilities.lua"

function build(directory, config, parameters, level, seed)
  --sb.logInfo("buildScript Online!")
  local configParameter = function(keyName, defaultValue)
    if parameters[keyName] ~= nil then
      return parameters[keyName]
    elseif config[keyName] ~= nil then
      return config[keyName]
    else
      return defaultValue
    end
  end

  if level and not configParameter("fixedLevel", false) then
    parameters.level = level
  end

  -- initialize randomization
  if seed then
    parameters.seed = seed
  else
    seed = configParameter("seed")
    if not seed then
      math.randomseed(util.seedTime())
      seed = math.random(1, 4294967295)
      parameters.seed = seed
    end
  end

  -- select the generation profile to use
  local builderConfig = {}
  if config.builderConfig then
    builderConfig = randomFromList(config.builderConfig, seed, "builderConfig")
  end
  
  -- generate parts
  -- barrel, receiver, stock, addonAlpha, addonBeta, underbarrel
  if not parameters.build then 
    parameters.build = builderConfig.defaults
  end
  
  local partConfig = {}
  if type(builderConfig.partConfig) == "table" then
    for k, v in pairs(builderConfig.partConfig) do
      partConfig = util.mergeTable(partConfig, root.assetJson(v))
    end
  else
    partConfig = root.assetJson(builderConfig.partConfig)
  end
  for k, v in pairs(builderConfig.addonTypes) do
    partConfig["baseAddon"..v] = partConfig.baseAddon
  end
  
  local attachmentPoints = {}
  
  --sb.logInfo("Building ability configs...")
  
  -- setup ability bases
  local newConfig = {primaryAbility = {}}
  
  for k, v in pairs(parameters.build) do
    local parts = partConfig[k]
    local part = parts[v]
    
    if part.weaponMods then
      util.mergeTable(newConfig, part.weaponMods)
    end
    
    if part.baseStats then
      util.mergeTable(newConfig.primaryAbility, part.baseStats)
    end
    
    attachmentPoints[k] = {0, 0}
  end
  
  for k, v in pairs(parameters.build) do
    local parts = partConfig[k]
    local part = parts[v]
    
    if part.modifiers then
      for kk, vv in pairs(part.modifiers) do
        if type(vv) == "number" then
          if newConfig.primaryAbility[kk] then
            newConfig.primaryAbility[kk] = newConfig.primaryAbility[kk] * vv
          end
        elseif type(vv) == "string" then
          if newConfig.primaryAbility[kk] then
            newConfig.primaryAbility[kk] = newConfig.primaryAbility[kk] .. vv
          end
        elseif type(vv) == "table" then
          if newConfig.primaryAbility[kk] then
            util.mergeTable(newConfig.primaryAbility[kk], vv)
          end
        end
      end
    end
    
    if part.attachmentPoints then
      for kk, vv in pairs(part.attachmentPoints) do
        if attachmentPoints[kk] then
          attachmentPoints[kk] = vec2.add(attachmentPoints[kk], vv)
        else
          attachmentPoints[kk] = vv
        end
      end
    end
  end
  
  local projectileConfig = partConfig["projectiles"]
  if projectileConfig[newConfig.primaryAbility.projectileType] then
    local projectile = projectileConfig[newConfig.primaryAbility.projectileType]
    
    newConfig.primaryAbility.projectileType = projectile.projectileType
    
    if newConfig.primaryAbility.projectileParameters then
      util.mergeTable(newConfig.primaryAbility.projectileParameters, projectile.projectileParameters)
    else
      newConfig.primaryAbility.projectileParameters = projectile.projectileParameters
    end
    
    construct(config, "animationCustom", "sounds", "fire")
    config.animationCustom.sounds.fire = projectile.fireSfx
  end
  
  util.mergeTable(config, newConfig)
  
  --sb.logInfo("setupAbility")
  
  -- select, load and merge abilities
  setupAbility(config, parameters, "alt")
  setupAbility(config, parameters, "primary")
  
  --sb.logInfo("setupAbility runs!")
  
  parameters.primaryAbility = parameters.primaryAbility or {}
  parameters.primaryAbility.stances = config.primaryAbility.stances
  parameters.twoHanded = partConfig.receiver[parameters.build.receiver].twoHanded or partConfig.stock[parameters.build.stock].twoHanded or false
  parameters.primaryAbility.stances.cooldown.duration = parameters.primaryAbility.stances.cooldown.duration * (config.primaryAbility.cooldownMult or 1)
  
  for k, v in pairs(parameters.primaryAbility.stances) do
    v.twoHanded = parameters.twoHanded
    v.armRotation = v.armRotation * (parameters.primaryAbility.fireTime or config.primaryAbility.fireTime)
    v.weaponRotation = v.weaponRotation * (parameters.primaryAbility.fireTime or config.primaryAbility.fireTime)
  end
  
  -- animation parts
  config.animationParts = config.animationParts or {}
  for k, v in pairs(parameters.build) do
    if string.sub(k, 1, 9) == "baseAddon" then
      partType = "baseAddon"
    else partType = k
    end
    config.animationParts[k] = directory .. "parts" .. "/" .. partType .. "/" .. v .. ".png"
  end
  
  -- set gun part offsets
  construct(config, "animationCustom", "animatedParts", "parts")
  for k, v in pairs(parameters.build) do
    construct(config.animationCustom.animatedParts.parts, k, "properties")
    config.animationCustom.animatedParts.parts[k].properties.offset = vec2.add(config.baseOffset, attachmentPoints[k])
  end
  
  -- this is the point where most people realize my main language is java
  local barrelImageSize = root.imageSize(config.animationParts.barrel)
  if barrelImageSize[1] == 64 then
    barrelImageSize = {0, 0}
  end
  config.animationCustom.animatedParts.parts.barrel.properties.offset = vec2.add(config.animationCustom.animatedParts.parts.barrel.properties.offset, {barrelImageSize[1] / 16, 0})
  
  local barrelOffset = vec2.add(config.animationCustom.animatedParts.parts.barrel.properties.offset, {barrelImageSize[1] / 16, 0})
  config.muzzleOffset = vec2.add(config.muzzleOffset or {0,0}, barrelOffset)
  config.muzzleOffset = vec2.add(config.muzzleOffset, attachmentPoints.muzzle or {0,0})
  config.beamOffset = vec2.mul(attachmentPoints.muzzle or {0,0}, -1)
  if parameters.build["underbarrelAddon"] then
    config.animationCustom.animatedParts.parts.underbarrelAddon.properties.offset = vec2.add(vec2.add(config.animationCustom.animatedParts.parts.underbarrelAddon.properties.offset, barrelOffset), vec2.mul(config.baseOffset, -1))
  end
  
  -- basic setup past this point
  
  -- name
  parameters.shortdescription = generateName(parameters, config)
  
  -- elemental type and config (for alt ability)
  local elementalType = configParameter("elementalType", "physical")
  replacePatternInData(config, nil, "<elementalType>", elementalType)
  if config.altAbility and config.altAbility.elementalConfig then
    util.mergeTable(config.altAbility, config.altAbility.elementalConfig[elementalType])
  end
  
  -- calculate damage level multiplier
  config.damageLevelMultiplier = root.evalFunction("weaponDamageLevelMultiplier", configParameter("level", 1))

  -- palette swaps
  config.paletteSwaps = ""
  if config.palette then
    local palette = root.assetJson(util.absolutePath(directory, config.palette))
    local selectedSwaps = palette.swaps[configParameter("colorIndex", 1)]
    for k, v in pairs(selectedSwaps) do
      config.paletteSwaps = string.format("%s?replace=%s=%s", config.paletteSwaps, k, v)
    end
  end
  
    -- build inventory icon
  if not config.inventoryIcon and config.animationParts then
    config.inventoryIcon = jarray()
    local parts = util.keys(parameters.build)
    parts = sortParts(parts, config, parameters.build)
    for _,partName in ipairs(parts) do
      local drawable = {
        image = config.animationParts[partName] .. config.paletteSwaps,
        position = vec2.mul(config.animationCustom.animatedParts.parts[partName].properties.offset, 8)
      }
      table.insert(config.inventoryIcon, drawable)
    end
  end
  
  -- populate tooltip fields
  if config.tooltipKind ~= "base" then
    config.tooltipFields = {}
    local fireTime = parameters.primaryAbility.fireTime or config.primaryAbility.fireTime or 1.0
    local baseDps = parameters.primaryAbility.baseDps or config.primaryAbility.baseDps or 0
    local energyUsage = parameters.primaryAbility.energyUsage or config.primaryAbility.energyUsage or 0
    config.tooltipFields.levelLabel = util.round(configParameter("level", 1), 1)
    config.tooltipFields.dpsLabel = util.round(baseDps * config.damageLevelMultiplier, 1)
    config.tooltipFields.speedLabel = util.round(1 / fireTime, 1)
    config.tooltipFields.damagePerShotLabel = util.round(baseDps * fireTime * config.damageLevelMultiplier, 1)
    config.tooltipFields.energyPerShotLabel = util.round(energyUsage * fireTime, 1)
    if elementalType ~= "physical" then
      config.tooltipFields.damageKindImage = "/interface/elements/"..elementalType..".png"
    end
    if config.primaryAbility then
      config.tooltipFields.primaryAbilityTitleLabel = "Primary:"
      config.tooltipFields.primaryAbilityLabel = parameters.primaryAbility.name or config.primaryAbility.name or "unknown"
    end
    if parameters.altAbility or config.altAbility then
      parameters.altAbility = parameters.altAbility or {}
      
      if config.altAbility.type and string.sub(config.altAbility.type, 1, 7) == "bayonet" then
        for k, v in pairs(config.animationCustom.animatedParts.parts.swoosh.partStates.swoosh) do
          if v.properties.offset then
            v.properties.offset = vec2.add(v.properties.offset, {barrelImageSize[1] / 8, 0})
          else
            v.properties.offset = {barrelImageSize[1] / 8, 0}
          end
          v.properties.offset = vec2.add(v.properties.offset, attachmentPoints.underbarrelAddon)
          v.properties.offset = vec2.add(v.properties.offset, attachmentPoints.underbarrelAddonBladeOffset or {0, 0})
          --sb.logInfo("%s", v.properties.offset)
        end
      end
      
      config.tooltipFields.altAbilityTitleLabel = "Special:"
      config.tooltipFields.altAbilityLabel = parameters.altAbility.name or config.altAbility.name or "unknown"
    end
  end

  -- set price
  config.price = (config.price or 0) * root.evalFunction("itemLevelPriceMultiplier", configParameter("level", 1)) * util.tableSize(parameters.build)
  
  return config, parameters
end

function sortParts(parts, config)
  mt = {}
  for i=1,5 do
    mt[i] = {}
  end

  local animation = root.assetJson(config.animation)
  for k, v in pairs(parts) do
    table.insert(mt[animation.animatedParts.parts[v].properties.zLevel + 1], v)
  end
  
  local ret = {}
  for k, v in ipairs(mt) do
    for kk, vv in pairs(v) do
      table.insert(ret, vv)
    end
  end
  return ret
end

function generateName(parameters, config)
  if parameters.name and parameters.name ~= "" then
    return parameters.name
  else
    return config.shortdescription
  end
end