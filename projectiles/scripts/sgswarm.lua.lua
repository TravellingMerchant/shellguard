require "/scripts/vec2.lua"
require "/scripts/util.lua"

function init()
  if config.getParameter("speedEqualsPower") == true then -- increases damage the faster it moves
	self.speed = vec2.mag(mcontroller.velocity())
	self.power = projectile.getParameter("power")
	self.maxPowerMult = 4
  end

  self.targetSpeed = vec2.mag(mcontroller.velocity())

  self.maxControlForce = config.getParameter("maxHomingControlForce") * self.targetSpeed
  self.minControlForce = config.getParameter("minHomingControlForce") * self.targetSpeed
  
  self.controlForce = math.random() * (self.maxControlForce - self.minControlForce) + self.minControlForce

  self.maxWavePeriod = config.getParameter("maxWavePeriod")
  self.minWavePeriod = config.getParameter("minWavePeriod")

  self.wavePeriod = (math.random() * (self.minWavePeriod - self.maxWavePeriod) + self.minWavePeriod) / (2 * math.pi)

  self.maxWaveAmplitude = config.getParameter("maxWaveAmplitude")
  self.minWaveAmplitude = config.getParameter("minWaveAmplitude")

  self.waveAmplitude = math.random() * (self.maxWaveAmplitude - self.minWaveAmplitude) + self.minWaveAmplitude
  
  self.timer = self.wavePeriod * 0.25
  local vel = mcontroller.velocity()
  if vel[1] < 0 then
    self.waveAmplitude = -self.waveAmplitude
  end
  self.lastAngle = 0
end

function update(dt)
  if config.getParameter("speedEqualsPower") == true then
    local cSpeed = vec2.mag(mcontroller.velocity())
    local powerMult = math.min( cSpeed / (self.speed or 1), self.maxPowerMult)
    projectile.setPower(self.power * powerMult)
  end

  self.timer = self.timer + dt
  local newAngle = self.waveAmplitude * math.sin(self.timer / self.wavePeriod)

  mcontroller.setVelocity(vec2.rotate(mcontroller.velocity(), newAngle - self.lastAngle))

  self.lastAngle = newAngle

  local targets = world.entityQuery(mcontroller.position(), 20, {
      includedTypes = {"monster", "npc"},
      order = "nearest"
    })

  for _, target in ipairs(targets) do
    if entity.entityInSight(target) then
      local targetPos = world.entityPosition(target)
      local myPos = mcontroller.position()
      local dist = world.distance(targetPos, myPos)

      mcontroller.approachVelocity(vec2.mul(vec2.norm(dist), self.targetSpeed), self.controlForce)
      return
    end
  end
end
