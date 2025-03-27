-- Import repeat-util for automation
local repeatUtil = require('repeat-util')

-- Define a function to count site types, print totals, and update sitecap
local function count_and_update_sitecap()
    -- Initialize counters for site types
    local player_fortress_count = 0
    local dark_fortress_count = 0
    local mountain_halls_count = 0
    local forest_retreat_count = 0
    local town_count = 0
    local fortress_count = 0

    -- Loop through all sites in the world
    for _, site in ipairs(df.global.world.world_data.sites) do
        local site_type = site.type

        -- Increment counters based on site type
        if site_type == df.world_site_type.PlayerFortress then
            player_fortress_count = player_fortress_count + 1
        elseif site_type == df.world_site_type.DarkFortress then
            dark_fortress_count = dark_fortress_count + 1
        elseif site_type == df.world_site_type.MountainHalls then
            mountain_halls_count = mountain_halls_count + 1
        elseif site_type == df.world_site_type.ForestRetreat then
            forest_retreat_count = forest_retreat_count + 1
        elseif site_type == df.world_site_type.Town then
            town_count = town_count + 1
        elseif site_type == df.world_site_type.Fortress then
            fortress_count = fortress_count + 1
        end
    end

    -- Calculate the total number of sites
    local total_sites = player_fortress_count + dark_fortress_count + mountain_halls_count +
                        forest_retreat_count + town_count + fortress_count

    -- Print the results
    dfhack.println("Site Type Counts:")
    dfhack.println(" - Player Fortresses: " .. player_fortress_count)
    dfhack.println(" - Dark Fortresses: " .. dark_fortress_count)
    dfhack.println(" - Mountain Halls: " .. mountain_halls_count)
    dfhack.println(" - Forest Retreats: " .. forest_retreat_count)
    dfhack.println(" - Towns: " .. town_count)
    dfhack.println(" - Fortresses: " .. fortress_count)
    dfhack.println("Total number of sites: " .. total_sites)

    -- Reveal current sitecap
    local current_sitecap = df.global.world.worldgen.worldgen_parms.site_cap
    dfhack.println("Current sitecap: " .. current_sitecap)

    -- Update the sitecap by 5
    df.global.world.worldgen.worldgen_parms.site_cap = current_sitecap + 5
    dfhack.println("New sitecap set to: " .. (current_sitecap + 5))
end

-- Schedule the script to run every 100,800 ticks
repeatUtil.scheduleEvery("repeat_sitecap_adjust", 100800, "ticks", count_and_update_sitecap)

-- Initial run
count_and_update_sitecap()
