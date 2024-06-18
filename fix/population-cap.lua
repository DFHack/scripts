local ui = df.global.plotinfo
local ui_stats = ui.tasks
local civ = df.historical_entity.find(ui.civ_id)

if not civ then
    qerror('No active fortress.')
end

local civ_stats = civ.activity_stats

if not civ_stats then
    civ.activity_stats = {
        new = true,
        created_weapons = { resize = #ui_stats.created_weapons },
        discovered_creature_foods = { resize = #ui_stats.discovered_creature_foods },
        discovered_creatures = { resize = #ui_stats.discovered_creatures },
        discovered_plant_foods = { resize = #ui_stats.discovered_plant_foods },
        discovered_plants = { resize = #ui_stats.discovered_plants },
    }
    civ_stats = civ.activity_stats
end

-- Use max to keep at least some of the original caravan communication idea
local new_pop = math.max(civ_stats.population, ui_stats.population)

if civ_stats.population ~= new_pop then
    civ_stats.population = new_pop
    print('Home civ notified about current population.')
end
