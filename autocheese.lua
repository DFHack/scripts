--@module = true

---make cheese using a specific barrel and workshop
---@param barrel df.item
---@param workshop df.building_workshopst
---@return df.job
function makeCheese(barrel, workshop)
    ---@type df.job
    local job = dfhack.job.createLinked()
    job.job_type = df.job_type.MakeCheese

    local jitem = df.job_item:new()
    jitem.quantity = 0
    jitem.vector_id = df.job_item_vector_id.ANY_COOKABLE
    jitem.flags1.unrotten = true
    jitem.flags1.milk = true
    job.job_items.elements:insert('#', jitem)

    if not dfhack.job.attachJobItem(job, barrel, df.job_role_type.Reagent, 0, -1) then
        dfhack.error('could not attach item')
    end

    dfhack.job.assignToWorkshop(job, workshop)
    return job
end

---checks that unit can path to workshop
---@param unit df.unit
---@param workshop df.building_workshopst
---@return boolean
function canAccessWorkshop(unit, workshop)
    local workshop_position = xyz2pos(workshop.centerx, workshop.centery, workshop.z)
    return dfhack.maps.canWalkBetween(unit.pos, workshop_position)
end

---check if unit can perform labor at workshop
---@param unit df.unit
---@param unit_labor df.unit_labor
---@param workshop df.building
---@return boolean
function availableLaborer(unit, unit_labor, workshop)
    return unit.status.labors[unit_labor]
       and dfhack.units.isJobAvailable(unit)
       and canAccessWorkshop(unit, workshop)
end

---find unit with a particular labor enabled
---@param unit_labor df.unit_labor
---@param job_skill df.job_skill
---@param workshop df.building
---@return df.unit|nil
---@return integer|nil
 function findAvailableLaborer(unit_labor, job_skill, workshop)
    local max_unit = nil
    local max_skill = -1
    for _, unit in ipairs(dfhack.units.getCitizens(true, false)) do
        if
            availableLaborer(unit, unit_labor, workshop)
        then
            local unit_skill = dfhack.units.getNominalSkill(unit, job_skill, true)
            if unit_skill > max_skill then
                max_unit = unit
                max_skill = unit_skill
            end
        end
    end
    return max_unit, max_skill
end

local function findMilkBarrel(min_liquids)
    for _, container in ipairs(df.global.world.items.other.FOOD_STORAGE) do
        if
            not (container.flags.in_job or container.flags.forbid) and
            container.flags.container and #container.general_refs >= min_liquids
        then
            local content_reference = dfhack.items.getGeneralRef(container, df.general_ref_type.CONTAINS_ITEM)
            local contained_item = df.item.find(content_reference and content_reference.item_id or -1)
            if contained_item then
                local mat_info = dfhack.matinfo.decode(contained_item)
                if mat_info:matches { milk = true } then
                    return container
                end
            end
        end
    end
end

---find a workshop to which the barrel can be brought
---if the workshop has a master, only return workshop and master if the master is available
---@param pos df.coord
---@return df.building_workshopst?
---@return df.unit?
function findWorkshop(pos)
    for _,workshop in ipairs(df.global.world.buildings.other.WORKSHOP_FARMER) do
        if
            dfhack.maps.canWalkBetween(pos, xyz2pos(workshop.centerx, workshop.centery, workshop.z)) and
            not workshop.profile.blocked_labors[df.unit_labor.MAKE_CHEESE] and
            #workshop.jobs == 0
        then
            if #workshop.profile.permitted_workers == 0 then
                -- immediately return workshop without master
                return workshop, nil
            else
                unit = df.unit.find(workshop.profile.permitted_workers[0])
                if
                    unit and availableLaborer(unit, df.unit_labor.MAKE_CHEESE, workshop)
                then
                    -- return workshop and master, if master is available
                    return workshop, unit
                else
                    print("autocheese: Skipping farmer's workshop with unavailable master")
                end
            end
        end
    end
end

if dfhack_flags.module then
    return
end

-- actual script action

local argparse = require('argparse')

local min_number = 50

local _ = argparse.processArgsGetopt({...},
{
    { 'm', 'min-milk', hasArg = true,
    handler = function(min)
        min_number = argparse.nonnegativeInt(min, 'min-milk')
    end }
})


local reagent = findMilkBarrel(min_number)

if not reagent then
    -- print('autocheese: no sufficiently full barrel found')
    return
end

local workshop, worker = findWorkshop(xyz2pos(dfhack.items.getPosition(reagent)))

if not workshop then
    print("autocheese: no Farmer's Workshop available")
    return
end

-- try to find laborer for workshop without master
if not worker then
    worker, _ = findAvailableLaborer(df.unit_labor.MAKE_CHEESE, df.job_skill.CHEESEMAKING, workshop)
end

if not worker then
    print('autocheese: no cheesemaker available')
    return
end
local job = makeCheese(reagent, workshop)

print(('autocheese: dispatching cheesemaking job for %s (%d milk) to %s'):format(
    dfhack.df2console(dfhack.items.getReadableDescription(reagent)),
    #reagent.general_refs,
    dfhack.df2console(dfhack.units.getReadableName(worker))
))


-- assign a worker and send it to fetch the barrel
dfhack.job.addWorker(job, worker)
dfhack.units.setPathGoal(worker, reagent.pos, df.unit_path_goal.GrabJobResources)
job.items[0].flags.is_fetching = true
job.flags.fetching = true
