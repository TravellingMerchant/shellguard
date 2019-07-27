require "/scripts/util.lua"

function init()
  self.iAction = config.getParameter("iAction")
  self.iData = config.getParameter("iData")
  
  local partConfig = {}
  local pConfig = config.getParameter("partConfig")
  if type(pConfig) == "table" then
    for k, v in pairs(pConfig) do
      partConfig = util.mergeTable(partConfig, root.assetJson(v))
    end
  else
    partConfig = root.assetJson(pConfig)
  end
  local items = {}
  for k, v in pairs(partConfig) do
    if k ~= "projectiles" then
      local itemList = {}
      for kk, _ in pairs(v) do
        table.insert(itemList, {item = "sg_" .. k .. "_" .. kk })
      end
      
      table.sort(itemList, function(a, b)
        return a.item < b.item
      end)
      
      util.appendLists(items, itemList)
    end
  end
  self.iData.items = items
  
  object.setInteractive(true)
end

function onInteraction(args)
  return {self.iAction, self.iData}
end
