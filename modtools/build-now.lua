-- instantly completes unsuspended building construction jobs
--[====[

build-now
=========

Instantly completes unsuspended building construction jobs. By default, all
buildings on the map are completed, but the area of effect is configurable.

Note that no units will get architecture experience for any buildings that
require that skill to construct.

Usage::

    build-now [<pos> [<pos>]] [<options>]

Where the optional ``<pos>`` pair can be used to specify the coordinate bounds
within which ``build-now`` will operate. If they are not specified,
``build-now`` will scan the entire map. If only one ``<pos>`` is specified, only
the building at that coordinate is built.

The ``<pos>`` parameters can either be an ``<x>,<y>,<z>`` triple (e.g.
``35,12,150``) or the string ``here``, which means the position of the active
game cursor.

Examples:

``build-now``
    Completes all unsuspended construction jobs on the map.

``build-now here``
    Builds the unsuspended, unconstructed building under the cursor.

Options:

:``-h``, ``--help``:
    Show help text.
:``-q``, ``--quiet``:
    Suppress informational output (error messages are still printed).
]====]

local argparse = require('argparse')
local dig_now = require('plugins.dig-now')
local utils = require('utils')

local function min_to_max(...)
    local args = {...}
    table.sort(args, function(a, b) return a < b end)
    return table.unpack(args)
end

local function parse_commandline(args)
    local opts = {}
    local positionals = argparse.processArgsGetopt(args, {
            {'h', 'help', handler=function() opts.help = true end},
            {'q', 'quiet', handler=function() opts.quiet = true end},
        })

    if positionals[1] == 'help' then opts.help = true end
    if opts.help then return opts end

    if #positionals >= 1 then
        opts.start = argparse.coords(positionals[1])
        if #positionals >= 2 then
            opts['end'] = argparse.coords(positionals[2])
            opts.start.x, opts['end'].x = min_to_max(opts.start.x,opts['end'].x)
            opts.start.y, opts['end'].y = min_to_max(opts.start.y,opts['end'].y)
            opts.start.z, opts['end'].z = min_to_max(opts.start.z,opts['end'].z)
        else
            opts['end'] = opts.start
        end
    else
        -- default to covering entire map
        opts.start = xyz2pos(0, 0, 0)
        local x, y, z = dfhack.maps.getTileSize()
        opts['end'] = xyz2pos(x-1, y-1, z-1)
    end
    return opts
end

-- gets list of jobs that meet all of the following criteria:
--   is a building construction job
--   has all job_items attached
--   is not suspended
--   target building is within the processing area
local function get_jobs(opts)
    local num_suspended, num_incomplete, num_clipped, jobs = 0, 0, 0, {}
    for _,job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type ~= df.job_type.ConstructBuilding then goto continue end
        if job.flags.suspend then
            num_suspended = num_suspended + 1
            goto continue
        end

        -- job_items are not items, they're filters that describe the kinds of
        -- items that need to be attached.
        for _,job_item in ipairs(job.job_items) do
            -- we have to check for quantity != 0 instead of just the existence
            -- of the job_item since buildingplan leaves 0-quantity job_items in
            -- place to protect against persistence errors.
            if job_item.quantity > 0 then
                num_incomplete = num_incomplete + 1
                goto continue
            end
        end

        local bld = dfhack.job.getHolder(job)
        if not bld then
            printerr('skipping construction job without attached building')
            goto continue
        end

        -- accept building if if any part is within the processing area
        if bld.z < opts.start.z or bld.z > opts['end'].z
                or bld.x2 < opts.start.x or bld.x1 > opts['end'].z
                or bld.y2 < opts.start.y or bld.y1 > opts['end'].y then
            num_clipped = num_clipped + 1
            goto continue
        end

        table.insert(jobs, job)
        ::continue::
    end
    if not opts.quiet then
        if num_suspended > 0 then
            print(('Skipped %d suspended building%s')
                  :format(num_suspended, num_suspended ~= 1 and 's' or ''))
        end
        if num_incomplete > 0 then
            print(('Skipped %d building%s with missing items')
                  :format(num_incomplete, num_incomplete ~= 1 and 's' or ''))
        end
        if num_clipped > 0 then
            print(('Skipped %d building%s out of processing range')
                  :format(num_clipped, num_clipped ~= 1 and 's' or ''))
        end
    end
    return jobs
end

-- move items away from the construction site
-- moves items to nearest walkable tile that is not occupied by a building
local function clear_footprint(bld)
    return true
end

-- retrieve the items from the job before we destroy the references
local function get_items(job)
    local items = {}
    for _,item_ref in ipairs(job.items) do
        table.insert(items, item_ref.item)
    end
    return items
end

-- disconnect item from the workshop that it is cluttering, if any
local function disconnect_clutter(item)
    local bld = dfhack.items.getHolderBuilding(item)
    if not bld then return true end
    -- remove from contained items list, fail if not found
    local found = false
    for i,contained_item in ipairs(bld.contained_items) do
        if contained_item.item == item then
            bld.contained_items:erase(i)
            found = true
            break
        end
    end
    if not found then
        printerr('failed to find clutter item in expected building')
        return false
    end
    -- remove building ref from item and move item into containing map block
    -- we do this manually instead of calling dfhack.items.moveToGround()
    -- because that function will cowardly refuse to work with items with
    -- BUILDING_HOLDER references (because it could crash the game). However,
    -- we know that this particular setup is safe to work with.
    for i,ref in ipairs(item.general_refs) do
        if ref:getType() == df.general_ref_type.BUILDING_HOLDER then
            item.general_refs:erase(i)
            -- this call can return failure, but it always succeeds in setting
            -- the required item flags and adding the item to the map block,
            -- which is all we care about here. dfhack.items.moveToBuilding()
            -- will fix things up later.
            item:moveToGround(item.pos.x, item.pos.y, item.pos.z)
            return true
        end
    end
    return false
end

-- teleport any items that are not already part of the building to the building
-- center and mark them as part of the building. this handles both partially-
-- built buildings and items that are being carried to the building correctly.
local function attach_items(bld, items)
    for _,item in ipairs(items) do
        -- skip items that have already been brought to the building
        if item.flags.in_building then goto continue end
        -- ensure we have no more holder building references so moveToBuilding
        -- can succeed
        if not disconnect_clutter(item) then return false end
        -- 2 means "make part of bld" (which causes constructions to crash on
        -- deconstruct)
        local use = bld:getType() == df.building_type.Construction and 0 or 2
        if not dfhack.items.moveToBuilding(item, bld, use) then return false end
        ::continue::
    end
    return true
end

-- from observation of vectors sorted by the DF, pos sorting seems to be by x,
-- then by y, then by z
local function pos_cmp(a, b)
    local xcmp = utils.compare(a.x, b.x)
    if xcmp ~= 0 then return xcmp end
    local ycmp = utils.compare(a.y, b.y)
    if ycmp ~= 0 then return ycmp end
    return utils.compare(a.z, b.z)
end

local function create_and_link_construction(pos, item, top_of_wall)
    local construction = df.construction:new()
    utils.assign(construction.pos, pos)
    construction.item_type = item:getType()
    construction.item_subtype = item:getSubtype()
    construction.mat_type = item:getMaterial()
    construction.mat_index = item:getMaterialIndex()
    construction.flags.top_of_wall = top_of_wall
    construction.flags.no_build_item = not top_of_wall
    construction.original_tile = dfhack.maps.getTileType(pos)
    utils.insert_sorted(df.global.world.constructions, construction,
                        'pos', pos_cmp)
end

-- maps construction_type to the resulting tiletype
local const_to_tile = {
    [df.construction_type.Fortification] = df.tiletype.ConstructedFortification,
    [df.construction_type.Wall] = df.tiletype.ConstructedPillar,
    [df.construction_type.Floor] = df.tiletype.ConstructedFloor,
    [df.construction_type.UpStair] = df.tiletype.ConstructedStairU,
    [df.construction_type.DownStair] = df.tiletype.ConstructedStairD,
    [df.construction_type.UpDownStair] = df.tiletype.ConstructedStairUD,
    [df.construction_type.Ramp] = df.tiletype.ConstructedRamp,
}
-- fill in all the track mappings, which have nice consistent naming conventions
for i,v in ipairs(df.construction_type) do
    if type(v) ~= 'string' then goto continue end
    local _, _, base, dir = v:find('^(TrackR?a?m?p?)([NSEW]+)')
    if base == 'Track' then
        const_to_tile[i] = df.tiletype['ConstructedFloorTrack'..dir]
    elseif base == 'TrackRamp' then
        const_to_tile[i] = df.tiletype['ConstructedRampTrack'..dir]
    end
    ::continue::
end

local function set_tiletype(pos, tt)
    local block = dfhack.maps.ensureTileBlock(pos)
    block.tiletype[pos.x%16][pos.y%16] = tt
    if tt == df.tiletype.ConstructedPillar then
        block.designation[pos.x%16][pos.y%16].outside = 0
    end
    -- all tiles below this one are now "inside"
    for z = pos.z-1,0,-1 do
        block = dfhack.maps.ensureTileBlock(pos.x, pos.y, z)
        if not block or block.designation[pos.x%16][pos.y%16].outside == 0 then
            return
        end
        block.designation[pos.x%16][pos.y%16].outside = 0
    end
end

local function adjust_tile_above(pos_above, item, construction_type)
    if not dfhack.maps.ensureTileBlock(pos_above) then return end
    local tt_above = dfhack.maps.getTileType(pos_above)
    local shape_above = df.tiletype.attrs[tt_above].shape
    if shape_above ~= df.tiletype_shape.EMPTY
            and shape_above == df.tiletype_shape.RAMP_TOP then
        return
    end
    if construction_type == df.construction_type.Wall then
        create_and_link_construction(pos_above, item, true)
        set_tiletype(pos_above, df.tiletype.ConstructedFloor)
    elseif df.construction_type[construction_type]:find('Ramp') then
        set_tiletype(pos_above, df.tiletype.RampTop)
    end
end

-- add new construction to the world list and manage tiletype conversion
local function build_construction(bld)
    -- remember required metadata and get rid of building used for designation
    local item = bld.contained_items[0].item
    local pos = copyall(item.pos)
    local construction_type = bld.type
    dfhack.buildings.deconstruct(bld)

    -- add entries to df.global.world.constructions and adjust tiletypes for
    -- the construction itself
    create_and_link_construction(pos, item, false)
    set_tiletype(pos, const_to_tile[construction_type])
    if construction_type == df.construction_type.Wall then
        dig_now.link_adjacent_smooth_walls(pos)
    end

    -- for walls and ramps with empty space above, adjust the tile above
    if construction_type == df.construction_type.Wall
            or df.construction_type[construction_type]:find('Ramp') then
        adjust_tile_above(xyz2pos(pos.x, pos.y, pos.z+1), item,
                          construction_type)
    end

    -- a duplicate item will get created on deconstruction due to the
    -- no_build_item flag set in create_and_link_construction; destroy this item
    dfhack.items.remove(item)
end

-- complete architecture, if required, and mark the building as built
local function build_building(bld)
    if bld:needsDesign() then
        -- unlike "natural" builds, we don't set the architect or builder unit
        -- id. however, this doesn't seem to have any in-game effect.
        local design = bld.design
        design.flags.designed = true
        design.flags.built = true
        design.hitpoints = 80640
        design.max_hitpoints = 80640
    end
    bld:setBuildStage(bld:getMaxBuildStage())
    bld.flags.exists = true
end

local function throw(bld, msg)
    msg = msg .. ('; please remove and recreate the %s at (%d, %d, %d)')
                 :format(df.building_type[bld:getType()],
                         bld.centerx, bld.centery, bld.z)
    qerror(msg)
end

-- main script
local opts = parse_commandline({...})
if opts.help then print(dfhack.script_help()) return end

local num_jobs = 0
for _,job in ipairs(get_jobs(opts)) do
    local bld = dfhack.job.getHolder(job)

    -- clear items from the planned building footprint
    if not clear_footprint(bld) then
        printerr(('cannot move items blocking building at (%d, %d, %d)')
                 :format(bld.centerx, bld.centery, bld.z))
        goto continue
    end

    local items = get_items(job)

    -- remove job data and clean up ref links. we do this first because
    -- dfhack.items.moveToBuilding() refuses to work with items that already
    -- hold references to buildings.
    if not dfhack.job.removeJob(job) then
        throw(bld, 'failed to remove job; job state may be inconsistent')
    end

    if not attach_items(bld, items) then
        throw(bld, 'failed to attach items; building state may be inconsistent')
    end

    if bld:getType() == df.building_type.Construction then
        build_construction(bld)
    else
        build_building(bld)
    end

    num_jobs = num_jobs + 1
    ::continue::
end

df.global.world.reindex_pathfinding = true

if not opts.quiet then
    print(('Completed %d construction job%s')
        :format(num_jobs, num_jobs ~= 1 and 's' or ''))
end
