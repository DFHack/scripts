
-- From workorder.lua
---------------------------8<-----------------------------

-- local utils = require 'utils'

local world = df.global.world
local uu = dfhack.units

local function isValidAnimal(u)
    -- this should also check for the absence of misc trait 55 (as of 50.09), but we don't
    -- currently have an enum definition for that value yet
    return uu.isOwnCiv(u)
        and uu.isAlive(u)
        and uu.isAdult(u)
        and uu.isActive(u)
        and uu.isFortControlled(u)
        and uu.isTame(u)
        and not uu.isMarkedForSlaughter(u)
        and not uu.getMiscTrait(u, df.misc_trait_type.Migrant, false)
end

-- true/false or nil if no shearable_tissue_layer with length > 0.
local function canShearCreature(u)
    local stls = world.raws.creatures
        .all[u.race]
        .caste[u.caste]
        .shearable_tissue_layer

    local any
    for _, stl in ipairs(stls) do
        if stl.length > 0 then
            for _, bpi in ipairs(stl.bp_modifiers_idx) do
                any = { u.appearance.bp_modifiers[bpi], stl.length }
                if u.appearance.bp_modifiers[bpi] >= stl.length then
                    return true, any
                end
            end
        end
    end

    if any then return false, any end
    -- otherwise: nil
end

---------------------------8<-----------------------------

local function canMilkCreature(u)
    if uu.isMilkable(u) and not uu.isPet(u) then
        local mt_milk = uu.getMiscTrait(u, df.misc_trait_type.MilkCounter, false)
        if not mt_milk then return true else return false end
    else
        return nil
    end
end

function hasJobType(workshop, jobtype)
    for _, job in ipairs(workshop.jobs) do
        if job.job_type == jobtype then return true end
    end
    return false
end


function addWorkshopJob(workshop, job_type, rep, priority)
    local ref = df.general_ref_building_holderst:new()
    ref.building_id = workshop.id

    local job = df.job:new()
    job.job_type = job_type
    job.pos = {
        x = workshop.centerx,
        y = workshop.centery,
        z = workshop.z
    }
    job.flags['repeat'] = rep
    job.flags.do_now = priority
    job.general_refs:insert("#", ref)
    workshop.jobs:insert("#", job)

    dfhack.job.linkIntoWorld(job, true)
    dfhack.job.checkBuildingsNow()
end

-- squared distance is enough for ordering by distance
local function distance2 (x1,y1,x2,y2)
    return (math.abs(x1-x2)^2 + math.abs(y1-y2)^2)
end

-- organize workshops by z-level
local workshops_by_z = {}
for _, workshop in ipairs(df.global.world.buildings.other.WORKSHOP_FARMER) do
    table.insert(ensure_key(workshops_by_z, workshop.z), workshop)
end

for _, unit in ipairs(world.units.active) do
    if not isValidAnimal(unit) then goto skip end

    local shear = canShearCreature(unit)
    local milk  = canMilkCreature(unit)

    if not shear and not milk then goto skip end

    -- print(dfhack.units.getReadableName(unit),'shear:', shear, 'milk:', milk)

    -- locate closest farmers workshop (on same z level)
    local closest = nil
    local distance = nil
    for _, workshop in pairs(workshops_by_z[unit.pos.z] or {}) do
        local d = distance2(unit.pos.x, unit.pos.y, workshop.centerx, workshop.centery)
        if not closest or d < distance then
            closest = workshop
            distance = d
        end
    end

    -- enure that closest workshop has the appropriate jobs
    if closest and #closest.jobs < 5 then
        if milk and not hasJobType(closest, df.job_type.MilkCreature) then
            addWorkshopJob(closest, df.job_type.MilkCreature, false, false)
        end
        if shear and not hasJobType(closest, df.job_type.ShearCreature) then
            addWorkshopJob(closest, df.job_type.ShearCreature, false, false)
        end
    end

    ::skip::
end
