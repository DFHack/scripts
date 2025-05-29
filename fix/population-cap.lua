local plotinfo = df.global.plotinfo
local tasks = plotinfo.tasks
local knowledge = tasks.knowledge

local civ = df.historical_entity.find(plotinfo.civ_id)

if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() or not civ then
    qerror('No active fortress.')
end

local civ_stats = civ.activity_stats

local function upsize(civ_vec, tasks_vec)
    local tasks_vec_size = #tasks_vec
    if #civ_vec < tasks_vec_size then
        civ_vec:resize(tasks_vec_size)
    end
end

upsize(civ_stats.created_weapons, tasks.created_weapons)
upsize(civ_stats.knowledge.discovered_creature_foods, knowledge.discovered_creature_foods)
upsize(civ_stats.knowledge.discovered_creatures, knowledge.discovered_creatures)
upsize(civ_stats.knowledge.discovered_plant_foods, knowledge.discovered_plant_foods)
upsize(civ_stats.knowledge.discovered_plants, knowledge.discovered_plants)

-- Use max to keep at least some of the original caravan communication idea
local new_pop = math.max(civ_stats.population, tasks.population)

if civ_stats.population ~= new_pop then
    civ_stats.population = new_pop
    print('Home civ notified about current population.')
end
