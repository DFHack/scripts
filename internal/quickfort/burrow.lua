-- burrow-related data and logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local civalert = reqscript('gui/civ-alert')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_map = reqscript('internal/quickfort/map')
local quickfort_parse = reqscript('internal/quickfort/parse')
local quickfort_preview = reqscript('internal/quickfort/preview')
local utils = require('utils')

local log = quickfort_common.log

local burrow_db = {
    a={label='Add', add=true},
    e={label='Erase', add=false},
}

local function custom_burrow(_, keys)
    local token_and_label, props_start_pos = quickfort_parse.parse_token_and_label(keys, 1, '%w')
    if not token_and_label or not rawget(burrow_db, token_and_label.token) then return nil end
    local db_entry = copyall(burrow_db[token_and_label.token])
    local props = quickfort_parse.parse_properties(keys, props_start_pos)
    if props.name then
        db_entry.name = props.name
        props.name = nil
    end
    if db_entry.add and props.create == 'true' then
        db_entry.create = true
        props.create = nil
    end
    if db_entry.add and props.civalert == 'true' then
        db_entry.civalert = true
        props.civalert = nil
    end
    if db_entry.add and props.autochop_clear == 'true' then
        db_entry.autochop_clear = true
        props.autochop_clear = nil
    end
    if db_entry.add and props.autochop_chop == 'true' then
        db_entry.autochop_chop = true
        props.autochop_chop = nil
    end

    for k,v in pairs(props) do
        dfhack.printerr(('unhandled property for symbol "%s": "%s"="%s"'):format(
            token_and_label.token, k, v))
    end

    return db_entry
end

setmetatable(burrow_db, {__index=custom_burrow})

local burrows = df.global.plotinfo.burrows

local function create_burrow(name)
    local b = df.burrow:new()
    b.id = burrows.next_id
    burrows.next_id = burrows.next_id + 1
    if name then
        b.name = name
    end
    b.symbol_index = math.random(0, 22)
    b.texture_r = math.random(0, 255)
    b.texture_g = math.random(0, 255)
    b.texture_b = math.random(0, 255)
    b.texture_br = 255 - b.texture_r
    b.texture_bg = 255 - b.texture_g
    b.texture_bb = 255 - b.texture_b
    burrows.list:insert('#', b)
    return b
end

local function do_burrow(ctx, db_entry, pos)
    local stats = ctx.stats
    local b
    if db_entry.name then
        b = dfhack.burrows.findByName(db_entry.name, true)
    end
    if not b and db_entry.add then
        if db_entry.create then
            b = create_burrow(db_entry.name)
            stats.burrow_created.value = stats.burrow_created.value + 1
        else
            log('could not find burrow to add to')
            return
        end
    end
    if b then
        dfhack.burrows.setAssignedTile(b, pos, db_entry.add)
        stats['burrow_tiles_'..(db_entry.add and 'added' or 'removed')].value =
            stats['burrow_tiles_'..(db_entry.add and 'added' or 'removed')].value + 1
        if db_entry.civalert then
            if db_entry.add then
                civalert.add_civalert_burrow(b.id)
            else
                civalert.remove_civalert_burrow(b.id)
            end
        end
        if db_entry.autochop_clear or db_entry.autochop_chop then
            if db_entry.autochop_chop then
                dfhack.run_command('autochop', (db_entry.add and '' or 'no')..'chop', tostring(b.id))
            end
            if db_entry.autochop_clear then
                dfhack.run_command('autochop', (db_entry.add and '' or 'no')..'clear', tostring(b.id))
            end
        end
        if not db_entry.add and db_entry.create and #dfhack.burrows.listBlocks(b) == 0 then
            dfhack.burrows.clearTiles(b)
            local _, _, idx = utils.binsearch(burrows.list, b.id, 'id')
            if idx then
                burrows.list:erase(idx)
                b:delete()
                stats.burrow_destroyed.value = stats.burrow_destroyed.value + 1
            end
        end
    elseif not db_entry.add then
        for _,burrow in ipairs(burrows.list) do
            dfhack.burrows.setAssignedTile(burrow, pos, false)
        end
        stats.burrow_tiles_removed.value = stats.burrow_tiles_removed.value + 1
    end
end

function do_run_impl(zlevel, grid, ctx, invert)
    local stats = ctx.stats
    stats.burrow_created = stats.burrow_created or
            {label='Burrows created', value=0}
    stats.burrow_destroyed = stats.burrow_destroyed or
            {label='Burrows destroyed', value=0}
    stats.burrow_tiles_added = stats.burrow_tiles_added or
            {label='Burrow tiles added', value=0}
    stats.burrow_tiles_removed = stats.burrow_tiles_removed or
            {label='Burrow tiles removed', value=0}

    ctx.bounds = ctx.bounds or quickfort_map.MapBoundsChecker{}
    for y, row in pairs(grid) do
        for x, cell_and_text in pairs(row) do
            local cell, text = cell_and_text.cell, cell_and_text.text
            local pos = xyz2pos(x, y, zlevel)
            log('applying spreadsheet cell %s with text "%s" to map' ..
                ' coordinates (%d, %d, %d)', cell, text, pos.x, pos.y, pos.z)
            local db_entry = nil
            local keys, extent = quickfort_parse.parse_cell(ctx, text)
            if keys then db_entry = burrow_db[keys] end
            if not db_entry then
                dfhack.printerr(('invalid key sequence: "%s" in cell %s')
                                :format(text, cell))
                stats.invalid_keys.value = stats.invalid_keys.value + 1
                goto continue
            end
            if invert then
                db_entry = copyall(db_entry)
                db_entry.add = not db_entry.add
            end
            if extent.specified then
                -- shift pos to the upper left corner of the extent and convert
                -- the extent dimensions to positive, simplifying the logic below
                pos.x = math.min(pos.x, pos.x + extent.width + 1)
                pos.y = math.min(pos.y, pos.y + extent.height + 1)
            end
            for extent_x=1,math.abs(extent.width) do
                for extent_y=1,math.abs(extent.height) do
                    local extent_pos = xyz2pos(
                        pos.x+extent_x-1,
                        pos.y+extent_y-1,
                        pos.z)
                    if not ctx.bounds:is_on_map(extent_pos) then
                        log('coordinates out of bounds; skipping (%d, %d, %d)',
                            extent_pos.x, extent_pos.y, extent_pos.z)
                        stats.out_of_bounds.value =
                                stats.out_of_bounds.value + 1
                    else
                        quickfort_preview.set_preview_tile(ctx, extent_pos, true)
                        if not ctx.dry_run then
                            do_burrow(ctx, db_entry, extent_pos)
                        end
                    end
                end
            end
            ::continue::
        end
    end
end

function do_run(zlevel, grid, ctx)
    do_run_impl(zlevel, grid, ctx, false)
end

function do_orders()
    log('nothing to do for blueprints in mode: burrow')
end

function do_undo(zlevel, grid, ctx)
    do_run_impl(zlevel, grid, ctx, true)
end
