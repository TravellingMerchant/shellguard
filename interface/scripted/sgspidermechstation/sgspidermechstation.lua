require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
	self.completeText = config.getParameter("completeText")

	self.energyFormat = config.getParameter("energyFormat")
	self.drainFormat = config.getParameter("drainFormat")

	self.imageBasePath = config.getParameter("imageBasePath")
	
	self.partTypeData = {
		primaryGun = root.assetJson("/vehicles/wfsystem/wfcrabmech/parts/primarygun.wfcrabconfig"),
		secondaryGun = root.assetJson("/vehicles/wfsystem/wfcrabmech/parts/secondarygun.wfcrabconfig"),
		boosters = root.assetJson("/vehicles/wfsystem/wfcrabmech/parts/boosters.wfcrabconfig"),
		chassis = root.assetJson("/vehicles/wfsystem/wfcrabmech/parts/chassis.wfcrabconfig"),
		legs = root.assetJson("/vehicles/wfsystem/wfcrabmech/parts/legs.wfcrabconfig")
	}
	
	self.partSet = {}
	for partType, partData in pairs(self.partTypeData) do
		for partName, partConfig in pairs(partData or {}) do
			self.partSet[partType] = partName
			break
		end
	end
		
	self.partTypeSelectedLabel = config.getParameter("partTypeSelectedLabel",{})
	
	self.primaryColorIndex = 0
	self.secondaryColorIndex = 0

	self.previewCanvas = widget.bindCanvas("cvsPreview")

	widget.setImage("imgPrimaryColorPreview", colorPreviewImage(self.primaryColorIndex))
	widget.setImage("imgSecondaryColorPreview", colorPreviewImage(self.secondaryColorIndex))

	self.paletteConfig = root.assetJson("/vehicles/modularmech/mechpalettes.config")
	self.defaultPrimaryColors = {"A3391D","7B1700","5B0600","3D0001"}
	self.defaultSecondaryColors = {"3B3B3B","2F2F2F","202020","181818"}

	updatePreview()
	partSelectionGroup(nil,"chassis")
end

function update(dt)
end

function uninit()
	local storedItem = widget.itemSlotItem("itemSlot_Spawner")
	if storedItem then
		player.giveItem(storedItem)
	end
end

function swapItem(widgetName)
	local currentItem = widget.itemSlotItem(widgetName)
	local swapItem = player.swapSlotItem()

	if not swapItem or swapItem.name == "wfcrabdeployer" then
		player.setSwapSlotItem(currentItem)
		widget.setItemSlotItem(widgetName, swapItem)
	end
	local newCurrentItem = widget.itemSlotItem(widgetName)
	if newCurrentItem and newCurrentItem.name == "wfcrabdeployer" and newCurrentItem.parameters and newCurrentItem.parameters.wfCrabDeploymentData then
		for partType, partName in pairs(newCurrentItem.parameters.wfCrabDeploymentData.partIds or {}) do
			self.partSet[partType] = partName
		end
		self.primaryColorIndex = newCurrentItem.parameters.wfCrabDeploymentData.primaryColorIndex or 0
		self.secondaryColorIndex = newCurrentItem.parameters.wfCrabDeploymentData.secondaryColorIndex or 0
		colorSelectionChanged()
	end
end

function nextPrimaryColor()
	self.primaryColorIndex = validateColorIndex(self.primaryColorIndex + 1)
	colorSelectionChanged()
end

function prevPrimaryColor()
	self.primaryColorIndex = validateColorIndex(self.primaryColorIndex - 1)
	colorSelectionChanged()
end

function nextSecondaryColor()
	self.secondaryColorIndex = validateColorIndex(self.secondaryColorIndex + 1)
	colorSelectionChanged()
end

function prevSecondaryColor()
	self.secondaryColorIndex = validateColorIndex(self.secondaryColorIndex - 1)
	colorSelectionChanged()
end

function colorSelectionChanged()
	widget.setImage("imgPrimaryColorPreview", colorPreviewImage(self.primaryColorIndex))
	widget.setImage("imgSecondaryColorPreview", colorPreviewImage(self.secondaryColorIndex))
	updatePreview()
end

function updateComplete()
	if self.disabled then
		widget.setVisible("imgIncomplete", true)
		widget.setText("lblStatus", self.disabledText)
	elseif itemSetComplete(self.itemSet) then
		widget.setVisible("imgIncomplete", false)
		widget.setText("lblStatus", self.completeText)
	else
		widget.setVisible("imgIncomplete", true)
		widget.setText("lblStatus", self.incompleteText)
	end
end

function colorPreviewImage(colorIndex)
	if colorIndex == 0 then
		return self.imageBasePath .. "paintbar_default.png"
	else
		local img = self.imageBasePath .. "paintbar.png"
		local toColors = self.paletteConfig.swapSets[colorIndex]
		for i, fromColor in ipairs(self.paletteConfig.primaryMagicColors) do
			img = string.format("%s?replace=%s=%s", img, fromColor, toColors[i])
		end
		return img
	end
end

function updatePreview()
	-- assemble vehicle and animation config
	local params = buildVehicleParameters(self.partSet, self.primaryColorIndex, self.secondaryColorIndex)
	local animationConfig = root.assetJson("/vehicles/wfsystem/wfcrabmech/wfcrabmech.animation")
	animationConfig = util.mergeTable(animationConfig, params.animationCustom or {})

	-- build list of parts to preview
	local previewParts = {}
	for partName, partConfig in pairs(animationConfig.animatedParts.parts) do
		local partProperties = partConfig.properties or {}
		if partConfig.partStates then
			for stateName, stateConfig in pairs(partConfig.partStates) do
				if stateConfig.off then
					partProperties = util.mergeTable(partProperties, stateConfig.off.properties or {})
					break
				elseif stateConfig.idle then
					partProperties = util.mergeTable(partProperties, stateConfig.idle.properties or {})
					break
				end
			end
		end
		if partProperties.image then
			local scaleFactor = 0.5
			local partImage = {
				centered = partProperties.centered,
				zLevel = partProperties.zLevel or 0,
				image = partProperties.image,
				offset = vec2.mul(partProperties.offset or {0, 0}, 8 * scaleFactor),
				scale = scaleFactor,
				rotation = 0
			}
			if partName == "upperLegFrontRight" then
				partImage.offset = vec2.mul(params.baseChassisOffsets and params.baseChassisOffsets.rF or {3,-4.75},8 * scaleFactor)
				partImage.rotation = 0.523599
			elseif partName == "upperLegFrontLeft" then
				partImage.offset = vec2.mul(params.baseChassisOffsets and params.baseChassisOffsets.lF or {-3,-4.75},8 * scaleFactor)
				partImage.rotation = 2.61799
			elseif partName == "lowerLegFrontRight" then
				partImage.offset = vec2.mul(vec2.add(params.baseChassisOffsets and params.baseChassisOffsets.rF or {3,-4.75},vec2.rotate({params.upperLegLength or 6,0},0.523599)),8 * scaleFactor)
				partImage.rotation = 4.88692
			elseif partName == "lowerLegFrontLeft" then
				partImage.offset = vec2.mul(vec2.add(params.baseChassisOffsets and params.baseChassisOffsets.rF or {-3,-4.75},vec2.rotate({params.upperLegLength or 6,0},2.61799)),8 * scaleFactor)
				partImage.rotation = 4.53786
			elseif partName == "upperLegBackRight" then
				partImage.offset = vec2.mul(params.baseChassisOffsets and params.baseChassisOffsets.rB or {3,-4.5},8 * scaleFactor)
				partImage.rotation = 0.959931
			elseif partName == "upperLegBackLeft" then
				partImage.offset = vec2.mul(params.baseChassisOffsets and params.baseChassisOffsets.lB or {-3,-4.5},8 * scaleFactor)
				partImage.rotation = 2.18166
			elseif partName == "lowerLegBackRight" then
				partImage.offset = vec2.mul(vec2.add(params.baseChassisOffsets and params.baseChassisOffsets.rB or {3,-4.5},vec2.rotate({params.upperLegLength or 6,0},0.959931)),8 * scaleFactor)
				partImage.rotation = 4.79966
			elseif partName == "lowerLegBackLeft" then
				partImage.offset = vec2.mul(vec2.add(params.baseChassisOffsets and params.baseChassisOffsets.lB or {-3,-4.5},vec2.rotate({params.upperLegLength or 6,0},2.18166)),8 * scaleFactor)
				partImage.rotation = 4.62512
			end
			table.insert(previewParts,partImage)
		end
	end

	table.sort(previewParts, function(a, b) return a.zLevel < b.zLevel end)

	-- replace directive tags in preview images
	previewParts = util.replaceTag(previewParts, "paletteSwaps", params.colorSwaps)
	previewParts = util.replaceTag(previewParts, "globalDirectives", "")
	previewParts = util.replaceTag(previewParts, "frame", 1)

	-- draw preview images
	self.previewCanvas:clear()

	local canvasCenter = vec2.mul(widget.getSize("cvsPreview"), 0.5)

	for _, part in ipairs(previewParts) do
		local pos = vec2.add(canvasCenter, part.offset)
		self.previewCanvas:drawImageDrawable(part.image, pos, part.scale, nil, part.rotation)
	end
end

function doConstruct()
	local keySlot = widget.itemSlotItem("itemSlot_Spawner")
	if keySlot and keySlot.name == "wfcrabdeployer" then
		widget.setItemSlotItem("itemSlot_Spawner",nil)
		player.giveItem({name = "wfcrabdeployer", count = 1, parameters = {inventoryIcon = "/vehicles/wfsystem/wfcrabmech/wfcrabdeployer.png:full", description = string.format("%s\n%s\n%s\n%s\n%s",self.partTypeData.chassis[self.partSet.chassis].description.name,self.partTypeData.primaryGun[self.partSet.primaryGun].description.name,self.partTypeData.secondaryGun[self.partSet.secondaryGun].description.name,self.partTypeData.legs[self.partSet.legs].description.name,self.partTypeData.boosters[self.partSet.boosters].description.name), shortdescription = "C.R.A.B Deployer", wfCrabDeploymentData = buildVehicleParameters(self.partSet, self.primaryColorIndex, self.secondaryColorIndex)}})
	end
end

function partSelectionGroup(button,partType)
	self.selectedPart = partType
	--widget.setText("lblDescription", config.getParameter("selectPartDescription"))
	widget.setText("lblSlot", self.partTypeSelectedLabel[partType])
	widget.clearListItems("partScrollArea.partList")

	local preSelected = nil
	local modifiedPartList = {}
	for partId,partData in pairs(self.partTypeData[partType] or {}) do
		local modifiedPartData = partData
		modifiedPartData.partId = partId
		modifiedPartData.description = modifiedPartData.description or {}
		modifiedPartData.description.name = modifiedPartData.description.name or "FAILED DESCRIPTION"
		table.insert(modifiedPartList,modifiedPartData)
	end
	table.sort(modifiedPartList, function(a, b) return a.description.name < b.description.name end)
	for i,partData in ipairs(modifiedPartList) do
		local partId = partData.partId
		local listItem = widget.addListItem("partScrollArea.partList")
		if partId == self.partSet[self.selectedPart] then
			preSelected = listItem
		end
		widget.setText(string.format("partScrollArea.partList.%s.partName", listItem), partData.description.name)
		widget.setData(string.format("partScrollArea.partList.%s", listItem), partId)
	end
	if preSelected then
		widget.setListSelected("partScrollArea.partList",preSelected)
	end
	
	self.tweenSelector = coroutine.wrap(function(dt)
		local position = widget.getPosition("imgSlotSelect")
		local timer = 0
		while timer < self.selectorTime do
			timer = math.min(timer + dt, self.selectorTime)
			local ratio = timer / self.selectorTime
			widget.setPosition("imgSlotSelect", {position[1], interp.sin(ratio, position[2], self.selectorHeights[slot])})
			coroutine.yield()
		end
		self.tweenSelector = nil
	end)
end

function partSelected()
	local listItem = widget.getListSelected("partScrollArea.partList")
	if listItem and self.selectedPart then
		local partId = widget.getData(string.format("partScrollArea.partList.%s", listItem))
		self.partSet[self.selectedPart] = partId
	end
	updatePreview()
end

function buildVehicleParameters(partSet, primaryColorIndex, secondaryColorIndex)
	local params = {}
	
	local copiedTable = copy(self.partTypeData)

	params.partIds = {}

	for partType, partId in pairs(partSet) do
		params = util.mergeTable(params,copiedTable[partType][partId])
		params.partIds[partType] = partId
	end
	params.primaryColorIndex = primaryColorIndex
	params.secondaryColorIndex = secondaryColorIndex
	params.colorSwaps = buildSwapDirectives(primaryColorIndex,secondaryColorIndex)
	return params
end

function validateColorIndex(colorIndex)
	if type(colorIndex) ~= "number" then return 0 end

	if colorIndex > #self.paletteConfig.swapSets or colorIndex < 0 then
		colorIndex = colorIndex % (#self.paletteConfig.swapSets + 1)
	end
	return colorIndex
end

function buildSwapDirectives(primaryIndex, secondaryIndex)
	local result = ""
	local primaryColors = primaryIndex == 0 and self.defaultPrimaryColors or self.paletteConfig.swapSets[primaryIndex]
	for i, fromColor in ipairs(self.paletteConfig.primaryMagicColors) do
		result = string.format("%s?replace=%s=%s", result, fromColor, primaryColors[i])
	end
	local secondaryColors = secondaryIndex == 0 and self.defaultSecondaryColors or self.paletteConfig.swapSets[secondaryIndex]
	for i, fromColor in ipairs(self.paletteConfig.secondaryMagicColors) do
		result = string.format("%s?replace=%s=%s", result, fromColor, secondaryColors[i])
	end
	return result
end
