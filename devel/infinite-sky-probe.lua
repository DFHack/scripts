-- Facilitates in-game reproduction of DFHack issue #254: z-levels added by
-- infinite-sky spontaneously reverting and causing cave-ins.
--[====[

devel/infinite-sky-probe
========================

Tool for attempting in-game reproduction of `issue #254
<https://github.com/DFHack/dfhack/issues/254>`_: sky z-levels created by
``infinite-sky`` periodically disappearing again down to the level of the
highest construction, causing cave-ins.

.. warning::

    This tool fabricates completed constructions and forces cave-column
    recomputation. It can cave-in or otherwise corrupt your fort. Only use it
    on a disposable save.

Usage:

``status``
    Print the current map z-level state: ``z_count``/``z_count_block``,
    the highest construction z-level, whether the top-level map blocks are
    allocated, and the state of the cave-column bookkeeping flags that are
    suspected to be involved in the issue.

``add <n>``
    Add *n* sky z-levels via the real ``infinite-sky`` plugin command.

``tower [--pos x,y,z] [--top z] [--platform]``
    Fabricate a completed construction tower: a column of pillar walls, the
    implied "top of wall" floor on top, and the matching ``df.construction``
    records (this is the same end state the game produces when a dwarf
    finishes a construction job). If ``--pos`` is not given, the keyboard
    cursor position is used; if it has no z component, building starts at
    the ground surface found at that x,y. The tower is built up to
    ``--top`` (default: one z-level below the current map ceiling, leaving
    one empty sky level like the game normally expects). ``--platform``
    additionally lays constructed floors adjacent to the top of the tower,
    mimicking the "constructions in progress near the top" scenario from
    the issue report.

``poke``
    Force the suspected trigger: set the world ``process_columns`` flag and
    mark every map block column ``UPDATE_CAVE_COLUMNS``, which is what the
    game sets when construction changes require cave-column recomputation.

``watch [frames]``
    Monitor ``z_count``/``z_count_block``, the construction list, the
    cave-column flags, and ``CAVE_COLLAPSE`` reports once per frame for the
    given number of frames (default 20000; at ~100 FPS that is a few
    minutes). The game is unpaused while watching and the pause state is
    restored afterwards. Any *decrease* in z-levels is reported loudly:
    that means issue #254 has been reproduced.

``run [frames] [--levels n] [--enable]``
    Run the full reproduction sequence: ``status``, optionally ``add n``
    sky levels, optionally ``enable infinite-sky`` (reproduces the
    "construction monitoring" variant of the report), ``tower
    --platform``, ``poke``, ``watch``.

``stop``
    Stop a running ``watch`` early.

]====]

local argparse = require('argparse')
local utils = require('utils')

local function get_world()
    if not dfhack.isMapLoaded() then
        qerror('requires a loaded fortress map')
    end
    return df.global.world
end

-- ---------------------------------------------------------------------------
-- status
-- ---------------------------------------------------------------------------

local function count_pending_columns()
    local n = 0
    for _, col in ipairs(df.global.world.map.map_block_columns) do
        if col.flags[df.map_block_column_flags.UPDATE_CAVE_COLUMNS] then
            n = n + 1
        end
    end
    return n
end

local function count_collapse_reports()
    local n = 0
    for _, r in ipairs(df.global.world.status.reports) do
        if r.type == df.announcement_type.CAVE_COLLAPSE then
            n = n + 1
        end
    end
    return n
end

local function highest_construction_z()
    local hi = nil
    for _, c in ipairs(df.global.world.event.constructions) do
        if not hi or c.pos.z > hi then
            hi = c.pos.z
        end
    end
    return hi
end

local function count_allocated_blocks_at_level(z)
    local map = df.global.world.map
    local allocated, total = 0, 0
    for bx = 0, map.x_count_block - 1 do
        for by = 0, map.y_count_block - 1 do
            total = total + 1
            if dfhack.maps.getTileBlock(bx * 16, by * 16, z) then
                allocated = allocated + 1
            end
        end
    end
    return allocated, total
end

local function do_add(n)
    get_world()
    dfhack.run_command(('infinite-sky %d'):format(n))
end

local function do_status()
    local world = get_world()
    local map = world.map
    print(('z_count_block=%d z_count=%d (map %dx%d blocks)')
        :format(map.z_count_block, map.z_count,
                map.x_count_block, map.y_count_block))
    local hi = highest_construction_z()
    print(('constructions: %d; highest at z=%s')
        :format(#world.event.constructions,
                hi and tostring(hi) or 'none'))
    local alloc, total = count_allocated_blocks_at_level(map.z_count_block - 1)
    print(('top level allocated blocks: %d/%d'):format(alloc, total))
    print(('world process_columns flag: %s')
        :format(tostring(world.flags[df.world_flags.process_columns])))
    print(('columns flagged UPDATE_CAVE_COLUMNS: %d')
        :format(count_pending_columns()))
    print(('CAVE_COLLAPSE reports on record: %d')
        :format(count_collapse_reports()))
end

-- ---------------------------------------------------------------------------
-- construction fabrication
-- ---------------------------------------------------------------------------

-- the constructions vector is sorted by pos, in (x, y, z) order
local function coord_cmp(a, b)
    if a.x ~= b.x then return a.x - b.x end
    if a.y ~= b.y then return a.y - b.y end
    return a.z - b.z
end

local function get_construction_material()
    -- clone material fields from an existing construction, if there is one
    for _, c in ipairs(df.global.world.event.constructions) do
        if not c.flags.top_of_wall then
            return c.item_type, c.item_subtype, c.mat_type, c.mat_index
        end
    end
    -- otherwise use the first stone available on this embark
    local mats = df.global.plotinfo.stone_mat_types
    if #mats > 0 then
        return df.item_type.BLOCKS, -1, mats[0],
               df.global.plotinfo.stone_mat_indexes[0]
    end
    return df.item_type.BLOCKS, -1, df.builtin_mats.INORGANIC, 0
end

-- Turn the tile at pos into the given constructed tiletype and register a
-- matching df.construction record, as if a construction job had completed.
local function fabricate_construction(pos, tt, top_of_wall)
    local block = dfhack.maps.getTileBlock(pos)
    if not block then
        return false, 'no map block'
    end
    if dfhack.constructions.findAtTile(pos) then
        return false, 'construction already present'
    end
    local lx, ly = pos.x % 16, pos.y % 16
    local old_tt = block.tiletype[lx][ly]
    local bs = df.tiletype_shape.attrs[
        df.tiletype.attrs[old_tt].shape].basic_shape
    if bs ~= df.tiletype_shape_basic.Open
            and bs ~= df.tiletype_shape_basic.Floor
            and bs ~= df.tiletype_shape_basic.Ramp then
        return false, ('tile not buildable (basic_shape=%s)')
            :format(df.tiletype_shape_basic[bs] or tostring(bs))
    end
    local it, ist, mt, mi = get_construction_material()
    block.tiletype[lx][ly] = tt
    block.designation[lx][ly].dig = df.tile_dig_designation.No
    local added, c = utils.insert_sorted(
        df.global.world.event.constructions,
        {new = true,
         pos = pos,
         item_type = it,
         item_subtype = ist,
         mat_type = mt,
         mat_index = mi,
         sec_i_sc1 = -1,
         sec_i_sc2 = -1,
         original_tile = old_tt},
        'pos', coord_cmp)
    if not added then
        return false, 'construction record already exists'
    end
    if top_of_wall then
        c.flags.top_of_wall = true
        c.flags.no_build_item = true
    end
    -- mark the z-level dirty so the game reprocesses it (best effort: the
    -- Lua binding's recorded size for this raw array can be stale after
    -- infinite-sky reallocates it in C++)
    local zf = df.global.world.map_extras.z_level_flags
    if zf then
        pcall(function()
            zf[pos.z].update = true
            zf[pos.z].update_twice = true
        end)
    end
    return true
end

-- find the z-level of the ground surface at x,y (topmost non-air tile)
local function find_surface_z(x, y)
    for z = df.global.world.map.z_count_block - 1, 0, -1 do
        local tt = dfhack.maps.getTileType(x, y, z)
        if tt and df.tiletype.attrs[tt].material ~= df.tiletype_material.AIR then
            return z, tt
        end
    end
    return nil
end

local function do_tower(opts)
    local world = get_world()
    local x, y, z = opts.x, opts.y, opts.z
    if not x or not y then
        local c = df.global.cursor
        if c.x ~= -30000 then
            x, y = c.x, c.y
            if not z and c.z ~= -30000 then z = c.z end
        end
    end
    if not x or not y then
        -- fall back to the first citizen's position
        local unit = df.global.world.units.active[0]
        if not unit then qerror('no position given, no cursor, no units') end
        x, y = unit.pos.x, unit.pos.y
    end
    if not z then
        local surf_z, tt = find_surface_z(x, y)
        if not surf_z then
            qerror(('no surface tile found at (%d, %d)'):format(x, y))
        end
        local bs = df.tiletype_shape.attrs[
            df.tiletype.attrs[tt].shape].basic_shape
        -- walls can't be built on solid tiles; start one level above them
        z = (bs == df.tiletype_shape_basic.Wall
             or bs == df.tiletype_shape_basic.Stair) and surf_z + 1 or surf_z
    end
    local top = opts.top or (world.map.z_count_block - 2)
    if top >= world.map.z_count_block then
        top = world.map.z_count_block - 1
    end
    if z > top then
        qerror(('start z=%d is above top z=%d'):format(z, top))
    end
    print(('fabricating pillar tower at (%d, %d) from z=%d to z=%d')
        :format(x, y, z, top))
    local built, existed = 0, 0
    local last_z = z - 1
    for tz = z, top do
        local ok, err = fabricate_construction(
            xyz2pos(x, y, tz), df.tiletype.ConstructedPillar)
        if not ok then
            if err:match('already') then
                -- left over from a previous run; counts toward the tower
                existed = existed + 1
                last_z = tz
            else
                print(('  stopped at z=%d: %s'):format(tz, err))
                break
            end
        else
            built = built + 1
            last_z = tz
        end
    end
    if existed > 0 then
        print(('  reused %d existing construction(s)'):format(existed))
    end
    if built == 0 and existed == 0 then
        qerror('could not build any part of the tower')
    end
    -- the implied floor on top of the last wall (ITEMLESS_CEILING record)
    local ok, err = fabricate_construction(
        xyz2pos(x, y, last_z + 1), df.tiletype.ConstructedFloor, true)
    if ok then
        built = built + 1
    else
        print(('  could not add top floor: %s'):format(err))
    end
    -- optionally lay a small platform adjacent to the top floor, like the
    -- "constructions going on" tiles in the issue report
    if opts.platform then
        local fz = last_z + 1
        for _, d in ipairs{{1, 0}, {-1, 0}, {0, 1}, {0, -1},
                           {1, 1}, {1, -1}, {-1, 1}, {-1, -1}} do
            local px, py = x + d[1], y + d[2]
            if px >= 0 and px < world.map.x_count
                    and py >= 0 and py < world.map.y_count then
                local ok2 = fabricate_construction(
                    xyz2pos(px, py, fz), df.tiletype.ConstructedFloor)
                if ok2 then built = built + 1 end
            end
        end
    end
    world.reindex_pathfinding = true
    print(('built %d construction%s; highest construction now at z=%s')
        :format(built, built == 1 and '' or 's',
                tostring(highest_construction_z())))
end

-- ---------------------------------------------------------------------------
-- poke: force cave-column recomputation
-- ---------------------------------------------------------------------------

local function do_poke()
    local world = get_world()
    world.flags[df.world_flags.process_columns] = true
    local n = 0
    for _, col in ipairs(world.map.map_block_columns) do
        if not col.flags[df.map_block_column_flags.UPDATE_CAVE_COLUMNS] then
            col.flags[df.map_block_column_flags.UPDATE_CAVE_COLUMNS] = true
            n = n + 1
        end
    end
    print(('set world process_columns; marked %d column%s UPDATE_CAVE_COLUMNS')
        :format(n, n == 1 and '' or 's'))
end

-- ---------------------------------------------------------------------------
-- watch: monitor for the z-level reset described in issue #254
-- ---------------------------------------------------------------------------

watching = watching or false
watch_state = watch_state or nil
watch_frames_left = watch_frames_left or 0
watch_saved_pause = watch_saved_pause or nil

local function stop_watch(msg)
    watching = false
    if watch_saved_pause ~= nil then
        df.global.pause_state = watch_saved_pause
        watch_saved_pause = nil
    end
    if msg then print(msg) end
end

local function watch_log(msg)
    print(('[tick %d] %s'):format(df.global.world.frame_counter, msg))
end

local function watch_step()
    if not watching then return end
    if not df.global.world or not dfhack.isMapLoaded() then
        stop_watch('map unloaded; watch aborted')
        return
    end
    local world = df.global.world
    local map = world.map
    local s = watch_state

    if map.z_count_block ~= s.zb or map.z_count ~= s.z then
        if map.z_count_block < s.zb or map.z_count < s.z then
            s.reset_observed = true
            dfhack.color(COLOR_LIGHTRED)
            watch_log(('*** z-levels DECREASED: z_count_block %d -> %d, ' ..
                       'z_count %d -> %d -- issue #254 reproduced! ***')
                :format(s.zb, map.z_count_block, s.z, map.z_count))
            dfhack.color(COLOR_RESET)
        else
            watch_log(('z-levels increased: z_count_block %d -> %d, ' ..
                       'z_count %d -> %d')
                :format(s.zb, map.z_count_block, s.z, map.z_count))
        end
        s.zb, s.z = map.z_count_block, map.z_count
    end

    local con = #world.event.constructions
    if con < s.con then
        watch_log(('construction count dropped %d -> %d (possible cave-in)')
            :format(s.con, con))
    elseif con > s.con then
        watch_log(('construction count rose %d -> %d'):format(s.con, con))
    end
    s.con = con

    local proc = world.flags[df.world_flags.process_columns]
    if proc ~= s.proc then
        watch_log(('world process_columns flag -> %s'):format(tostring(proc)))
        s.proc = proc
    end

    local nid = world.status.next_report_id
    if nid ~= s.next_report then
        for _, r in ipairs(world.status.reports) do
            if r.id >= s.next_report and r.id < nid
                    and r.type == df.announcement_type.CAVE_COLLAPSE then
                dfhack.color(COLOR_YELLOW)
                watch_log(('CAVE_COLLAPSE report %d at (%d, %d, %d): %s')
                    :format(r.id, r.pos.x, r.pos.y, r.pos.z, r.text))
                dfhack.color(COLOR_RESET)
            end
        end
        s.next_report = nid
    end

    s.frames = s.frames + 1
    if s.frames % 100 == 0 then
        local n = count_pending_columns()
        if n ~= s.cols then
            watch_log(('columns pending UPDATE_CAVE_COLUMNS: %d -> %d')
                :format(s.cols, n))
            s.cols = n
        end
    end

    watch_frames_left = watch_frames_left - 1
    if watch_frames_left <= 0 then
        if s.reset_observed then
            stop_watch(('watch ended: RESET WAS OBSERVED - issue #254 ' ..
                        'reproduced (z_count_block now %d)')
                :format(map.z_count_block))
        else
            stop_watch(('watch ended: z_count_block=%d z_count=%d, no reset ' ..
                        'observed in the watch window')
                :format(map.z_count_block, map.z_count))
        end
        return
    end
    dfhack.timeout(1, 'frames', watch_step)
end

local function do_watch(frames)
    local world = get_world()
    if watching then
        qerror('already watching; run "devel/infinite-sky-probe stop" first')
    end
    watch_state = {
        zb = world.map.z_count_block,
        z = world.map.z_count,
        con = #world.event.constructions,
        proc = world.flags[df.world_flags.process_columns],
        next_report = world.status.next_report_id,
        cols = count_pending_columns(),
        frames = 0,
    }
    watch_frames_left = frames or 20000
    watch_saved_pause = df.global.pause_state
    watching = true
    if watch_saved_pause then
        df.global.pause_state = false
        print('unpaused game while watching (pause state will be restored)')
    end
    print(('watching z-levels for %d frames; current z_count_block=%d ' ..
           'z_count=%d; run "devel/infinite-sky-probe stop" to abort')
        :format(watch_frames_left, watch_state.zb, watch_state.z))
    dfhack.timeout(1, 'frames', watch_step)
end

-- ---------------------------------------------------------------------------
-- command dispatch
-- ---------------------------------------------------------------------------

local function main(args)
    local opts = {}
    local positionals = argparse.processArgsGetopt(args, {
            {'h', 'help', handler = function() opts.help = true end},
            {'p', 'pos', hasArg = true,
             handler = function(a) opts.pos = argparse.coords(a, 'pos') end},
            {'t', 'top', hasArg = true,
             handler = function(a) opts.top = argparse.positiveInt(a, 'top') end},
            {'', 'platform', handler = function() opts.platform = true end},
            {'e', 'enable', handler = function() opts.enable = true end},
            {'l', 'levels', hasArg = true,
             handler = function(a) opts.levels = argparse.positiveInt(a, 'levels') end},
        })

    local cmd = positionals[1]
    if not cmd or cmd == 'help' or opts.help then
        print(dfhack.script_help())
        return
    end

    if cmd == 'status' then
        do_status()
    elseif cmd == 'add' then
        local n = argparse.positiveInt(positionals[2] or '', 'count')
        do_add(n)
    elseif cmd == 'tower' then
        do_tower{
            x = opts.pos and opts.pos.x,
            y = opts.pos and opts.pos.y,
            z = opts.pos and opts.pos.z,
            top = opts.top,
            platform = opts.platform,
        }
    elseif cmd == 'poke' then
        do_poke()
    elseif cmd == 'watch' then
        do_watch(positionals[2] and tonumber(positionals[2]))
    elseif cmd == 'run' then
        if opts.enable then
            dfhack.run_command('enable infinite-sky')
        end
        do_status()
        if opts.levels then
            do_add(opts.levels)
        end
        do_tower{
            x = opts.pos and opts.pos.x,
            y = opts.pos and opts.pos.y,
            z = opts.pos and opts.pos.z,
            top = opts.top,
            platform = true,
        }
        do_poke()
        do_watch(positionals[2] and tonumber(positionals[2]))
    elseif cmd == 'stop' then
        if watching then
            stop_watch('watch stopped')
        else
            print('not currently watching')
        end
    else
        qerror('unknown command: ' .. tostring(cmd))
    end
end

if not dfhack_flags.module then
    main({...})
end
