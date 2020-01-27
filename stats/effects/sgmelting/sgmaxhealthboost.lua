function init()
  effect.addStatModifierGroup({
    {stat = "maxHealth", amount = config.getParameter("healthAmount", 0)},
    {stat = "maxHealth", baseMultiplier = config.getParameter("healthBaseMultiplier", 1.0)},
    {stat = "maxHealth", effectiveMultiplier = config.getParameter("healthEffectiveMultiplier", 1.0)},
  })

  script.setUpdateDelta(0)
end

function update(dt)
end

function uninit()
end
