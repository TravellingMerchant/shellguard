function init()
  --Check our entityType
  self.entityId = entity.id()
  --Check if our entityType is not in the whitelist so we can expire the effect
  if config.getParameter("monsterWhitelist") then
    if not config.getParameter("monsterWhitelist")[self.entityId] then
      effect.expire()
    end
  end
    
  --Check for damage taken in the init() step to ensure that damage taken before the status was applied won't get calculated for the damage increase
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep

  script.setUpdateDelta(1)
end

function update(dt)	
  --Listen for damage taken
  local damageNotifications, nextStep = status.damageTakenSince(self.queryDamageSince)
  self.queryDamageSince = nextStep
  
  --Multiply damage if damage multiplication is enabled
  for _, notification in ipairs(damageNotifications) do
	if notification.healthLost > 1 and config.getParameter("damageAdditionPercentage", 0) > 0 then
	  local damageRequest = {}
	  damageRequest.damageType = "IgnoresDef"
	  damageRequest.damage = notification.damageDealt * config.getParameter("damageAdditionPercentage", 0)
	  damageRequest.damageSourceKind = notification.damageSourceKind
	  damageRequest.sourceEntityId = notification.sourceEntityId
	  status.applySelfDamageRequest(damageRequest)
	  effect.expire()
	end
  end
end
