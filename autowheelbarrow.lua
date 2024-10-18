local repeatutil = require("repeat-util")
local GLOBAL_KEY = "autowheelbarrow"
enabled = enabled or false

-- Main function for managing wheelbarrows
local function unassign_wheelbarrows()
    local wheelbarrow_count = 0
    for _, item in ipairs(df.global.world.items.other.TOOL) do
        if df.item_toolst:is_instance(item) then
            local tool_def = dfhack.items.getSubtypeDef(item:getType(), item:getSubtype())
            if tool_def and tool_def.id == "ITEM_TOOL_WHEELBARROW" then
                wheelbarrow_count = wheelbarrow_count + 1 -- Count each wheelbarrow
                if item.flags.in_job then
                    -- Skip if in use
                elseif item.stockpile then
                    item.stockpile.id = -1 -- Unassign wheelbarrow from stockpile
                end
            end
        end
    end
    return wheelbarrow_count -- Return the total count of wheelbarrows processed
end

local function set_wheelbarrows_for_all_stockpiles()
    for _, building in ipairs(df.global.world.buildings.all) do
        if building:getType() == df.building_type.Stockpile then
            local stockpile_settings = building.settings
            local skip_wheelbarrows = false

            -- Check food settings to skip wheelbarrows
            if stockpile_settings and stockpile_settings.food then
                local food_settings = stockpile_settings.food
                skip_wheelbarrows = #food_settings.meat > 0 or #food_settings.fish > 0 or #food_settings.unprepared_fish > 0 or
                                    #food_settings.egg > 0 or #food_settings.plants > 0 or #food_settings.drink_plant > 0 or
                                    #food_settings.drink_animal > 0 or #food_settings.cheese_animal > 0 or #food_settings.cheese_plant > 0 or
                                    #food_settings.seeds > 0 or #food_settings.leaves > 0 or #food_settings.powder_plant > 0 or
                                    #food_settings.powder_creature > 0 or #food_settings.glob > 0 or #food_settings.glob_paste > 0 or
                                    #food_settings.glob_pressed > 0 or #food_settings.liquid_plant > 0 or #food_settings.liquid_animal > 0 or
                                    #food_settings.liquid_misc > 0
                    --dfhack.println("Skipping stockpile due to food items" .. tostring(building))

            end

            -- Check all the flags and skip if any of them are true (for individual stockpiles)
            if stockpile_settings and stockpile_settings.flags then
                local flags = stockpile_settings.flags
                if flags.animals == true or flags.food == true or flags.furniture == true or
                   flags.corpses == true or flags.refuse == true or flags.ammo == true or flags.coins == true or
                   flags.bars_blocks == true or flags.gems == true or flags.finished_goods == true or
                   flags.leather == true or flags.cloth == true or flags.wood == true or
                   flags.weapons == true or flags.armor == true or flags.sheet == true or
                   flags[17] == true or flags[18] == true or flags[19] == true or flags[20] == true or
                   flags[21] == true or flags[22] == true or flags[23] == true or flags[24] == true or
                   flags[25] == true or flags[26] == true or flags[27] == true or flags[28] == true or
                   flags[29] == true or flags[30] == true or flags[31] == true then
                    skip_wheelbarrows = true
                    --dfhack.println("individual stockpiles Skipping stockpile due to one or more flags being true at " .. tostring(building))
                end
            end

            -- Check if all flags are set to false (for the none stockpile)
            if stockpile_settings and stockpile_settings.flags then
                local flags = stockpile_settings.flags
                if flags.animals == false and flags.food == false and flags.furniture == false and
                   flags.corpses == false and flags.refuse == false and flags.stone == false and flags.ammo == false and
                   flags.coins == false and flags.bars_blocks == false and flags.gems == false and flags.finished_goods == false and
                   flags.leather == false and flags.cloth == false and flags.wood == false and flags.weapons == false and
                   flags.armor == false and flags.sheet == false and
                   flags[17] == false and flags[18] == false and flags[19] == false and flags[20] == false and
                   flags[21] == false and flags[22] == false and flags[23] == false and flags[24] == false and
                   flags[25] == false and flags[26] == false and flags[27] == false and flags[28] == false and
                   flags[29] == false and flags[30] == false and flags[31] == false then
                    skip_wheelbarrows = true
                    --dfhack.println("Skipping NONE stockpile" .. tostring(building))
                end
            end

            if skip_wheelbarrows then
                building.max_wheelbarrows = 0
            else
                local count = unassign_wheelbarrows()
                building.max_wheelbarrows = count
                --dfhack.println("Set wheelbarrow limit for stockpile at " .. tostring(building) .. " to " .. count)
            end
        end
    end
end

local function auto_wheelbarrows()
    for _, unit in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(unit) and unit.job.current_job and unit.job.current_job.job_type == 38 then
            unassign_wheelbarrows()
            set_wheelbarrows_for_all_stockpiles()
            return
        end
    end
end

-- Event loop function to call periodically
local function event_loop()
    if enabled then
        dfhack.println("Running autowheelbarrow.lua ")
        auto_wheelbarrows()
        -- Check again in 1 days
        repeatutil.scheduleUnlessAlreadyScheduled(GLOBAL_KEY, 1, "days", event_loop)
    end
end

-- Manage on state change
dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_MAP_LOADED and df.global.gamemode == df.game_mode.DWARF then
        event_loop() -- Start the event loop when the game map is loaded
    elseif sc == SC_MAP_UNLOADED then
        repeatutil.cancel(GLOBAL_KEY) -- Stop the event loop when the map is unloaded
    end
end

-- Enable the script and start the event loop
enabled = true
event_loop()
