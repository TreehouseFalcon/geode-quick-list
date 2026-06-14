local cocos = geode.cocos2d
local gd = geode.gd

local BUTTON_ID = "add-to-list-button"
local PRIORITY_MENU_ID = "add-to-list-priority-menu"
local PRIORITY_BUTTON_ID = "add-to-list-priority-button"
local OPEN_MENU_SETTING_ID = "open-add-to-list-menu"
local ADD_TO_LIST_BUTTON_SPRITE = "GJ_listAddBtn_001.png"
local ADD_TO_LIST_BUTTON_SCALE = 0.62
local PRIORITY_MENU_TOUCH_PRIORITY = -129
local MAX_RETAINED_PROXY_LAYERS = 8

local GJ_LEVEL_TYPE = {
	Default = 0,
	Main = 1,
	Editor = 2,
	Saved = 3,
	SearchResult = 4,
}

local retainedProxyLayers = {}

local function shouldOpenAddToListMenu(): boolean
	return geode.Mod.getSettingValue(OPEN_MENU_SETTING_ID) == true
end

local function trimRetainedProxyLayers()
	while #retainedProxyLayers > MAX_RETAINED_PROXY_LAYERS do
		local layer = table.remove(retainedProxyLayers, 1)
		if layer then
			layer:release()
		end
	end
end

local function createAddToListProxy(level: GJGameLevel): LevelInfoLayer?
	local levelFields = geode.fields(level)
	levelFields.quickListProxyOwner = true
	local layer = gd.LevelInfoLayer.create(level, false)
	levelFields.quickListProxyOwner = nil
	if not layer then
		return nil
	end

	layer:retain()
	geode.fields(layer).quickListProxy = true
	table.insert(retainedProxyLayers, layer)
	trimRetainedProxyLayers()

	return layer
end

local function openAddToListMenu(level, sender)
	if not level then
		return
	end

	task.defer(function()
		local layer = createAddToListProxy(level)
		if not layer then
			return
		end

		layer:onAddToList(sender)
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

local function addLevelOrOpenMenu(level, sender)
	if shouldOpenAddToListMenu() then
		openAddToListMenu(level, sender)
		return false
	end

	if addLevelToTopLocalList(level) then
		return true
	else
		openAddToListMenu(level, sender)
		return false
	end
end

local function getMainLayer(cell)
	local mainLayer = cell:getChildByID("main-layer")
	if not mainLayer then
		return nil
	end

	return mainLayer
end

local function getPriorityMenu(mainLayer): CCMenu?
	local menu = mainLayer:getChildByID(PRIORITY_MENU_ID)
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

local function getQuickListButtonPosition(viewButton): CCPoint
	local position: CCPoint = viewButton:getPosition()
	local width: number = viewButton:getScaledContentWidth()
	local height: number = viewButton:getScaledContentHeight()

	return {
		x = position.x - width * 0.5,
		y = position.y + height * 0.5 - 2,
	}
end

local function convertPositionBetweenNodes(position, fromNode, toNode): CCPoint
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

local function hideQuickListButtons(mainMenu, priorityMenu)
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

	local mainLayer = getMainLayer(cell)
	if not mainLayer then
		return
	end

	local mainMenu = mainLayer:getChildByID("main-menu")
	if not mainMenu then
		return
	end

	local viewButton = mainMenu:getChildByID("view-button")
	if not viewButton then
		return
	end

	local mainMenuPosition = getQuickListButtonPosition(viewButton)
	local priorityMenu = nil
	local openForCell = function(button: CCMenuItemSpriteExtra?)
		if addLevelOrOpenMenu(cell.m_level, (button :: any) :: CCObject) then
			hideQuickListButtons(mainMenu, priorityMenu)
		end
	end

	upsertQuickListButton(mainMenu, BUTTON_ID, mainMenuPosition, openForCell)

	priorityMenu = getPriorityMenu(mainLayer)
	if not priorityMenu then
		return
	end

	local priorityPosition = convertPositionBetweenNodes(mainMenuPosition, mainMenu, priorityMenu)
	upsertQuickListButton(priorityMenu, PRIORITY_BUTTON_ID, priorityPosition, openForCell)

	setPriorityMenuTouchPriority(priorityMenu)
end

geode.hook("geode.gd.LevelCell:loadFromLevel/1", {
	after = function(cell, level)
		local levelType = level.m_levelType
		if levelType ~= GJ_LEVEL_TYPE.SearchResult and levelType ~= GJ_LEVEL_TYPE.Saved then
			return
		end
		addListButtonToCell(cell, level)
		return
	end,
})

geode.hook("geode.gd.LevelInfoLayer:init/2", {
	before = function(layer, level)
		if level and geode.fields(level).quickListProxyOwner then
			geode.fields(layer).quickListProxy = true
		end
		return
	end,
})

geode.hook("geode.gd.LevelInfoLayer:downloadLevel/0", {
	before = function(layer)
		if geode.fields(layer).quickListProxy then
			return geode.skip()
		end
		return
	end,
})
