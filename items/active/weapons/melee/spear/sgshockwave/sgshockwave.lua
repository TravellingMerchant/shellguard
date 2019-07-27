require "/scripts/util.lua"
require "/scripts/rect.lua"
require "/items/active/weapons/weapon.lua"

ShockWave = WeaponAbility:new()

function ShockWave:init()
end

function ShockWave:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  if self.weapon.currentAbility == nil and self.fireMode == "alt" and mcontroller.onGround() and not status.resourceLocked("energy") then
    self:setState(self.windup)
  end
end

-- Attack state: windup
function ShockWave:windup()
  self.weapon:setStance(self.stances.windup)
  self.weapon:updateAim()

  animator.setParticleEmitterActive(self.weapon.elementalType.."Charge", true)
  animator.playSound(self.weapon.elementalType.."charge")

  local wasFull = false
  local chargeTimer = 0
  while self.fireMode == "alt" and (chargeTimer == self.chargeTime or status.overConsumeResource("energy", (self.energyUsage / self.chargeTime) * self.dt)) do
    chargeTimer = math.min(self.chargeTime, chargeTimer + self.dt)

    if chargeTimer == self.chargeTime and not wasFull then
      wasFull = true
      animator.stopAllSounds(self.weapon.elementalType.."charge")
      animator.playSound(self.weapon.elementalType.."full", -1)
    end

    local chargeRatio = math.sin(chargeTimer / self.chargeTime * 1.57)
    self.weapon.relativeArmRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.armRotation, self.stances.windup.endArmRotation}))
    self.weapon.relativeWeaponRotation = util.toRadians(util.lerp(chargeRatio, {self.stances.windup.weaponRotation, self.stances.windup.endWeaponRotation}))

    mcontroller.controlModifiers({
      jumpingSuppressed = true,
      runningSuppressed = true
    })

    coroutine.yield()
  end

  animator.stopAllSounds(self.weapon.elementalType.."charge")
  animator.stopAllSounds(self.weapon.elementalType.."full")

  if chargeTimer > self.minChargeTime then
    self:setState(self.fire, chargeTimer / self.chargeTime)
  end
end

-- Attack state: fire
function ShockWave:fire(charge)
  self.weapon:setStance(self.stances.fire)

  self:fireShockwave(charge)
  animator.playSound("fire")

  util.wait(self.stances.fire.duration)
end

function ShockWave:reset()
  animator.setParticleEmitterActive(self.weapon.elementalType.."Charge", false)
  animator.stopAllSounds(self.weapon.elementalType.."charge")
  animator.stopAllSounds(self.weapon.elementalType.."full")
end

function ShockWave:uninit()
  self:reset()
end

-- Helper functions
function ShockWave:fireShockwave(charge)
  local impact, impactHeight = self:impactPosition()

  if impact then
    self.weapon.weaponOffset = {0, impactHeight + self.impactWeaponOffset}

    local charge = math.floor(charge * self.maxDistance)
    local directions = {1}
    if self.bothDirections then directions[2] = -1 end
    local positions = self:shockwaveProjectilePositions(impact, charge, directions)
    if #positions > 0 then
      animator.playSound(self.weapon.elementalType.."impact")
      local params = copy(self.projectileParameters)
      params.powerMultiplier = activeItem.ownerPowerMultiplier()
      params.power = params.power * config.getParameter("damageLevelMultiplier")
      params.actionOnReap = {
        {
          action = "projectile",
          inheritDamageFactor = 1,
          type = self.projectileType
        }
      }
      for i,position in pairs(positions) do
        local xDistance = world.distance(position, impact)[1]
        local dir = util.toDirection(xDistance)
        params.timeToLive = (math.floor(math.abs(xDistance))) * 0.025
        world.spawnProjectile("shockwavespawner", position, activeItem.ownerEntityId(), {dir,0}, false, params)
      end
    end
  end
end

function ShockWave:impactPosition()
  local dir = mcontroller.facingDirection()
  local startLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[1], {dir, 1}))
  local endLine = vec2.add(mcontroller.position(), vec2.mul(self.impactLine[2], {dir, 1}))

  local blocks = world.collisionBlocksAlongLine(startLine, endLine, {"Null", "Block"})
  if #blocks > 0 then
    return vec2.add(blocks[1], {0.5, 0.5}), endLine[2] - blocks[1][2] + 1
  end
end

function ShockWave:shockwaveProjectilePositions(impactPosition, maxDistance, directions)
  local positions = {}

  for _,direction in pairs(directions) do
    direction = direction * mcontroller.facingDirection()
    local position = copy(impactPosition)
    for i = 0, maxDistance do
      local continue = false
      for _,yDir in ipairs({0, -1, 1}) do
        local wavePosition = {position[1] + direction * i, position[2] + 0.5 + yDir + self.shockwaveHeight}
        local groundPosition = {position[1] + direction * i, position[2] + yDir}
        local bounds = rect.translate(self.shockWaveBounds, wavePosition)

        if world.pointTileCollision(groundPosition, {"Null", "Block", "Dynamic", "Slippery"}) and not world.rectTileCollision(bounds, {"Null", "Block", "Dynamic", "Slippery"}) then
          table.insert(positions, wavePosition)
          position[2] = position[2] + yDir
          continue = true
          break
        end
      end
      if not continue then break end
    end
  end

  return positions
end
