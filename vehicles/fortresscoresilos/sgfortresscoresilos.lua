require "/scripts/messageutil.lua"
require "/scripts/util.lua"

function init()
  --Message Handling--
  message.setHandler("moveUp", localHandler(moveUp))
  message.setHandler("moveDown", localHandler(moveDown))

  --General Init--
  mcontroller.setRotation(0)
  vehicle.setInteractive(false)
  self.resolvedVelocity = 0
  self.timer = 0
end

function update(dt)
  if self.timer > 0 then
    self.timer = self.timer - dt
    mcontroller.setYVelocity(self.resolvedVelocity)
	if self.timer <= 0 then
	  endTransit()
	end
  end
  
  --Kill it so it doesn't persist, despite not going to be at the world limit ¯\_(ツ)_/¯
  if mcontroller.atWorldLimit() then
    vehicle.destroy()
    return
  end
  
  --Make sure it never moves left or right
  mcontroller.setXVelocity(0)
end

function uninit()
end

function moveUp(distance, time)
  local distance = distance * 4.5
  self.resolvedVelocity = distance * time
  self.timer = time
end

function moveDown(distance, time)
  local distance = -distance * 4.5
  self.resolvedVelocity = distance * time
  self.timer = time
end

function endTransit()
  mcontroller.setYVelocity(0)
end