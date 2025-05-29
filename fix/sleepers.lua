-- Number of fixed army controller(s) that may be shared by multiple units
local num_fixed = 0

-- Loop through all the active units currently loaded
for _, unit in ipairs(df.global.world.units.active) do
    local army_controller = unit.enemy.army_controller
    -- Only Campers have been observed to sleep
    if army_controller and army_controller.goal == df.army_controller_goal_type.CAMP then
        if not army_controller.data.goal_camp.camp_flag.ALARM_INTRUDER then
            -- Intruder alert! Bloodthirsty adventurer is in the camp!
            army_controller.data.goal_camp.camp_flag.ALARM_INTRUDER = true
            num_fixed = num_fixed + 1
        end
    end
end

if num_fixed == 0 then
    print ("No sleepers with the fixable bug were found, sorry.")
else
    print ("Fixed " .. num_fixed .. " group(s) of sleeping units.")
end
