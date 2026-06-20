local cocos = geode.cocos2d
local gd = geode.gd

local BUTTON_ID = "add-to-list-button"
local PRIORITY_MENU_ID = "add-to-list-priority-menu"
local PRIORITY_BUTTON_ID = "add-to-list-priority-button"
local OPEN_MENU_SETTING_ID = "open-add-to-list-menu"
local ADD_TO_LIST_BUTTON_SPRITE = "GJ_listAddBtn_001.png"
local ADD_TO_LIST_BUTTON_SCALE = 0.62
local PRIORITY_MENU_TOUCH_PRIORITY = -129

local function shouldAttachQuickListButton(level): boolean
	if not level then
		return false
	end

	return level.m_levelType == geode.gd.GJLevelType.SearchResult
end

local function shouldOpenAddToListMenu(): boolean
	local ok, value = pcall(function()
		return geode.Mod.getSettingValue(OPEN_MENU_SETTING_ID)
	end)
	return ok and value == true
end

local function getMenuParent(anchor: CCNode?): CCNode?
	if not anchor then
		return nil
	end

	local current: CCNode = anchor
	while current:getParent() do
		current = current:getParent() :: CCNode
	end

	return current
end

local function openAddToListMenu(level, sender, anchor: CCNode?)
	if not level then
		return
	end

	task.defer(function()
		local layer = gd.LevelInfoLayer.create(level, false)
		if not layer then
			return
		end

		local parent = getMenuParent(anchor)
		if not parent then
			return
		end

		parent:addChild(layer, 999)
		layer:onAddToList(sender)

		layer:scheduleOnce(function()
			if layer:getParent() then
				layer:removeFromParentAndCleanup(true)
			end
		end, 0)
	end)
end

local function getTopLocalList(): GJLevelList?
	local localLevelManager = gd.LocalLevelManager.sharedState()
	if not localLevelManager then
		return nil
	end

	local lists = localLevelManager:getCreatedLists(0)
	if not lists or lists:count() == 0 then
		return nil
	end

	return lists:objectAtIndex(0) :: GJLevelList?
end

local function topLocalListContainsLevel(level: GJGameLevel): boolean
	local listOk, listOrErr = pcall(getTopLocalList)
	if not listOk then
		print("Quick List: failed to check top local list: " .. tostring(listOrErr))
		return false
	end

	local list = listOrErr
	if not list then
		return false
	end

	local levels = list.m_levels
	if not levels then
		return false
	end

	return table.find(levels, level.m_levelID) ~= nil
end

local function addLevelToTopLocalList(level): boolean
	if not level then
		return false
	end

	local listOk, listOrErr = pcall(getTopLocalList)
	if not listOk then
		print("Quick List: failed to find top local list: " .. tostring(listOrErr))
		return false
	end

	local list = listOrErr
	if not list then
		print("Quick List: no local lists found, opening add-to-list menu")
		return false
	end

	local gameLevelManager = gd.GameLevelManager.sharedState()
	if not gameLevelManager then
		print("Quick List: GameLevelManager is unavailable, opening add-to-list menu")
		return false
	end

	local ok, err = pcall(function()
		list:addLevelToList(level)
		gameLevelManager:saveLevelList(list)
	end)
	if not ok then
		print("Quick List: failed to add level to top local list: " .. tostring(err))
		return false
	end

	print("Quick List: added level to " .. list.m_listName)
	return true
end

local function addLevelOrOpenMenu(level, sender, anchor: CCNode?)
	if shouldOpenAddToListMenu() then
		openAddToListMenu(level, sender, anchor)
		return false
	end

	if addLevelToTopLocalList(level) then
		return true
	end

	openAddToListMenu(level, sender, anchor)
	return false
end

local function getMainLayer(cell): CCNode?
	return cell:getChildByID("main-layer")
end

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

local function getQuickListButtonPosition(viewButton: CCNode): CCPoint
	local position: CCPoint = viewButton:getPosition()
	local width: number = viewButton:getScaledContentWidth()
	local height: number = viewButton:getScaledContentHeight()

	return {
		x = position.x - width * 0.5,
		y = position.y + height * 0.5 - 2,
	}
end

local function convertPositionBetweenNodes(
	position: CCPoint,
	fromNode: CCNode,
	toNode: CCNode
): CCPoint
	return toNode:convertToNodeSpace(fromNode:convertToWorldSpace(position))
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

local function resetButtonScale(button: CCMenuItemSpriteExtra)
	if not button then
		return
	end

	button:stopAllActions()
	button:unselected()
	button:setScale(1)
	button.m_baseScale = 1
end

local function setupQuickListButton(button: CCMenuItemSpriteExtra, id, position)
	button:setID(id)
	button:setScale(1)
	button.m_baseScale = 1
	button:setSizeMult(1.35)
	button:setPosition(position)
end

local function createQuickListButton(id, position, callback): CCMenuItemSpriteExtra?
	local sprite = cocos.CCSprite.createWithSpriteFrameName(ADD_TO_LIST_BUTTON_SPRITE)
	if not sprite then
		return nil
	end
	sprite:setScale(ADD_TO_LIST_BUTTON_SCALE)

	local button: CCMenuItemSpriteExtra? = nil
	button = cocos.CCMenuItemSpriteExtra.create(sprite, function()
		resetButtonScale(button :: CCMenuItemSpriteExtra)
		callback(button)
	end)
	if not button then
		return nil
	end

	setupQuickListButton(button, id, position)
	return button
end

local function upsertQuickListButton(
	menu: CCMenu,
	id,
	position,
	callback: (CCMenuItemSpriteExtra?) -> ()
): CCMenuItemSpriteExtra?
	local button = menu:getChildByID(id) :: CCMenuItemSpriteExtra?
	if button then
		menu:reorderChild(button, 1000)
		setupQuickListButton(button, id, position)
		return button
	end

	button = createQuickListButton(id, position, callback)
	if button then
		menu:addChild(button, 1000)
	end

	return button
end

local function hideQuickListButtons(mainMenu: CCMenu?, priorityMenu: CCMenu?)
	local button = mainMenu and mainMenu:getChildByID(BUTTON_ID)
	if button then
		button:setVisible(false)
		button:removeFromParentAndCleanup(true)
	end

	local priorityButton = priorityMenu and priorityMenu:getChildByID(PRIORITY_BUTTON_ID)
	if priorityButton then
		priorityButton:setVisible(false)
		priorityButton:removeFromParentAndCleanup(true)
	end
end

local function addListButtonToCell(cell, level)
	if not cell or not level then
		return
	end

	if not shouldOpenAddToListMenu() and topLocalListContainsLevel(level) then
		return
	end

	local mainLayer = getMainLayer(cell)
	if not mainLayer then
		return
	end

	local mainMenu = mainLayer:getChildByID("main-menu") :: CCMenu?
	if not mainMenu then
		return
	end

	local viewButton = mainMenu:getChildByID("view-button") :: CCNode?
	if not viewButton then
		return
	end

	local mainMenuPosition = getQuickListButtonPosition(viewButton)
	local priorityMenu: CCMenu? = nil
	local openForCell = function(button: CCMenuItemSpriteExtra?)
		if addLevelOrOpenMenu(cell.m_level, (button :: any) :: CCObject, mainLayer) then
			hideQuickListButtons(mainMenu, priorityMenu)
		end
	end

	upsertQuickListButton(mainMenu, BUTTON_ID, mainMenuPosition, openForCell)

	priorityMenu = getPriorityMenu(mainLayer)
	if not priorityMenu then
		return
	end

	local priorityPosition =
		convertPositionBetweenNodes(mainMenuPosition, mainMenu, priorityMenu)
	upsertQuickListButton(priorityMenu, PRIORITY_BUTTON_ID, priorityPosition, openForCell)

	setPriorityMenuTouchPriority(priorityMenu)
end

local function scheduleCellButtonSetup(cell, level)
	if not cell or not shouldAttachQuickListButton(level) then
		return
	end

	task.defer(function()
		local ok, err = pcall(function()
			addListButtonToCell(cell, level)
		end)
		if not ok then
			print("Quick List: failed to add button: " .. tostring(err))
		end
	end)
end

geode.hook("geode.gd.LevelCell:loadFromLevel/1", {
	after = function(cell, level)
		scheduleCellButtonSetup(cell, level)
		return
	end,
})
