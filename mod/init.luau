local cocos = geode.cocos2d

local getQuickListButtonPosition = require("./getQuickListButtonPosition")

local TopLocalList = require("./TopLocalList")
local PriorityMenu = require("./PriorityMenu")

local BUTTON_ID = "add-to-list-button"
local PRIORITY_BUTTON_ID = "add-to-list-priority-button"
local ADD_TO_LIST_BUTTON_SPRITE = "GJ_listAddBtn_001.png"
local ADD_TO_LIST_BUTTON_SCALE = 0.62

local function setupQuickListButton(button: CCMenuItemSpriteExtra, id, position)
	button:setID(id)
	button:setScale(1)
	button.m_baseScale = 1
	button:setSizeMult(1.35)
	button:setPosition(position)
end

local function upsertQuickListButton(
	menu: CCMenu,
	id,
	position,
	callback: (CCMenuItemSpriteExtra?) -> ()
): CCMenuItemSpriteExtra?
	local existingButton = menu:getChildByID(id) :: CCMenuItemSpriteExtra?
	if existingButton then
		menu:reorderChild(existingButton, 1000)
		setupQuickListButton(existingButton, id, position)
		return existingButton
	end

	local sprite = cocos.CCSprite.createWithSpriteFrameName(ADD_TO_LIST_BUTTON_SPRITE)
	if not sprite then
		return nil
	end
	sprite:setScale(ADD_TO_LIST_BUTTON_SCALE)

	local button: CCMenuItemSpriteExtra? = nil
	button = cocos.CCMenuItemSpriteExtra.create(sprite, function()
		if not button then
			return
		end

		button:stopAllActions()
		button:unselected()
		button:setScale(1)
		button.m_baseScale = 1
		callback(button)
	end)
	if not button then
		return nil
	end

	setupQuickListButton(button, id, position)
	menu:addChild(button, 1000)
	return button
end

local function addListButtonToCell(cell, level)
	if not cell or not level then
		return
	end

	if TopLocalList.containsLevel(level) then
		return
	end

	local mainLayer = cell:getChildByID("main-layer")
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
		if TopLocalList.addLevel(cell.m_level) then
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
	end

	priorityMenu = PriorityMenu.getOrCreate(mainLayer)
	if not priorityMenu then
		return
	end

	local referenceButton = upsertQuickListButton(mainMenu, BUTTON_ID, mainMenuPosition, openForCell) -- first addition - placed for finding relative offset for the new priority menu
	local priorityPosition = priorityMenu:convertToNodeSpace(mainMenu:convertToWorldSpace(mainMenuPosition))
	if referenceButton then
		referenceButton:removeFromParentAndCleanup(true)
	end
	upsertQuickListButton(priorityMenu, PRIORITY_BUTTON_ID, priorityPosition, openForCell) -- second addition - actually visible button

	PriorityMenu.setTouchPriority(priorityMenu)
end

geode.hook("geode.gd.LevelCell:loadFromLevel/1", {
	after = function(cell, level: GJGameLevel)
		if not cell or level.m_levelType ~= geode.gd.GJLevelType.SearchResult then
			return
		end

		task.spawn(function()
			local ok, err = pcall(function()
				addListButtonToCell(cell, level)
			end)
			if not ok then
				print("Quick List: failed to add button: " .. tostring(err))
			end
		end)

		return
	end,
})
