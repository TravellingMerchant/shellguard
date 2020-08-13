idleState = {}

function idleState.enter()
  if hasTarget() then return nil end
  script.setUpdateDelta(1)

  return {
    parameters = {gravityEnabled = true},
  }
end

function idleState.update(dt, stateData)
  mcontroller.controlParameters(stateData.parameters)
end

function idleState.leavingState(stateData)
  stateData.parameters = {gravityEnabled = false}
  mcontroller.controlParameters(stateData.parameters)
  animator.resetTransformationGroup("head")
end
