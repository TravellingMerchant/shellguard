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
end

function ruined.update(dt, stateData)
 --status.setResource("health", status.stat("maxHealth"))
  --Set up a damagelistener for incoming damage
  local damageListener = damageListener("damageTaken", function(notifications)
    for _,notification in pairs(notifications) do
      if notification.damageSourceKind == "ruincleaverfinisher" then
				status.removeEphemeralEffect("fortressidontwanttodie")
				status.setResource("health", 0)
				world.sendEntityMessage(entity.id(), "killYourself")
				sb.logInfo("I went to kermit's sewer slide")
        return true
      end
    end
  end)
  damageListener:update()
end

function ruined.leavingState(stateData)
  animator.rotateGroup("core", 0, true)
end