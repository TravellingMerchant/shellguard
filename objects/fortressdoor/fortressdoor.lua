require "/scripts/rect.lua"
require "/scripts/util.lua"
require "/scripts/status.lua"

function init()
	--Setup message handler for boss
  message.setHandler("becomeBreakable", function() becomeBreakable() end)
	
	--Set door state
  animator.setAnimationState("doorState", "default")
	
	--Set collission spaces
  setupMaterialSpaces()
  object.setMaterialSpaces(self.closedMaterialSpaces)
	
	--Set on init if breakable
	storage.breakable = false
end

function update(dt)
	--Check if breakable, if not make the door effectively invincible
	if not storage.breakable then
		object.setHealth(50000)
	end
	if object.health() <= 49000 and storage.breakable then
	--Set door state
		animator.setAnimationState("doorState", "destroyed")
		animator.playSound("break")
		updateLightAndCollision()
		object.setMaterialSpaces(self.openMaterialSpaces)
    world.spawnProjectile("mechexplosion", vec2.add(object.position(), config.getParameter("explosionOffset", {0,0})), entity.id(), {0,0})
		storage.breakable = false
	end
end

--Make it breakable upon receiving message
function becomeBreakable()
	storage.breakable = true
end

function updateLightAndCollision()
  object.setLightColor(config.getParameter("closedLight", {0,0,0,0}))
  setupMaterialSpaces()
  object.setMaterialSpaces(storage.brokeDoor and self.openMaterialSpaces or self.closedMaterialSpaces)
end

function setupMaterialSpaces()
  self.closedMaterialSpaces = config.getParameter("closedMaterialSpaces")
  if not self.closedMaterialSpaces then
    self.closedMaterialSpaces = {}
    local metamaterial = "metamaterial:door"
    for i, space in ipairs(object.spaces()) do
      table.insert(self.closedMaterialSpaces, {space, metamaterial})
    end
  end
  self.openMaterialSpaces = config.getParameter("openMaterialSpaces", {})
end