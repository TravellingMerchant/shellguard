require "/scripts/util.lua"

function init()
  self.updateLock = true
end

function update()
  if self.updateLock then
    local item = widget.itemGridItems("itemGrid")
    if not isEmpty(item) then
      self.updateLock = false
      script.setUpdateDelta(0)
      
      widget.setText("name", item[7] and item[7].parameters.name or "")
    end
  end
end

function name()
  world.sendEntityMessage(pane.containerEntityId(), "nameItem", widget.getText("name"))
end