-- zone-related data and logic for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

require('dfhack.buildings') -- loads additional functions into dfhack.buildings
local utils = require('utils')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_building = reqscript('internal/quickfort/building')
local quickfort_map = reqscript('internal/quickfort/map')
local quickfort_parse = reqscript('internal/quickfort/parse')

local log = quickfort_common.log
local logfn = quickfort_common.logfn

local function is_valid_zone_tile(pos)
    return not dfhack.maps.getTileFlags(pos).hidden
end

local function is_valid_zone_extent(s)
    for extent_x, col in ipairs(s.extent_grid) do
        for extent_y, in_extent in ipairs(col) do
            if in_extent then return true end
        end
    end
    return false
end

local zone_template = {
    has_extents=true, min_width=1, max_width=31, min_height=1, max_height=31,
    is_valid_tile_fn = is_valid_zone_tile,
    is_valid_extent_fn = is_valid_zone_extent
}

local zone_db = {
    a={label='Inactive', zone_flags={active=false}},
    w={label='Water Source', zone_flags={water_source=true}},
    f={label='Fishing', zone_flags={fishing=true}},
    g={label='Gather/Pick Fruit', zone_flags={gather=true}},
    d={label='Garbage Dump', zone_flags={garbage_dump=true}},
    n={label='Pen/Pasture', zone_flags={pen_pasture=true}},
    p={label='Pit/Pond', zone_flags={pit_pond=true}},
    s={label='Sand', zone_flags={sand=true}},
    c={label='Clay', zone_flags={clay=true}},
    m={label='Meeting Area', zone_flags={meeting_area=true}},
    h={label='Hospital', zone_flags={hospital=true}},
    t={label='Animal Training', zone_flags={animal_training=true}},
}
for _, v in pairs(zone_db) do utils.assign(v, zone_template) end

local function parse_pit_pond_subconfig(keys, flags)
    for c in keys:gmatch('.') do
        if c == 'f' then
            flags.is_pond = true
        else
            qerror(string.format('invalid pit/pond config char: "%s"', c))
        end
    end
end

local function parse_gather_subconfig(keys, flags)
    -- all options are on by default; specifying them turns them off
    for c in keys:gmatch('.') do
        if c == 't' then
            flags.pick_trees = false
        elseif c == 's' then
            flags.pick_shrubs = false
        elseif c == 'f' then
            flags.gather_fallen = false
        else
            qerror(string.format('invalid gather config char: "%s"', c))
        end
    end
end

local hospital_max_values = {
    thread=1500000,
    cloth=1000000,
    splints=100,
    crutches=100,
    plaster=15000,
    buckets=100,
    soap=15000
}

local function set_hospital_supplies(key, val, flags)
    if not hospital_max_values[key] then
        qerror(string.format('invalid hospital setting: "%s"', key))
    end
    local val_num = tonumber(val)
    if not val_num or val_num < 0 or val_num > hospital_max_values[key] then
        qerror(string.format(
            'invalid hospital supply count: "%s". must be between 0 and %d',
            val, hospital_max_values[key]))
    end
    flags['max_'..key] = val_num
    flags.supplies_needed[key] = val_num > 0
end

-- full format (all params optional):
-- {hospital thread=num cloth=num splints=num crutches=num plaster=num buckets=num soap=num}
local function parse_hospital_subconfig(keys, flags)
    local etoken, params = quickfort_parse.parse_extended_token(keys)
    if etoken:lower() ~= 'hospital' then
        qerror(string.format('invalid hospital settings: "%s"', keys))
    end
    for k,v in pairs(params) do
        set_hospital_supplies(k, v, flags)
    end
end

local function parse_zone_config(keys, labels, zone_data)
    local i = 1
    while i <= #keys do
        local c = keys:sub(i, i)
        if rawget(zone_db, c) then
            local db_entry = zone_db[c]
            if (db_entry.zone_flags.pen_pasture or
                zone_data.zone_flags.pen_pasture) and
                (db_entry.zone_flags.pit_pond or
                 zone_data.zone_flags.pit_pond) then
                qerror("zone cannot be both a pen/pasture and a pit/pond")
            end
            table.insert(labels, db_entry.label)
            utils.assign(zone_data.zone_flags, db_entry.zone_flags)
        elseif c == 'P' then
            zone_data.pit_flags = {}
            parse_pit_pond_subconfig(keys:sub(i+1), zone_data.pit_flags)
            break
        elseif c == 'G' then
            zone_data.gather_flags = {}
            parse_gather_subconfig(keys:sub(i+1), zone_data.gather_flags)
            break
        elseif c == 'H' then
            zone_data.hospital = {supplies_needed={}}
            parse_hospital_subconfig(keys:sub(i+1), zone_data.hospital)
            break
        end
        i = i + 1
    end
end

local function custom_zone(_, keys)
    local labels = {}
    local zone_data = {zone_flags={}}
    -- subconfig sequences are separated by '^' characters
    for zone_config in keys:gmatch('[^^]+') do
        parse_zone_config(zone_config, labels, zone_data)
    end
    zone_data.label = table.concat(labels, '+')
    utils.assign(zone_data, zone_template)
    return zone_data
end

setmetatable(zone_db, {__index=custom_zone})

local function dump_flags(args)
    local flags = args[1]
    for k,v in pairs(flags) do
        if type(v) ~= 'table' then
            print(string.format('  %s: %s', k, v))
        end
    end
end

local function assign_flags(bld, db_entry, key, dry_run)
    local flags = db_entry[key]
    if flags then
        log('assigning %s:', key)
        logfn(dump_flags, flags)
        if not dry_run then utils.assign(bld[key], flags) end
    end
end

local function create_zone(zone, dry_run)
    local db_entry = zone_db[zone.type]
    log('creating %s zone at map coordinates (%d, %d, %d), defined' ..
        ' from spreadsheet cells: %s',
        db_entry.label, zone.pos.x, zone.pos.y, zone.pos.z,
        table.concat(zone.cells, ', '))
    local extents, ntiles =
            quickfort_building.make_extents(zone, dry_run)
    local bld, err = nil, nil
    if not dry_run then
        local fields = {room={x=zone.pos.x, y=zone.pos.y, width=zone.width,
                              height=zone.height, extents=extents},
                        is_room=true}
        bld, err = dfhack.buildings.constructBuilding{
            type=df.building_type.Civzone, subtype=df.civzone_type.ActivityZone,
            abstract=true, pos=zone.pos, width=zone.width, height=zone.height,
            fields=fields}
        if not bld then
            -- this is an error instead of a qerror since our validity checking
            -- is supposed to prevent this from ever happening
            error(string.format('unable to designate zone: %s', err))
        end
        -- set defaults (should move into constructBuilding)
        bld.zone_flags.active = true
        bld.gather_flags.pick_trees = true
        bld.gather_flags.pick_shrubs = true
        bld.gather_flags.gather_fallen = true
    end
    -- set specified flags
    assign_flags(bld, db_entry, 'zone_flags', dry_run)
    assign_flags(bld, db_entry, 'pit_flags', dry_run)
    assign_flags(bld, db_entry, 'gather_flags', dry_run)
    assign_flags(bld, db_entry, 'hospital', dry_run)
    return ntiles
end

function do_run(zlevel, grid, ctx)
    local stats = ctx.stats
    stats.zone_designated = stats.zone_designated or
            {label='Zones designated', value=0, always=true}
    stats.zone_tiles = stats.zone_tiles or
            {label='Zone tiles designated', value=0}
    stats.zone_occupied = stats.zone_occupied or
            {label='Zone tiles skipped (tile occupied)', value=0}

    local zones = {}
    stats.invalid_keys.value =
            stats.invalid_keys.value + quickfort_building.init_buildings(
                ctx, zlevel, grid, zones, zone_db)
    stats.out_of_bounds.value =
            stats.out_of_bounds.value + quickfort_building.crop_to_bounds(
                ctx, zones, zone_db)
    stats.zone_occupied.value =
            stats.zone_occupied.value +
            quickfort_building.check_tiles_and_extents(
                ctx, zones, zone_db)

    for _,zone in ipairs(zones) do
        if zone.pos then
            local ntiles = create_zone(zone, ctx.dry_run)
            stats.zone_tiles.value = stats.zone_tiles.value + ntiles
            stats.zone_designated.value = stats.zone_designated.value + 1
        end
    end
end

function do_orders()
    log('nothing to do for blueprints in mode: zone')
end

local function get_activity_zones(pos)
    local activity_zones = {}
    local civzones = dfhack.buildings.findCivzonesAt(pos)
    if not civzones then return activity_zones end
    for _,civzone in ipairs(civzones) do
        if civzone.type == df.civzone_type.ActivityZone then
            table.insert(activity_zones, civzone)
        end
    end
    return activity_zones
end

function do_undo(zlevel, grid, ctx)
    local stats = ctx.stats
    stats.zone_removed = stats.zone_removed or
            {label='Zones removed', value=0, always=true}

    local zones = {}
    stats.invalid_keys.value =
            stats.invalid_keys.value + quickfort_building.init_buildings(
                ctx, zlevel, grid, zones, zone_db)

    -- ensure a zone is not currently selected when we delete it. that causes
    -- crashes. note that we move the cursor, but we have to keep the ui mode
    -- the same. otherwise the zone stays selected (somehow) in memory. we only
    -- move the cursor when we're in mode Zones to avoid having the viewport
    -- jump around when it doesn't need to
    local restore_cursor = false
    if not dry_run and df.global.ui.main.mode == df.ui_sidebar_mode.Zones then
        quickfort_map.move_cursor(xyz2pos(-1, -1, ctx.cursor.z))
        restore_cursor = true
    end

    for _, zone in ipairs(zones) do
        for extent_x, col in ipairs(zone.extent_grid) do
            for extent_y, in_extent in ipairs(col) do
                if not zone.extent_grid[extent_x][extent_y] then goto continue end
                local pos = xyz2pos(zone.pos.x+extent_x-1,
                                    zone.pos.y+extent_y-1, zone.pos.z)
                local activity_zones = get_activity_zones(pos)
                for _,activity_zone in ipairs(activity_zones) do
                    log('removing zone at map coordinates (%d, %d, %d)',
                        pos.x, pos.y, pos.z)
                    if not dry_run then
                        dfhack.buildings.deconstruct(activity_zone)
                    end
                    stats.zone_removed.value = stats.zone_removed.value + 1
                end
                ::continue::
            end
        end
    end

    if restore_cursor then quickfort_map.move_cursor(ctx.cursor) end
end
