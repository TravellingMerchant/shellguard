function init()
  effect.addStatModifierGroup({
    {stat = "protection", amount = 100.0},
		{stat = "invulnerable", amount = 1},
		{stat = "maxHealth", amount = 3000000}
  })

   script.setUpdateDelta(0)
end

function update(dt)

end

function uninit()
  
end
