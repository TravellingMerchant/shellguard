require "/scripts/util.lua"

function init()
  self.updateLock = true
  script.setUpdateDelta(15)--update every 1/4 second
  widget.setText("errorLabel","")
end

function update(dt)
  if self.updateLock then
    local item = widget.itemGridItems("itemGrid")
    if not isEmpty(item) then
      self.updateLock = false
      --script.setUpdateDelta(0)
      
      widget.setText("name", item[7] and item[7].parameters.name or "")
    end
  end
  if self.errorPromise then
    if self.errorPromise:finished() then
	  if self.errorPromise:succeeded() then
	    local result=self.errorPromise:result()
		widget.setText("errorLabel",result or "")
	  end
	  self.errorPromise=nil
	end
  else
	self.errorPromise=world.sendEntityMessage(pane.containerEntityId(),"sendErrorStatus")
  end
end

function name()
  world.sendEntityMessage(pane.containerEntityId(), "nameItem", widget.getText("name"))
end