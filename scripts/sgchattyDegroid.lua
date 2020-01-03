require "/scripts/messageutil.lua"
require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
	self.questTrigger = "ambitiousdrone1"
	self.dialogsData = root.assetJson("/dialog/fridgedroidconversation.config")
	
	-- Template setting for the dialog
	self.dialogTemplate = root.assetJson(self.dialogsData.confirmationTemplate)

	self.awaitTime = self.dialogsData.waitTime
	self.timer = 0
end

function update(dt)
	self.timer = self.timer - dt
	if self.timer < 0 then
		self.timer = self.awaitTime
		if player.hasCompletedQuest("ambitiousdrone1") then
			local messageBundle = util.randomChoice(self.dialogsData.messages)
			processMessageBundle(messageBundle)
		end
	end
	promises:update()
end

function processMessageBundle(messageBundle)
	for _, message in ipairs(messageBundle) do
		processMessage(message)
	end
end

function processMessage(message)
	if not conditionAccepted(message) then return end
	
	if message.type == "radiomessage" then
		player.radioMessage(message.radiomessage, message.delay or 0)
	elseif message.type == "action" then
		_ENV[message.action](message.args)
	elseif message.type == "dialog" then
		local dialog = self.dialogTemplate
		dialog.message = message.message
		promises:add(player.confirm(dialog), function (hasAccepted)
			if hasAccepted then
				processMessageBundle(message.confirm)
			else
				processMessageBundle(message.decline)
			end
		end)
	end
end

function conditionAccepted(message)
	if not message.condition then
		return true
	elseif message.condition.type == "worldType" then
		return message.condition.worldType == world.type()
	elseif message.condition.type == "hasItem" then
		return player.hasCountOfItem(message.condition.item, false) > (message.condition.count or 0)
	elseif message.condition.type == "hasCompletedQuest" then
		return player.hasCompletedQuest(message.condition.questId)
	end
end

-- Action handlers
function withdrawMoney(amount)
	if not amount then amount = math.random(player.currency("money")) end
	player.consumeCurrency("money", amount)
end

function spawnMonster(args)
	local entityPosition = world.entityPosition(player.id())
	world.spawnMonster(args.monsterType, vec2.add(entityPosition, args.spawnOffset or {0, 0}), args.monsterParameters or {})
end

function uninit()

end