require "/scripts/status.lua"

--RUINED State
ruined = {}

function ruined.enterWith(args)
  if not args or not args.enteringPhase then return nil end

  return {
		vehicleType = config.getParameter("ruined.vehicleType")
	}
end

function ruined.enteringState(stateData)
  world.spawnVehicle(stateData.vehicleType, vec2.add(entity.position(), {-30, -15}))
  animator.setAnimationState("stages", "stage"..currentPhase())
  status.addEphemeralEffect("fortressidontwanttodie")
	
  --Set up a damagelistener for incoming damage
	self.slapsTaken = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
			sb.logInfo(sb.printJson(notification, 1))
      if notification.damageSourceKind == "ruincleaverfinisher" then
				status.removeEphemeralEffect("fortressidontwanttodie")
				status.setResource("health", 0)
				world.sendEntityMessage(entity.id(), "killYourself")
				sb.logInfo("I went to kermit's sewer slide")
        return true
      end
    end
  end)
end

function ruined.update(dt, stateData)
  status.setResource("health", status.stat("maxHealth"))

  self.slapsTaken:update()
end

function ruined.leavingState(stateData)
end