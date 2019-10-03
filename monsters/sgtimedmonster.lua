local sgtimedmonster_init = init
function init(...)
  self.sgTimeAlive = 0
  self.sgTimeToLive = config.getParameter("sgTimeToLive")
  if sgtimedmonster_init then
    sgtimedmonster_init(...)
  end
end

local sgtimedmonster_update = update
function update(dt,...)
  self.sgTimeAlive = self.sgTimeAlive + dt
  if self.sgTimeToLive <= self.sgTimeAlive then
    status.setResource("health",0)
	self.shouldDie = true
  end
  if sgtimedmonster_update then
    sgtimedmonster_update(dt,...)
  end
end