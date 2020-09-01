function update()
  localAnimator.clearDrawables()

  VehicleBlocked, VehiclePlaceable, VehicleEmpty, VehicleUnconfigured = 1, 2, 3, 4

  local vehicleState = animationConfig.animationParameter("vehicleState")

  if (vehicleState == VehicleEmpty or vehicleState == VehicleUnconfigured) then
    return {}
  else
    local vehicleImage = animationConfig.animationParameter("vehicleImage")
    local spawnPosition = activeItemAnimation.ownerAimPosition()

    local highlightColor = vehicleState == VehiclePlaceable and {150, 255, 150, 96} or {255, 150, 150, 128}

    localAnimator.addDrawable({
      image = vehicleImage,
      position = spawnPosition,
      color = highlightColor,
      fullbright = true
    })
  end
end
