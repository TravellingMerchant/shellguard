idleState = {}

function idleState.enter()
  if hasTarget() then return nil end
  script.setUpdateDelta(1)
  self.timer = 0

  return {
    parameters = {gravityEnabled = true},
	headRotationCenter = {4.125, 2.5},
	angleApproach = 0.01,
	amplitude = 0.025,
	period = 1.75
  }
end

function idleState.update(dt, stateData)
  mcontroller.controlFace(1)
  mcontroller.controlParameters(stateData.parameters)
  
  self.timer = self.timer + dt
  idleState.updateHead(stateData)
end

function idleState.leavingState(stateData)
  stateData.parameters = {gravityEnabled = false}
  mcontroller.controlParameters(stateData.parameters)
  animator.resetTransformationGroup("head")
end

function idleState.updateHead(stateData)
  animator.resetTransformationGroup("head")

  local targetAngle = stateData.amplitude * math.sin(self.timer * stateData.period)

  --self.headAngle = (self.headAngle or 0) + (targetAngle - (self.headAngle or 0)) * stateData.angleApproach
  animator.rotateTransformationGroup("head", targetAngle, stateData.headRotationCenter)
end