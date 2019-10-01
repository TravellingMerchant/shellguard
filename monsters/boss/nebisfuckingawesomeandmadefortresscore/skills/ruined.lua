require "/scripts/status.lua"

--RUINED State
ruined = {}

function ruined.enterWith(args)
  if not args or not args.enteringPhase then return nil end
	self.radioMessage = false

  return {
		vehicleType = config.getParameter("ruined.vehicleType")
	}
end

function ruined.enteringState(stateData)
	world.sendEntityMessage(entity.id(), "cutTheMusic", false)
  world.spawnVehicle(stateData.vehicleType, vec2.add(entity.position(), {-30, -15}))
  animator.setAnimationState("stages", "stage"..currentPhase())
  status.addEphemeralEffect("fortressidontwanttodie")
	
  --Set up a damagelistener for incoming damage
	self.slapsTaken = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
			--sb.logInfo(sb.printJson(notification, 1))
      if notification.damageSourceKind == "ruincleaverfinisher" then
				status.removeEphemeralEffect("fortressidontwanttodie")
				status.setResource("health", 0)
				world.sendEntityMessage(entity.id(), "killYourself", "none")
        return true
      end
    end
  end)
	
	local playerId = world.playerQuery(mcontroller.position(), 50, {order = "random"})[1]
	if not playerId then
		playerId = entity.id()
	end
	world.sendEntityMessage(playerId, "queueRadioMessage", "sgfortressRUINED1")
	self.radioMessage = true
end

function ruined.update(dt, stateData)
  status.setResource("health", status.stat("maxHealth"))

  self.slapsTaken:update()
end

function ruined.leavingState(stateData)
end