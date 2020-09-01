require "/scripts/util.lua"

WFSpiderMechPartManager = {}

function WFSpiderMechPartManager:new()
  local newPartManager = {}
  
  newPartManager.paletteConfig = root.assetJson("/vehicles/modularmech/mechpalettes.config")
  newPartManager.defaultPrimaryColors = {"A3391D","7B1700","5B0600","3D0001"}
  newPartManager.defaultSecondaryColors = {"A3391D","7B1700","5B0600","3D0001"}

  setmetatable(newPartManager, extend(self))
  return newPartManager
end

function WFSpiderMechPartManager:buildVehicleParameters(partSet, primaryColorIndex, secondaryColorIndex)
  local params = {}

  for i, configFile in ipairs(partSet) do
    local partData = root.assetJson("configFile")
	params = util.mergeTable(params,partData)
  end
  params.colorSwaps = self:buildSwapDirectives(primaryColorIndex,secondaryColorIndex)
  return params
end

function WFSpiderMechPartManager:validateColorIndex(colorIndex)
  if type(colorIndex) ~= "number" then return 0 end

  if colorIndex > #self.paletteConfig.swapSets or colorIndex < 0 then
    colorIndex = colorIndex % (#self.paletteConfig.swapSets + 1)
  end
  return colorIndex
end

function WFSpiderMechPartManager:buildSwapDirectives(primaryIndex, secondaryIndex)
  local result = ""
  local primaryColors = primaryIndex == 0 and self.defaultPrimaryColors or self.paletteConfig.swapSets[primaryIndex]
  for i, fromColor in ipairs(self.paletteConfig.primaryMagicColors) do
    result = string.format("%s?replace=%s=%s", result, fromColor, primaryColors[i])
  end
  local secondaryColors = secondaryIndex == 0 and self.defaultSecondaryColors or self.paletteConfig.swapSets[secondaryIndex]
  for i, fromColor in ipairs(self.paletteConfig.secondaryMagicColors) do
    result = string.format("%s?replace=%s=%s", result, fromColor, secondaryColors[i])
  end
  return result
end
