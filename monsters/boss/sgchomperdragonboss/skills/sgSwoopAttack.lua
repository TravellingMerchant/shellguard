sgSwoopAttack = {}

function sgSwoopAttack.enter()
  if not hasTarget() then return nil end
  if self.targetPosition == nil then return nil end
  
  self.headRotationCenter = config.getParameter("sgSwoopAttack.headRotationCenter", {0, 0})
  self.projectileSpawnOffset = config.getParameter("sgSwoopAttack.projectileSpawnOffset", {0, 0})
  self.headAngleOffset = config.getParameter("sgSwoopAttack.headAngleOffset", 1)
  self.angleApproach = config.getParameter("sgHeadLaser.angleApproach", 1)
  self.dashSpeed = config.getParameter("sgSwoopAttack.dashSpeed", 5)
  self.burstTime = config.getParameter("sgSwoopAttack.burstTime", 0.1)
  self.burstTimer = self.burstTime
  self.collided = false
  
  return {
    projectileType = config.getParameter("sgSwoopAttack.projectileType", "dragonblockbuster"),
    projectileParameters = config.getParameter("sgSwoopAttack.projectileParameters", {}),
    trackSourceEntity = config.getParameter("sgSwoopAttack.trackSourceEntity", false),
	
    timer = 0.0,
    swoopTime = config.getParameter("sgSwoopAttack.swoopTime"),
    tookDamage = false
  }
end

function sgSwoopAttack.enteringState(stateData)
  animator.rotateGroup("all", -30 * math.pi / 180)
  monster.setActiveSkillName("sgSwoopAttack")
  animator.setAnimationState("head", "attackWindup")
  animator.playSound("dashWindup")
end

function sgSwoopAttack.update(dt, stateData)
  mcontroller.controlFace(1)
  if not hasTarget() then return true end

  local testPosition = vec2.add(self.spawnPosition, {-500, 0})
	
  local wallCollision = world.lineTileCollisionPoint(self.spawnPosition, testPosition)
  if wallCollision then
    local wallPos, normal = wallCollision[1], wallCollision[2]
	testPosition = vec2.norm(world.resolvePolyCollision(self.testPoly, wallPos, 5))
  end    
  
  if testPosition ~= nil then
    mcontroller.setVelocity({
      testPosition[1] * self.dashSpeed,
      0
    })
  else
    mcontroller.controlFly({ 0, 1 })
  end
  
  self.burstTimer = math.max(0, self.burstTimer - dt)
  if self.burstTimer == 0 then
	--Fire Projectile
	local toTarget = {0, -1}
	rangedAttack.aim(self.projectileSpawnOffset, toTarget)
	animator.playSound("dashFire")
	rangedAttack.fireOnce(stateData.projectileType, stateData.projectileParameters)
	  
	self.burstTimer = self.burstTime
  end
  
  local position = mcontroller.position()
  self.collided = world.lineTileCollisionPoint(position, vec2.add(position, {15, 0}))
  
  mcontroller.controlFace(-1)
  sgSwoopAttack.updateHead(stateData)
  
  if self.collided then
    return true
  end
end

function sgSwoopAttack.updateHead(stateData)
  animator.resetTransformationGroup("head")
  
  local targetAngle = -math.pi/2

  self.headAngle = (self.headAngle or 0) + (targetAngle - (self.headAngle or 0)) * self.angleApproach
  animator.rotateTransformationGroup("head", self.headAngle + self.headAngleOffset, self.headRotationCenter)
end

function sgSwoopAttack.leavingState(stateData)
  animator.rotateGroup("all", 0)
  animator.setAnimationState("head", "attackWinddown")
  monster.setDamageOnTouch(false)
end
