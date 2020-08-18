-- dig-related logic for the quickfort script
--@ module = true
--[[
This file designates tiles with the same rules as the in-game UI. For example,
if the tile is hidden, we designate blindly to avoid spoilers. If it's visible,
the shape and material of the target tile affects whether the designation has
any effect.
]]

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local utils = require('utils')
local quickfort_common = reqscript('internal/quickfort/common')
local log = quickfort_common.log

local function is_construction(tileattrs)
    return tileattrs.material == df.tiletype_material.CONSTRUCTION
end

local function is_floor(tileattrs)
    return tileattrs.shape == df.tiletype_shape.FLOOR
end

local function is_diggable_floor(tileattrs)
    return is_floor(tileattrs) or
            tileattrs.shape == df.tiletype_shape.BOULDER or
            tileattrs.shape == df.tiletype_shape.PEBBLES
end

local function is_wall(tileattrs)
    return tileattrs.shape == df.tiletype_shape.WALL
end

local function is_tree(tileattrs)
    return tileattrs.material == df.tiletype_material.TREE
end

local function is_fortification(tileattrs)
    return tileattrs.shape == df.tiletype_shape.FORTIFICATION
end

local function is_up_stair(tileattrs)
    return tileattrs.shape == df.tiletype_shape.STAIR_UP
end

local function is_down_stair(tileattrs)
    return tileattrs.shape == df.tiletype_shape.STAIR_DOWN
end

local function is_removable_shape(tileattrs)
    return tileattrs.shape == df.tiletype_shape.RAMP or
            tileattrs.shape == df.tiletype_shape.STAIR_UP or
            tileattrs.shape == df.tiletype_shape.STAIR_UPDOWN
end

local function is_gatherable(tileattrs)
    return tileattrs.shape == df.tiletype_shape.SHRUB
end

local function is_sapling(tileattrs)
    return tileattrs.shape == df.tiletype_shape.SAPLING
end

local hard_natural_materials = utils.invert({
    df.tiletype_material.STONE,
    df.tiletype_material.FEATURE,
    df.tiletype_material.LAVA_STONE,
    df.tiletype_material.MINERAL,
    df.tiletype_material.FROZEN_LIQUID,
})

local function is_hard(tileattrs)
    return hard_natural_materials[tileattrs.material]
end

local function is_smooth(tileattrs)
    return tileattrs.special == df.tiletype_special.SMOOTH
end

local function get_engraving(pos)
    -- scan through engravings until we find the one at this pos
    -- super inefficient. we could cache, but it's unlikely that players will
    -- have so many engravings that it would matter.
    for _, engraving in ipairs(df.global.world.engravings) do
        if same_xyz(pos, engraving.pos) then
            return engraving
        end
    end
    return nil
end

-- TODO: it would be useful to migrate has_designation and clear_designation to
-- the Maps module
local function has_designation(flags, occupancy)
    return flags.dig ~= df.tile_dig_designation.No or
            flags.smooth ~= 0 or
            occupancy.carve_track_north ~= 0 or
            occupancy.carve_track_east ~= 0 or
            occupancy.carve_track_south ~= 0 or
            occupancy.carve_track_west ~= 0
end

local function clear_designation(flags, occupancy)
    flags.dig = df.tile_dig_designation.No
    flags.smooth = 0
    occupancy.carve_track_north = 0
    occupancy.carve_track_east = 0
    occupancy.carve_track_south = 0
    occupancy.carve_track_west = 0
end

local values = nil

local values_run = {
    dig_default=df.tile_dig_designation.Default,
    dig_channel=df.tile_dig_designation.Channel,
    dig_upstair=df.tile_dig_designation.UpStair,
    dig_downstair=df.tile_dig_designation.DownStair,
    dig_updownstair=df.tile_dig_designation.UpDownStair,
    dig_ramp=df.tile_dig_designation.Ramp,
    dig_no=df.tile_dig_designation.No,
    tile_smooth=1,
    tile_engrave=2,
    track=1,
    item_claimed=false,
    item_forbidden=true,
    item_melted=true,
    item_unmelted=false,
    item_dumped=true,
    item_undumped=false,
    item_hidden=true,
    item_unhidden=false,
    traffic_normal=0,
    traffic_low=1,
    traffic_high=2,
    traffic_restricted=3,
}

-- undo isn't guaranteed to restore what was set on the tile before the last
-- 'run' command; it just sets a sensible default. we could implement true undo
-- if there is demand, though.
local values_undo = {
    dig_default=df.tile_dig_designation.No,
    dig_channel=df.tile_dig_designation.No,
    dig_upstair=df.tile_dig_designation.No,
    dig_downstair=df.tile_dig_designation.No,
    dig_updownstair=df.tile_dig_designation.No,
    dig_ramp=df.tile_dig_designation.No,
    dig_no=df.tile_dig_designation.No,
    tile_smooth=0,
    tile_engrave=0,
    track=0,
    item_claimed=false,
    item_forbidden=false,
    item_melted=false,
    item_unmelted=false,
    item_dumped=false,
    item_undumped=false,
    item_hidden=false,
    item_unhidden=false,
    traffic_normal=0,
    traffic_low=0,
    traffic_high=0,
    traffic_restricted=0,
}

-- these functions return whether a designation was made
local function do_mine(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_default
    return true
end

local function do_channel(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                is_tree(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs) and
                 not is_diggable_floor(ctx.tileattrs) and
                 not is_down_stair(ctx.tileattrs) and
                 not is_removable_shape(ctx.tileattrs) and
                 not is_gatherable(ctx.tileattrs) and
                 not is_sapling(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_channel
    return true
end

local function do_up_stair(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_upstair
    return true
end

local function do_down_stair(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                is_tree(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs) and
                 not is_diggable_floor(ctx.tileattrs) and
                 not is_removable_shape(ctx.tileattrs) and
                 not is_gatherable(ctx.tileattrs) and
                 not is_sapling(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_downstair
    return true
end

local function do_up_down_stair(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs) and
                 not is_up_stair(ctx.tileattrs)) then
            return false
        end
    end
    if is_up_stair(ctx.tileattrs) then
        ctx.flags.dig = values.dig_downstair
    else
        ctx.flags.dig = values.dig_updownstair
    end
    return true
end

local function do_ramp(ctx)
    if ctx.on_map_edge then return false end
    if not ctx.flags.hidden then -- always designate if the tile is hidden
        if is_construction(ctx.tileattrs) or
                (not is_wall(ctx.tileattrs) and
                 not is_fortification(ctx.tileattrs)) then
            return false
        end
    end
    ctx.flags.dig = values.dig_ramp
    return true
end

local function do_remove_ramps(ctx)
    if ctx.on_map_edge or ctx.flags.hidden then return false end
    if is_construction(ctx.tileattrs) or
            not is_removable_shape(ctx.tileattrs) then
        return false
    end
    ctx.flags.dig = values.dig_default
    return true
end

local function do_gather(ctx)
    if ctx.flags.hidden then return false end
    if not is_gatherable(ctx.tileattrs) then return false end
    ctx.flags.dig = values.dig_default
    return true
end

local function do_smooth(ctx)
    if ctx.flags.hidden then return false end
    if is_construction(ctx.tileattrs) or
            not is_hard(ctx.tileattrs) or
            is_smooth(ctx.tileattrs) or
            (not is_floor(ctx.tileattrs) and not is_wall(ctx.tileattrs)) then
        return false
    end
    ctx.flags.smooth = values.tile_smooth
    return true
end

local function do_engrave(ctx)
    if ctx.flags.hidden or
            is_construction(ctx.tileattrs) or
            not is_smooth(ctx.tileattrs) or
            get_engraving(ctx.pos) ~= nil then
        return false
    end
    ctx.flags.smooth = values.tile_engrave
    return true
end

local function do_fortification(ctx)
    if ctx.flags.hidden then return false end
    if not is_wall(ctx.tileattrs) or
            not is_smooth(ctx.tileattrs) then return false end
    ctx.flags.smooth = values.tile_smooth
    return true
end

local function do_track(ctx)
    if ctx.on_map_edge or
            ctx.flags.hidden or
            is_construction(ctx.tileattrs) or
            not is_floor(ctx.tileattrs) or
            not is_hard(ctx.tileattrs) then
        return false
    end
    local extent_adjacent = ctx.extent_adjacent
    if not extent_adjacent.north and not  extent_adjacent.south and
            not extent_adjacent.east and not extent_adjacent.west then
        print('ambiguous direction for track; please use T(width x height)' ..
              ' syntax (specify both width > 1 and height > 1 for a' ..
              ' track that extends both South and East from this corner')
        return false
    end
    if extent_adjacent.north and extent_adjacent.west then
        -- we're in the "empty" interior of a track extent - tracks can only be
        -- built in lines along the top or left of an extent.
        return false
    end
    -- don't overwrite all directions, only 'or' in the new bits. we could be
    -- adding to a previously-designated track.
    local occupancy = ctx.occupancy
    if extent_adjacent.north then occupancy.carve_track_north = values.track end
    if extent_adjacent.east then occupancy.carve_track_east = values.track end
    if extent_adjacent.south then occupancy.carve_track_south = values.track end
    if extent_adjacent.west then occupancy.carve_track_west = values.track end
    return true
end

local function do_toggle_engravings(ctx)
    if ctx.flags.hidden then return false end
    local engraving = get_engraving(ctx.pos)
    if engraving == nil then return false end
    engraving.flags.hidden = not engraving.flags.hidden
    return true
end

local function do_toggle_marker(ctx)
    if not has_designation(ctx.flags, ctx.occupancy) then return false end
    ctx.occupancy.dig_marked = not ctx.occupancy.dig_marked
    return true
end

local function do_remove_construction(ctx)
    if ctx.flags.hidden or not is_construction(ctx.tileattrs) then
        return false
    end
    ctx.flags.dig = values.dig_default
    return true
end

local function do_remove_designation(ctx)
    if not has_designation(ctx.flags, ctx.occupancy) then return false end
    clear_designation(ctx.flags, ctx.occupancy)
    return true
end

local function is_valid_item(item)
    return not item.flags.garbage_collect
end

local function get_items_at(pos, include_buildings)
    local items = {}
    if include_buildings then
        local bld = dfhack.buildings.findAtTile(pos)
        if bld and same_xyz(pos, xyz2pos(bld.centerx, bld.centery, bld.z)) then
            for _, contained_item in ipairs(bld.contained_items) do
                if is_valid_item(contained_item.item) then
                    table.insert(items, contained_item.item)
                end
            end
        end
    end
    for _, item_id in ipairs(dfhack.maps.getTileBlock(pos).items) do
        local item = df.item.find(item_id)
        if same_xyz(pos, item.pos) and
                is_valid_item(item) and item.flags.on_ground then
            table.insert(items, item)
        end
    end
    return items
end

local function do_item_flag(pos, flag_name, flag_value, include_buildings)
    local ret = false
    for _, item in ipairs(get_items_at(pos, include_buildings)) do
        item.flags[flag_name] = flag_value
        ret = true
    end
    return ret
end

local function do_claim(ctx)
    return do_item_flag(ctx.pos, "forbid", values.item_claimed, true)
end

local function do_forbid(ctx)
    return do_item_flag(ctx.pos, "forbid", values.item_forbidden, true)
end

local function do_melt(ctx)
    -- the game appears to autoremove the flag from unmeltable items, so we
    -- don't actually need to do any filtering here
    return do_item_flag(ctx.pos, "melt", values.item_melted, false)
end

local function do_remove_melt(ctx)
    return do_item_flag(ctx.pos, "melt", values.item_unmelted, false)
end

local function do_dump(ctx)
    return do_item_flag(ctx.pos, "dump", values.item_dumped, false)
end

local function do_remove_dump(ctx)
    return do_item_flag(ctx.pos, "dump", values.item_undumped, false)
end

local function do_hide(ctx)
    return do_item_flag(ctx.pos, "hidden", values.item_hidden, true)
end

local function do_unhide(ctx)
    return do_item_flag(ctx.pos, "hidden", values.item_unhidden, true)
end

local function do_traffic_high(ctx)
    if ctx.flags.hidden then return false end
    ctx.flags.traffic = values.traffic_high
end

local function do_traffic_normal(ctx)
    if ctx.flags.hidden then return false end
    ctx.flags.traffic = values.traffic_normal
end

local function do_traffic_low(ctx)
    if ctx.flags.hidden then return false end
    ctx.flags.traffic = values.traffic_low
end

local function do_traffic_restricted(ctx)
    if ctx.flags.hidden then return false end
    ctx.flags.traffic = values.traffic_restricted
end

local designate_switch = {
    d=do_mine,
    h=do_channel,
    u=do_up_stair,
    j=do_down_stair,
    i=do_up_down_stair,
    r=do_ramp,
    z=do_remove_ramps,
    t=do_mine,
    p=do_gather,
    s=do_smooth,
    e=do_engrave,
    F=do_fortification,
    T=do_track,
    v=do_toggle_engravings,
    M=do_toggle_marker,
    n=do_remove_construction,
    x=do_remove_designation,
    bc=do_claim,
    bf=do_forbid,
    bm=do_melt,
    bM=do_remove_melt,
    bd=do_dump,
    bD=do_remove_dump,
    bh=do_hide,
    bH=do_unhide,
    oh=do_traffic_high,
    on=do_traffic_normal,
    ol=do_traffic_low,
    ['or']=do_traffic_restricted,
}

local function dig_tile(ctx, code, marker_mode)
    ctx.flags, ctx.occupancy = dfhack.maps.getTileFlags(ctx.pos)
    ctx.tileattrs = df.tiletype.attrs[dfhack.maps.getTileType(ctx.pos)]
    if designate_switch[code](ctx) then
        dfhack.maps.getTileBlock(ctx.pos).flags.designated = true
        if not has_designation(ctx.flags, ctx.occupancy) then
            ctx.occupancy.dig_marked = false
        elseif code == "dM" then
            -- the semantics are a little unclear if the code is M (toggle
            -- marker mode) but m or force_marker_mode is also specified.
            -- for now, let either turn marker mode on
            ctx.occupancy.dig_marked = ctx.occupancy.dig_marked or marker_mode
        else
            ctx.occupancy.dig_marked = marker_mode
        end
        return true
    end
    return false
end

local function do_run_impl(zlevel, grid)
    local stats = {
        designated={label='Tiles designated', value=0, always=true},
        out_of_bounds={label='Tiles skipped (outside map boundary)', value=0},
        invalid_keys={label='Invalid key sequences', value=0},
    }

    for y, row in pairs(grid) do
        for x, cell_and_text in pairs(row) do
            local cell, text = cell_and_text.cell, cell_and_text.text
            local pos = xyz2pos(x, y, zlevel)
            log('applying spreadsheet cell %s with text "%s" to map' ..
                ' coordinates (%d, %d, %d)', cell, text, pos.x, pos.y, pos.z)
            local keys, extent = quickfort_common.parse_cell(text)
            local marker_mode =
                    quickfort_common.settings['force_marker_mode'].value
            if keys:startswith('m') then
                keys = string.sub(keys, 2)
                marker_mode = true
            end
            if not designate_switch[keys] then
                print(string.format('invalid key sequence: "%s"', text))
                stats.invalid_keys.value = stats.invalid_keys.value+1
                goto continue
            end
            for extent_x=1,extent.width do
                for extent_y=1,extent.height do
                    local extent_pos = xyz2pos(
                        pos.x+extent_x-1,
                        pos.y+extent_y-1,
                        pos.z)
                    local extent_adjacent = {
                        north=extent_y>1,
                        east=extent_x<extent.width,
                        south=extent_y<extent.height,
                        west=extent_x>1,
                    }
                    local ctx = {
                        pos=extent_pos,
                        extent_adjacent=extent_adjacent,
                        on_map_edge=quickfort_common.is_on_map_edge(extent_pos)
                    }
                    if not quickfort_common.is_within_map_bounds(ctx.pos) and
                            not ctx.on_map_edge then
                        log('coordinates out of bounds; skipping')
                        stats.out_of_bounds.value = stats.out_of_bounds.value+1
                    else
                        if dig_tile(ctx, keys, marker_mode) then
                            stats.designated.value = stats.designated.value+1
                        end
                    end
                end
            end
            ::continue::
        end
    end
    return stats
end

function do_run(zlevel, grid)
    values = values_run
    local stats = do_run_impl(zlevel, grid)
    dfhack.job.checkDesignationsNow()
    return stats
end

function do_orders(zlevel, grid)
    log('nothing to do for blueprints in mode: dig')
    return nil
end

function do_undo(zlevel, grid)
    values = values_undo
    return do_run_impl(zlevel, grid)
end
