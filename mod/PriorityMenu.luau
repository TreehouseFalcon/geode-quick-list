--[[
    PriorityMenu exists because the quick list button does not
    capture input when clicking within the bounds of both the LevelCell
    "View" button and the quick list button.
]]

local cocos = geode.cocos2d

local PRIORITY_MENU_ID = "add-to-list-priority-menu"
local PRIORITY_MENU_TOUCH_PRIORITY = -129

local function getPriorityMenu(mainLayer: CCNode): CCMenu?
	local menu = mainLayer:getChildByID(PRIORITY_MENU_ID) :: CCMenu?
	if not menu then
		menu = cocos.CCMenu.create()
		if not menu then
			return nil
		end

		menu:setID(PRIORITY_MENU_ID)
		menu:setPosition({ x = 0, y = 0 })
		mainLayer:addChild(menu, 1001)
	end

	return menu
end

local function setPriorityMenuTouchPriority(menu: CCMenu)
	if not menu or geode.fields(menu).quickListPriorityApplied then
		return
	end

	if not menu:isRunning() then
		menu:scheduleOnce(function()
			setPriorityMenuTouchPriority(menu)
		end, 0)
		return
	end

	menu:setHandlerPriority(PRIORITY_MENU_TOUCH_PRIORITY)
	geode.fields(menu).quickListPriorityApplied = true
end

return table.freeze({
	getOrCreate = getPriorityMenu,
	setTouchPriority = setPriorityMenuTouchPriority,
})
