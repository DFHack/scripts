-- Fixes written materials that are stuck in a non-existent job
--@module = true

local argparse = require('argparse')
local utils = require('utils')

local quire_subtype, scroll_subtype

function is_written_material(item)
    if df.item_bookst:is_instance(item) then
        return true
    end
    if not df.item_toolst:is_instance(item) then
        return false
    end
    local subtype = item:getSubtype()
    return subtype == quire_subtype or subtype == scroll_subtype
end

local function get_ids_of_items_in_jobs()
    local ids = {}
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        for _, item_ref in ipairs(job.items) do
            if item_ref.item then
                ids[item_ref.item.id] = true
            end
        end
    end
    return ids
end

function is_in_live_job(item, ids)
    -- contents of a container are flagged in_job when the container itself
    -- is attached to a job
    while item do
        if ids[item.id] then return true end
        item = dfhack.items.getContainer(item)
    end
    return false
end

local function remove_dead_refs(item)
    for i = #item.specific_refs - 1, 0, -1 do
        local ref = item.specific_refs[i]
        -- the jobs these refs point at may have already been deleted, so the
        -- ref itself must not be dereferenced; just remove it
        if ref.type == df.specific_ref_type.JOB then
            ref:delete()
            item.specific_refs:erase(i)
        end
    end
end

function fixWrittenMaterials(opts)
    quire_subtype = dfhack.items.findSubtype('TOOL:ITEM_TOOL_QUIRE')
    scroll_subtype = dfhack.items.findSubtype('TOOL:ITEM_TOOL_SCROLL')

    local fixed = 0
    local in_job_ids = get_ids_of_items_in_jobs()

    for _, vec in ipairs{df.global.world.items.other.BOOK,
                         df.global.world.items.other.TOOL} do
        for _, item in ipairs(vec) do
            if not is_written_material(item) then goto continue end

            local stuck = false

            -- written materials can keep references to activity events that no
            -- longer exist, e.g. when a visitor that was reading or carrying
            -- them joins the fort (bug 9485)
            for i = #item.general_refs - 1, 0, -1 do
                local ref = item.general_refs[i]
                if ref:getType() == df.general_ref_type.ACTIVITY_EVENT and
                        not df.activity_entry.find(ref.activity_id) then
                    if not opts.dry_run then
                        ref:delete()
                        item.general_refs:erase(i)
                    end
                    stuck = true
                end
            end

            -- they can also be left with the in_job flag set while no actual
            -- job references them
            if item.flags.in_job and not is_in_live_job(item, in_job_ids) then
                if not opts.dry_run then
                    remove_dead_refs(item)
                    item.flags.in_job = false
                end
                stuck = true
            end

            if stuck then
                print(dfhack.df2console(('Found stuck written material: %s'):format(
                    dfhack.items.getDescription(item, 0, true))))
                fixed = fixed + 1
            end

            ::continue::
        end
    end

    if fixed > 0 or opts.dry_run then
        print(("%s %d stuck written material(s)."):format(
                opts.dry_run and "Found" or "Fixed",
                fixed
        ))
    end
end

if dfhack_flags.module then
    return
end

local opts = {}

local positionals = argparse.processArgsGetopt({...}, {
    { 'h', 'help', handler = function() opts.help = true end },
    { 'n', 'dry-run', handler = function() opts.dry_run = true end },
})

if positionals[1] == 'help' or opts.help then
    print(dfhack.script_help())
    return
end

fixWrittenMaterials(opts)
