--------------------------------------------------------------------------------
dieState = {}

function dieState.enterWith(params)
  if not params.die then return nil end
  
  rangedAttack.setConfig(config.getParameter("projectiles.deathexplosion.type"), config.getParameter("projectiles.deathexplosion.config"), 0.2)

  return {
    timer = 3,
	sayTime = 1,
    rotateInterval = 0.1,
    rotateAngle = 0.05,
    deathSound = true
  }
end

function dieState.enteringState(stateData)
  world.objectQuery(mcontroller.position(), 50, { name = "lunarbaselaser", callScript = "openLunarBaseDoor" })

  animator.setAnimationState("coreIdle", "off")
  animator.setAnimationState("blastShield", "winddown")
  
  local playerId = world.entityName(world.playerQuery(mcontroller.position(), 50, {order = "random"})[1])
  local currentLine = 1
  
  if stateData.sayTime > 0 then
	monster.sayPortrait(config.getParameter("dialog.death"..currentLine), config.getParameter("chatPortrait"), { player = playerId })
	if stateData.sayTime <= 0 then
	  stateData.sayTime = 1
	  if currentLine < 3 then
	    currentLine = currentLine + 1
	  end
	end
  end
	  
  animator.setAnimationState("stages", "destroyed")
  monster.setDamageBar("none")
  
  animator.playSound("destruction")
  animator.playSound("death")

  --Explode to signify death
    for i = 1, 7 do
      local randAngle = math.random() * math.pi * 2
      local spawnPosition = vec2.add(mcontroller.position(), vec2.rotate({math.random() * 8, 0}, randAngle))
      local aimVector = {math.cos(randAngle), math.sin(randAngle)}
      local projectile = "mechexplosion"
      local speed = math.random() * 60
      world.spawnProjectile(projectile, spawnPosition, entity.id(), aimVector, false, {
        power = 0
      })
    end
end

function dieState.update(dt, stateData)
  stateData.sayTime = stateData.sayTime - dt  
  if stateData.sayTime > 0 then
    stateData.sayTime = stateData.sayTime - dt
  end

  local angle = dieState.angleFactorFromTime(stateData.timer, stateData.rotateInterval) * stateData.rotateAngle - stateData.rotateAngle / 2

  stateData.timer = stateData.timer - dt

  if stateData.timer < 0.2 and stateData.deathSound then
    stateData.deathSound = false
  end

  --Since we want a destroyed final fortress due to the finisher, dont kill it and leave it alive with no state  
  --Lets also clear the health bar cus the boss is dead
  if stateData.timer < 0 then
    animator.rotateGroup("core", 0, true)
    --self.dead = true
  else
    animator.rotateGroup("core", angle, true)
  end
  
  --If it returns true, the phase ends which idk what would happen but probably an error
  return false
end

--basic triangle wave
function dieState.angleFactorFromTime(timer, interval)
  local modTime = interval - (timer % interval)
  if modTime < interval / 2 then
    return modTime / (interval / 2)
  else
    return (interval - modTime) / (interval / 2) 
  end
end
