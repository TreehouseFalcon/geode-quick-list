local function getQuickListButtonPosition(viewButton: CCNode): CCPoint
	local position: CCPoint = viewButton:getPosition()
	local width: number = viewButton:getScaledContentWidth()
	local height: number = viewButton:getScaledContentHeight()

	return {
		x = position.x - width * 0.5,
		y = position.y + height * 0.5 - 2,
	}
end

return getQuickListButtonPosition
