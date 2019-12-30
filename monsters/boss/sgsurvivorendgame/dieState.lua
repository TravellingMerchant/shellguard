dieState = {}

function dieState.enterWith(args)
  if not args.die then return nil end

  return {
    timer = 1.0
  }
end

function dieState.enteringState(stateData)
end

function dieState.update(dt, stateData)
  if stateData.timer <= 0.0 then
    self.dead = true
	world.spawnMonster("sgsurvivorcapture", mcontroller.position())
  end

  stateData.timer = stateData.timer - dt
  return false
end