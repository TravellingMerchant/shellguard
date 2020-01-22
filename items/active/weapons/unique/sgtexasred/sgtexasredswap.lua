TexasRedAlt = WeaponAbility:new()

function TexasRedAlt:init()
	self.weapon.relativeWeaponRotation = 0
	self.weapon.relativeArmRotation = 0
	self.weapon:setStance(self.weapon.abilities[1].stances[self.weapon.currentType.."Idle"])
	if self.weapon.currentType == "gun" then
		activeItem.setCursor("/cursors/reticle0.cursor")
	else
		activeItem.setCursor("/cursors/pointer.cursor")
	end
end

function TexasRedAlt:update(dt, fireMode, shiftHeld)
	WeaponAbility.update(self, dt, fireMode, shiftHeld)

	if not self.weapon.currentAbility and self.fireMode == "alt" and shiftHeld then
		self:setState(self.switch)
	end
end

function TexasRedAlt:switch()
	self.weapon.activeTimer = 0
	if self.weapon.currentType == "gun" then
		self.weapon.currentType = "blade"
		self.lastType = "gun"
		activeItem.setCursor("/cursors/pointer.cursor")
	else
		self.weapon.currentType = "gun"
		self.lastType = "blade"
		activeItem.setCursor("/cursors/reticle0.cursor")
	end
	activeItem.setInstanceValue("currentType", self.weapon.currentType)

	self.weapon:setStance(self.stances[self.weapon.currentType.."Transition"])
	animator.playSound("swap")
	local progress = 0
	util.wait(self.stances[self.weapon.currentType.."Transition"].duration, function()
		local from = self.weapon.abilities[1].stances[self.lastType.."Idle"].weaponOffset or {0,0}
		local to = self.weapon.abilities[1].stances[self.weapon.currentType.."Idle"].weaponOffset or {0,0}
		self.weapon.weaponOffset = {interp.linear(progress, from[1], to[1]), interp.linear(progress, from[2], to[2])}
		local aimAngle, aimDirection = activeItem.aimAngleAndDirection(-0.25, activeItem.ownerAimPosition())
		if self.weapon.currentType == "gun" then
			self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.weapon.abilities[1].stances.bladeIdle.weaponRotation,self.weapon.abilities[1].stances.gunIdle.weaponRotation))
			self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, self.weapon.abilities[1].stances.bladeIdle.armRotation,aimAngle*180/math.pi+self.weapon.abilities[1].stances.gunIdle.armRotation))
		else
			self.weapon.relativeWeaponRotation = util.toRadians(interp.linear(progress, self.weapon.abilities[1].stances.gunIdle.weaponRotation, self.weapon.abilities[1].stances.bladeIdle.weaponRotation))
			self.weapon.relativeArmRotation = util.toRadians(interp.linear(progress, aimAngle*180/math.pi+self.weapon.abilities[1].stances.gunIdle.armRotation, self.weapon.abilities[1].stances.bladeIdle.armRotation))
		end
		progress = math.min(1.0, progress + (self.dt / self.stances[self.weapon.currentType.."Transition"].duration))
	end)
	self.weapon.relativeWeaponRotation = 0
	self.weapon.relativeArmRotation = 0
	self.weapon:setStance(self.weapon.abilities[1].stances[self.weapon.currentType.."Idle"])
end

function TexasRedAlt:uninit()
end