--Scripted by nebulox, allows sticking into enemies and allies, along with distinguishing between friendly and enemy and doing an action respectively

require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  self.validEntityTypes = config.getParameter("validEntityTypes", {"npc", "monster", "player"})
  self.enemyAllyDistinguishing = config.getParameter("enemyAllyDistinguishing", false)
  self.allyActionOnStick = config.getParameter("allyActionOnStick")
  self.enemyActionOnStick = config.getParameter("enemyActionOnStick")
  self.searchDistance = config.getParameter("searchDistance", 0.1)
  self.targetTime = config.getParameter("stickToTargetTime")
  self.stickingOffset = {0, 0}
  
  message.setHandler("trigger", function()
      projectile.die()
    end)
	
  self.stickingTarget = nil
  self.stuckToTarget = false
  self.stuckToGround = false
  self.hasActioned = false
end

function update(dt)
  local targets = {}
  
  --Look for a target to stick to
  if not self.stickingTarget then
	local projectileLengthVector = vec2.norm(mcontroller.velocity())
	self.stuckToGround = world.lineTileCollision(mcontroller.position(), vec2.add(mcontroller.position(), projectileLengthVector))
	targets = world.entityQuery(mcontroller.position(), self.searchDistance, {
	  withoutEntityId = projectile.sourceEntity(),
	  includedTypes = self.validEntityTypes,
	  order = "nearest"
	})
  end

  --If targets were found, set tracking info to the closest entity, unless we were already stuck in the ground
  if #targets > 0 and not self.stuckToGround then
	if world.entityExists(targets[1]) then
	  self.stickingTarget = targets[1]
	  self.stickingOffset = world.distance(mcontroller.position(), world.entityPosition(self.stickingTarget))
	  mcontroller.setVelocity({0, 0})
	  self.stuckToTarget = world.entityExists(self.stickingTarget)
	  if self.targetTime then
		projectile.setTimeToLive(config.getParameter("stickToTargetTime"))
		self.targetTime = false
	  end
	end
  end
  
  --While our target lives, make the projectile follow the target
  if self.stickingTarget and world.entityExists(self.stickingTarget) then
    if self.enemyAllyDistinguishing and not self.hasActioned then
      if world.entityDamageTeam(self.stickingTarget).type == "enemy" and self.allyActionOnStick then
		projectile.processAction(self.allyActionOnStick)
	  elseif world.entityDamageTeam(self.stickingTarget).type == "friendly" and self.enemyActionOnStick then
		projectile.processAction(self.enemyActionOnStick)
	  end
	  self.hasActioned = true
	end
	local targetStickingPosition = vec2.add(world.entityPosition(self.stickingTarget), self.stickingOffset)
	mcontroller.setPosition(targetStickingPosition)
	local stickingVelocity = vec2.mul(self.stickingOffset, -1)
	mcontroller.setVelocity(stickingVelocity)
  elseif self.stickingTarget and not world.entityExists(self.stickingTarget) then
	self.stickingTarget = nil
    projectile.die()
  else
	self.stickingTarget = nil
  end
  
  if self.stuckToGround then
	if config.getParameter("proximitySearchRadius") then
	  local targets = world.entityQuery(mcontroller.position(), self.proximitySearchRadius, {
		withoutEntityId = projectile.sourceEntity(),
		includedTypes = {"creature"},
		order = "nearest"
	  })

	  for _, target in ipairs(targets) do
		if entity.entityInSight(target) and world.entityCanDamage(projectile.sourceEntity(), target) then
		  projectile.die()
		  return
		end
	  end
	end
  end
end
