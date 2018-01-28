--Fixes all local bugged sleepers in adventure mode.
--[====[

adv_fix_sleepers
================
Fixes all local bugged sleepers (units who never wake up) in adventure mode.

]====]

--========================
-- Author: ArrowThunder on bay12 & reddit
-- Version: 1.0
-- Bug fixed: http://www.bay12games.com/dwarves/mantisbt/view.php?id=6798
--		This bug is characterized by sleeping units who refuse to awaken in 
--		adventure mode regardless of talking to them, hitting them, or waiting
--		so long you die of thirst. 
-- 
-- Usage: If you come accross one or more bugged sleepers in adventure mode, 
-- 		simply run the script (type adv_fix_sleepers into the dfhack console),
--		and all nearby sleepers will be cured.
--
----=======================

-- gets the army controller based on the army controller id
local function get_army_controller(id)
	if id == nil then
		-- print ("nil id passed")
		return nil
	end
	local all_army_controllers = df.global.world.army_controllers.all
	for k, army_controller in pairs(all_army_controllers) do
		if not army_controller then
			-- print ("nil army_controller found")
		elseif army_controller.id == id then
			return army_controller
		end
	end
	return nil
end

-- get the list of all the active units currently loaded
local active_units = df.global.world.units.active -- get all active units

-- check every active unit for the bug
local num_fixed = 0 -- this is the number of army controllers fixed, not units
	-- I've found that often, multiple sleepers share a bugged army controller
for k, unit in pairs(active_units) do
	if unit ~= nil then
		local army_controller
		army_controller = get_army_controller(unit.enemy.army_controller_id)
		if not army_controller then
			-- print ("no army_controller found matching given id")
		elseif army_controller.type == 4 then -- sleeping code is possible
			if army_controller.unk_64.t4.unk_2.not_sleeping == false then
				army_controller.unk_64.t4.unk_2.not_sleeping = true -- fix bug
				num_fixed = num_fixed + 1;
			end
		end
	end
end

if num_fixed == 0 then
	print ("No sleepers with the fixable bug were found, sorry.")
else
	print ("Fixed " .. num_fixed .. " bugged army_controllers.")
end
