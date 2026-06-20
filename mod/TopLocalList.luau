-- Utilities for the first created local list

local gd = geode.gd

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

return table.freeze({
	addLevel = addLevelToTopLocalList,
	containsLevel = topLocalListContainsLevel,
})
