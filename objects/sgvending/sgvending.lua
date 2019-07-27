require "/scripts/util.lua"

function init()
  self.iAction = config.getParameter("iAction")
  self.iData = config.getParameter("iData")
  
  local itemConfig = root.itemConfig(config.getParameter("parentVendor"))
  self.iData.paneLayoutOverride = itemConfig.config.interactData.paneLayoutOverride
  self.iData.buyFactor = itemConfig.config.interactData.buyFactor
  self.iData.sellFactor = itemConfig.config.interactData.sellFactor
  self.iData.items = itemConfig.config.interactData.items
  
  object.setInteractive(true)
end

function onInteraction(args)
  return {self.iAction, self.iData}
end
