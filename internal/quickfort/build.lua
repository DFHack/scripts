-- build-related data and logic for the quickfort script
--@ module = true
--[[
In general, we enforce the same rules as the in-game UI for allowed placement of
buildings (e.g. beds have to be inside, doors have to be adjacent to a wall,
etc.). A notable exception is that we allow constructions and machine components
to be designated regardless of whether they are reachable or currently
supported. This allows the user to designate an entire floor of an above-ground
building or an entire power system without micromanagement. We also don't
enforce that materials are accessible from the designation location. That is
something that the player can manage.
]]


if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local utils = require('utils')
local buildingplan = require('plugins.buildingplan')
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_building = reqscript('internal/quickfort/building')
local quickfort_orders = reqscript('internal/quickfort/orders')
local quickfort_transform = reqscript('internal/quickfort/transform')

local log = quickfort_common.log

--
-- ************ tile validity checking functions ************ --
--

local function is_valid_tile_base(pos)
    local flags, occupancy = dfhack.maps.getTileFlags(pos)
    if not flags then return false end
    return not flags.hidden and occupancy.building == 0
end

local function is_valid_tile_generic(pos)
    if not is_valid_tile_base(pos) then return false end
    local shape = df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape
    return shape == df.tiletype_shape.FLOOR or
            shape == df.tiletype_shape.BOULDER or
            shape == df.tiletype_shape.PEBBLES or
            shape == df.tiletype_shape.TWIG or
            shape == df.tiletype_shape.SAPLING or
            shape == df.tiletype_shape.SHRUB
end

local function is_valid_tile_inside(pos)
    return is_valid_tile_generic(pos) and
            not dfhack.maps.getTileFlags(pos).outside
end

local function is_valid_tile_dirt(pos)
    local tileattrs = df.tiletype.attrs[dfhack.maps.getTileType(pos)]
    local shape = tileattrs.shape
    local mat = tileattrs.material
    local bad_shape =
            shape == df.tiletype_shape.BOULDER or
            shape == df.tiletype_shape.PEBBLES
    local good_material =
            mat == df.tiletype_material.SOIL or
            mat == df.tiletype_material.GRASS_LIGHT or
            mat == df.tiletype_material.GRASS_DARK or
            mat == df.tiletype_material.GRASS_DRY or
            mat == df.tiletype_material.GRASS_DEAD or
            mat == df.tiletype_material.PLANT
    return is_valid_tile_generic(pos) and not bad_shape and good_material
end

-- essentially, anywhere you could build a construction, plus constructed floors
local function is_valid_tile_has_space(pos)
    if not is_valid_tile_base(pos) then return false end
    local shape = df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape
    return shape == df.tiletype_shape.EMPTY or
            shape == df.tiletype_shape.FLOOR or
            shape == df.tiletype_shape.BOULDER or
            shape == df.tiletype_shape.PEBBLES or
            shape == df.tiletype_shape.RAMP_TOP or
            shape == df.tiletype_shape.BROOK_TOP or
            shape == df.tiletype_shape.TWIG or
            shape == df.tiletype_shape.SAPLING or
            shape == df.tiletype_shape.SHRUB
end

local function is_valid_tile_has_space_or_is_ramp(pos)
    local shape = df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape
    return is_valid_tile_has_space(pos) or shape == df.tiletype_shape.RAMP
end

local function is_valid_tile_machine(pos)
    return is_valid_tile_has_space_or_is_ramp(pos)
end

-- ramps are ok everywhere except under the anchor point of directional bridges
local function is_valid_tile_bridge(pos, db_entry, b)
    local dir = db_entry.direction
    local T_direction = df.building_bridgest.T_direction
    if (dir == T_direction.Up and pos.y == b.pos.y) or
            (dir == T_direction.Down and pos.y == b.pos.y+b.height-1) or
            (dir == T_direction.Left and pos.x == b.pos.x) or
            (dir == T_direction.Right and pos.x == b.pos.x+b.width-1) then
        return is_valid_tile_has_space(pos)
    end
    return is_valid_tile_has_space_or_is_ramp(pos)
end

local function is_valid_tile_construction(pos)
    local tileattrs = df.tiletype.attrs[dfhack.maps.getTileType(pos)]
    local shape = tileattrs.shape
    local mat = tileattrs.material
    return is_valid_tile_has_space_or_is_ramp(pos) and
            mat ~= df.tiletype_material.CONSTRUCTION
end

local function is_shape_at(pos, allowed_shapes)
    local tiletype = dfhack.maps.getTileType(pos)
    if not tiletype then return false end
    return allowed_shapes[df.tiletype.attrs[tiletype].shape]
end

-- for doors
local allowed_door_shapes = utils.invert({
    df.tiletype_shape.WALL,
    df.tiletype_shape.FORTIFICATION
})
local function is_tile_generic_and_wall_adjacent(pos)
    if not is_valid_tile_generic(pos) then return false end
    return is_shape_at(xyz2pos(pos.x+1, pos.y, pos.z), allowed_door_shapes) or
            is_shape_at(xyz2pos(pos.x-1, pos.y, pos.z), allowed_door_shapes) or
            is_shape_at(xyz2pos(pos.x, pos.y+1, pos.z), allowed_door_shapes) or
            is_shape_at(xyz2pos(pos.x, pos.y-1, pos.z), allowed_door_shapes)
end

local function is_tile_floor_adjacent(pos)
    return is_valid_tile_generic(xyz2pos(pos.x+1, pos.y, pos.z)) or
            is_valid_tile_generic(xyz2pos(pos.x-1, pos.y, pos.z)) or
            is_valid_tile_generic(xyz2pos(pos.x, pos.y+1, pos.z)) or
            is_valid_tile_generic(xyz2pos(pos.x, pos.y-1, pos.z))
end

-- for wells
local function is_tile_empty_and_floor_adjacent(pos)
    local shape = df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape
    if not is_valid_tile_base(pos) or
            (shape ~= df.tiletype_shape.EMPTY and
             shape ~= df.tiletype_shape.RAMP_TOP) then
        return false
    end
    return is_tile_floor_adjacent(pos)
end

-- for floor hatches, grates, and bars
local function is_tile_coverable(pos)
    local shape = df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape
    if not is_valid_tile_base(pos) or
            (shape ~= df.tiletype_shape.FLOOR and
             shape ~= df.tiletype_shape.EMPTY and
             shape ~= df.tiletype_shape.RAMP_TOP and
             shape ~= df.tiletype_shape.STAIR_DOWN) then
        return false
    end
    return is_tile_floor_adjacent(pos)
end

--
-- ************ extent validity checking functions ************ --
--

-- extent checking functions assume valid, non-zero width or height extents
local function is_extent_solid(b)
    local area = b.width * b.height
    local num_tiles = 0
    for extent_x, col in ipairs(b.extent_grid) do
        for extent_y, in_extent in ipairs(col) do
            if in_extent then num_tiles = num_tiles + 1 end
        end
    end
    return num_tiles == area
end

local function is_extent_nonempty(b)
    for extent_x, col in ipairs(b.extent_grid) do
        for extent_y, in_extent in ipairs(col) do
            if in_extent then return true end
        end
    end
    return false
end

--
-- ************ the database ************ --
--

local unit_vectors = quickfort_transform.unit_vectors
local unit_vectors_revmap = quickfort_transform.unit_vectors_revmap

local function make_transform_building_fn(vector, revmap, post_fn)
    return function(ctx)
        local keys = quickfort_transform.resolve_transformed_vector(
                                                        ctx, vector, revmap)
        if post_fn then keys = post_fn(keys) end
        return keys
    end
end

local bridge_data = {
    [df.building_bridgest.T_direction.Retracting]={label='Retracting'},
    [df.building_bridgest.T_direction.Up]={label='Raises to North',
                                           vector=unit_vectors.north},
    [df.building_bridgest.T_direction.Right]={label='Raises to East',
                                              vector=unit_vectors.east},
    [df.building_bridgest.T_direction.Down]={label='Raises to South',
                                             vector=unit_vectors.south},
    [df.building_bridgest.T_direction.Left]={label='Raises to West',
                                             vector=unit_vectors.west}
}
local bridge_revmap = {
    [unit_vectors_revmap.north]='gw',
    [unit_vectors_revmap.east]='gd',
    [unit_vectors_revmap.south]='gx',
    [unit_vectors_revmap.west]='ga'
}
local function make_bridge_entry(direction)
    local bridge_data_entry = bridge_data[direction]
    local transform = nil
    if direction ~= df.building_bridgest.T_direction.Retracting then
        transform = make_transform_building_fn(bridge_data_entry.vector,
                                               bridge_revmap)
    end
    return {label=('Bridge (%s)'):format(bridge_data_entry.label),
            type=df.building_type.Bridge,
            direction=direction,
            min_width=1,
            max_width=10,
            min_height=1,
            max_height=10,
            is_valid_tile_fn=is_valid_tile_bridge,
            transform=transform}
end

local screw_pump_data = {
    [df.screw_pump_direction.FromNorth]={label='North', vertical=true,
                                         vector=unit_vectors.north},
    [df.screw_pump_direction.FromEast]={label='East',
                                        vector=unit_vectors.east},
    [df.screw_pump_direction.FromSouth]={label='South', vertical=true,
                                         vector=unit_vectors.south},
    [df.screw_pump_direction.FromWest]={label='West',
                                        vector=unit_vectors.west}
}
local screw_pump_revmap = {
    [unit_vectors_revmap.north]='Msu',
    [unit_vectors_revmap.east]='Msk',
    [unit_vectors_revmap.south]='Msm',
    [unit_vectors_revmap.west]='Msh'
}
local function make_screw_pump_entry(direction)
    local width, height = 1, 1
    local screw_pump_data_entry = screw_pump_data[direction]
    if screw_pump_data_entry.vertical then
        height = 2
    else
        width = 2
    end
    local transform = make_transform_building_fn(screw_pump_data_entry.vector,
                                                 screw_pump_revmap)
    return {label=string.format('Screw Pump (Pump From %s)',
                                screw_pump_data_entry.label),
            type=df.building_type.ScrewPump,
            min_width=width, max_width=width,
            min_height=height, max_height=height,
            direction=direction,
            is_valid_tile_fn=is_valid_tile_machine,
            transform=transform}
end

local ns_ew_data = {
    [true]={label='N/S', vector=unit_vectors.north},
    [false]={label='E/W', vector=unit_vectors.east}
}
local water_wheel_revmap = {
    [unit_vectors_revmap.north]='Mw',
    [unit_vectors_revmap.east]='Mws',
    [unit_vectors_revmap.south]='Mw',
    [unit_vectors_revmap.west]='Mws'
}
local horizontal_axle_revmap = {
    [unit_vectors_revmap.north]='Mhs',
    [unit_vectors_revmap.east]='Mh',
    [unit_vectors_revmap.south]='Mhs',
    [unit_vectors_revmap.west]='Mh'
}
local function make_ns_ew_entry(name, building_type, long_dim_min, long_dim_max,
                                revmap, vertical)
    local width_min, width_max, height_min, height_max = 1, 1, 1, 1
    local ns_ew_data_entry = ns_ew_data[vertical]
    if vertical then
        height_min, height_max = long_dim_min, long_dim_max
    else
        width_min, width_max = long_dim_min, long_dim_max
    end
    local transform = make_transform_building_fn(ns_ew_data_entry.vector,
                                                 revmap)
    return {label=('%s (%s)'):format(name, ns_ew_data_entry.label),
            type=building_type,
            min_width=width_min, max_width=width_max,
            min_height=height_min, max_height=height_max,
            direction=vertical and 1 or 0,
            is_valid_tile_fn=is_valid_tile_has_space, -- impeded by ramps
            transform=transform}
end
local function make_water_wheel_entry(vertical)
    return make_ns_ew_entry('Water Wheel', df.building_type.WaterWheel, 3, 3,
                            water_wheel_revmap, vertical)
end
local function make_horizontal_axle_entry(vertical)
    return make_ns_ew_entry('Horizontal Axle', df.building_type.AxleHorizontal,
                            1, 10, horizontal_axle_revmap, vertical)
end

local roller_data = {
    [df.screw_pump_direction.FromNorth]={label='N->S', vertical=true,
                                         vector=unit_vectors.north},
    [df.screw_pump_direction.FromEast]={label='E->W',
                                        vector=unit_vectors.east},
    [df.screw_pump_direction.FromSouth]={label='S->N', vertical=true,
                                         vector=unit_vectors.south},
    [df.screw_pump_direction.FromWest]={label='W->E',
                                        vector=unit_vectors.west}
}
local roller_revmap = {
    [unit_vectors_revmap.north]='Mr',
    [unit_vectors_revmap.east]='Mrs',
    [unit_vectors_revmap.south]='Mrss',
    [unit_vectors_revmap.west]='Mrsss'
}
local roller_speedmap = {
    [50000]='',
    [40000]='q',
    [30000]='qq',
    [20000]='qqq',
    [10000]='qqqq'
}
local function make_transform_roller_fn(vector, speed)
    local function post_fn(keys) return keys .. roller_speedmap[speed] end
    return make_transform_building_fn(vector, roller_revmap, post_fn)
end
local function make_roller_entry(direction, speed)
    local roller_data_entry = roller_data[direction]
    local transform = make_transform_roller_fn(roller_data_entry.vector, speed)
    return {
        label=('Rollers (%s)'):format(roller_data_entry.label),
        type=df.building_type.Rollers,
        min_width=1, max_width=roller_data_entry.vertical and 1 or 10,
        min_height=1, max_height=roller_data_entry.vertical and 10 or 1,
        direction=direction,
        fields={speed=speed},
        is_valid_tile_fn=is_valid_tile_machine,
        transform=transform
    }
end

local trackstop_data = {
    dump_y_shift={[-1]={label='Dump North', vector=unit_vectors.north},
                  [1]={label='Dump South', vector=unit_vectors.south}},
    dump_x_shift={[-1]={label='Dump West', vector=unit_vectors.west},
                  [1]={label='Dump East', vector=unit_vectors.east}}
}
local trackstop_revmap = {
    [unit_vectors_revmap.north]='CSd',
    [unit_vectors_revmap.east]='CSddd',
    [unit_vectors_revmap.south]='CSdd',
    [unit_vectors_revmap.west]='CSdddd'
}
local trackstop_frictionmap = {
    [50000]='',
    [10000]='a',
    [500]='aa',
    [50]='aaa',
    [10]='aaaa'
}
local function make_transform_trackstop_fn(vector, friction)
    local function post_fn(keys)
        return keys .. trackstop_frictionmap[friction]
    end
    return make_transform_building_fn(vector, trackstop_revmap, post_fn)
end
local function make_trackstop_entry(direction, friction)
    local label, fields, transform = 'No Dump', {friction=friction}, nil
    if direction then
        fields.use_dump = 1
        for k,v in pairs(direction) do
            local trackstop_data_entry = trackstop_data[k][v]
            label = trackstop_data_entry.label
            fields[k] = v
            transform = make_transform_trackstop_fn(
                    trackstop_data_entry.vector, friction)
        end
    end
    return {
        label=('Track Stop (%s)'):format(label),
        type=df.building_type.Trap,
        subtype=df.trap_type.TrackStop,
        fields=fields,
        transform=transform,
        additional_orders={'wooden minecart'}
    }
end

local track_end_data = {
    N=unit_vectors.north,
    E=unit_vectors.east,
    S=unit_vectors.south,
    W=unit_vectors.west
}
local track_end_revmap = {
    [unit_vectors_revmap.north]='N',
    [unit_vectors_revmap.east]='E',
    [unit_vectors_revmap.south]='S',
    [unit_vectors_revmap.west]='W'
}

local track_through_data = {
    NS=unit_vectors.north,
    EW=unit_vectors.east
}
local track_through_revmap = {
    [unit_vectors_revmap.north]='NS',
    [unit_vectors_revmap.east]='EW',
    [unit_vectors_revmap.south]='NS',
    [unit_vectors_revmap.west]='EW'
}

-- the tables below don't use unit vectors since we need to map how both axes
-- are transformed. we need 8 potential landing points, not just four.
local track_corner_data = {
    NE={x=1, y=-2},
    NW={x=-2, y=-1},
    SE={x=2, y=1},
    SW={x=-1, y=2}
}
local track_corner_revmap = {
    ['x=1, y=-2'] = 'NE',
    ['x=2, y=-1'] = 'NE',
    ['x=2, y=1'] = 'SE',
    ['x=1, y=2'] = 'SE',
    ['x=-1, y=2'] = 'SW',
    ['x=-2, y=1'] = 'SW',
    ['x=-2, y=-1'] = 'NW',
    ['x=-1, y=-2'] = 'NW'
}

local track_tee_data = {
    NSE={x=1, y=-2},
    NEW={x=-2, y=-1},
    SEW={x=2, y=1},
    NSW={x=-1, y=2}
}
local track_tee_revmap = {
    ['x=1, y=-2'] = 'NSE',
    ['x=2, y=-1'] = 'NEW',
    ['x=2, y=1'] = 'SEW',
    ['x=1, y=2'] = 'NSE',
    ['x=-1, y=2'] = 'NSW',
    ['x=-2, y=1'] = 'SEW',
    ['x=-2, y=-1'] = 'NEW',
    ['x=-1, y=-2'] = 'NSW'
}

local function make_transform_track_fn(vector, revmap, is_ramp)
    local prefix = is_ramp and 'trackramp' or 'track'
    local function post_fn(keys) return prefix .. keys end
    return make_transform_building_fn(vector, revmap, post_fn)
end
local function make_track_entry(name, data, revmap, is_ramp)
    local typename = 'Track'..(is_ramp and 'Ramp' or '')..name
    local transform = nil
    if data and revmap then
        transform = make_transform_track_fn(data[name], revmap, is_ramp)
    end
    return {label=('Track%s (%s)'):format(is_ramp and '/Ramp' or '', name),
            type=df.building_type.Construction,
            subtype=df.construction_type[typename],
            transform=transform}
end

-- grouped by type, generally in ui order
local building_db = {
    -- basic building types
    a={label='Armor Stand', type=df.building_type.Armorstand},
    b={label='Bed', type=df.building_type.Bed,
       is_valid_tile_fn=is_valid_tile_inside},
    c={label='Seat', type=df.building_type.Chair},
    n={label='Burial Receptacle', type=df.building_type.Coffin},
    d={label='Door', type=df.building_type.Door,
       is_valid_tile_fn=is_tile_generic_and_wall_adjacent},
    x={label='Floodgate', type=df.building_type.Floodgate},
    H={label='Floor Hatch', type=df.building_type.Hatch,
       is_valid_tile_fn=is_tile_coverable},
    W={label='Wall Grate', type=df.building_type.GrateWall},
    G={label='Floor Grate', type=df.building_type.GrateFloor,
       is_valid_tile_fn=is_tile_coverable},
    B={label='Vertical Bars', type=df.building_type.BarsVertical},
    ['{Alt}b']={label='Floor Bars', type=df.building_type.BarsFloor,
                is_valid_tile_fn=is_tile_coverable},
    f={label='Cabinet', type=df.building_type.Cabinet},
    h={label='Container', type=df.building_type.Box},
    r={label='Weapon Rack', type=df.building_type.Weaponrack},
    s={label='Statue', type=df.building_type.Statue},
    ['{Alt}s']={label='Slab', type=df.building_type.Slab},
    t={label='Table', type=df.building_type.Table},
    gs=make_bridge_entry(df.building_bridgest.T_direction.Retracting),
    gw=make_bridge_entry(df.building_bridgest.T_direction.Up),
    gd=make_bridge_entry(df.building_bridgest.T_direction.Right),
    gx=make_bridge_entry(df.building_bridgest.T_direction.Down),
    ga=make_bridge_entry(df.building_bridgest.T_direction.Left),
    l={label='Well', type=df.building_type.Well,
       is_valid_tile_fn=is_tile_empty_and_floor_adjacent},
    y={label='Glass Window', type=df.building_type.WindowGlass},
    Y={label='Gem Window', type=df.building_type.WindowGem},
    D={label='Trade Depot', type=df.building_type.TradeDepot,
       min_width=5, max_width=5, min_height=5, max_height=5},
    Msu=make_screw_pump_entry(df.screw_pump_direction.FromNorth),
    Msk=make_screw_pump_entry(df.screw_pump_direction.FromEast),
    Msm=make_screw_pump_entry(df.screw_pump_direction.FromSouth),
    Msh=make_screw_pump_entry(df.screw_pump_direction.FromWest),
    -- there is no enum for water wheel and horiz axle directions, we just have
    -- to pass a non-zero integer (but not a boolean)
    Mw=make_water_wheel_entry(true),
    Mws=make_water_wheel_entry(false),
    Mg={label='Gear Assembly', type=df.building_type.GearAssembly,
        is_valid_tile_fn=is_valid_tile_machine},
    Mh=make_horizontal_axle_entry(false),
    Mhs=make_horizontal_axle_entry(true),
    Mv={label='Vertical Axle', type=df.building_type.AxleVertical,
        is_valid_tile_fn=is_valid_tile_machine},
    Mr=make_roller_entry(df.screw_pump_direction.FromNorth, 50000),
    Mrq=make_roller_entry(df.screw_pump_direction.FromNorth, 40000),
    Mrqq=make_roller_entry(df.screw_pump_direction.FromNorth, 30000),
    Mrqqq=make_roller_entry(df.screw_pump_direction.FromNorth, 20000),
    Mrqqqq=make_roller_entry(df.screw_pump_direction.FromNorth, 10000),
    Mrs=make_roller_entry(df.screw_pump_direction.FromEast, 50000),
    Mrsq=make_roller_entry(df.screw_pump_direction.FromEast, 40000),
    Mrsqq=make_roller_entry(df.screw_pump_direction.FromEast, 30000),
    Mrsqqq=make_roller_entry(df.screw_pump_direction.FromEast, 20000),
    Mrsqqqq=make_roller_entry(df.screw_pump_direction.FromEast, 10000),
    Mrss=make_roller_entry(df.screw_pump_direction.FromSouth, 50000),
    Mrssq=make_roller_entry(df.screw_pump_direction.FromSouth, 40000),
    Mrssqq=make_roller_entry(df.screw_pump_direction.FromSouth, 30000),
    Mrssqqq=make_roller_entry(df.screw_pump_direction.FromSouth, 20000),
    Mrssqqqq=make_roller_entry(df.screw_pump_direction.FromSouth, 10000),
    Mrsss=make_roller_entry(df.screw_pump_direction.FromWest, 50000),
    Mrsssq=make_roller_entry(df.screw_pump_direction.FromWest, 40000),
    Mrsssqq=make_roller_entry(df.screw_pump_direction.FromWest, 30000),
    Mrsssqqq=make_roller_entry(df.screw_pump_direction.FromWest, 20000),
    Mrsssqqqq=make_roller_entry(df.screw_pump_direction.FromWest, 10000),
    -- Instruments are not yet supported by DFHack
    -- I={label='Instrument', type=df.building_type.Instrument},
    S={label='Support', type=df.building_type.Support,
       is_valid_tile_fn=is_valid_tile_has_space},
    m={label='Animal Trap', type=df.building_type.AnimalTrap},
    v={label='Restraint', type=df.building_type.Chain},
    j={label='Cage', type=df.building_type.Cage},
    A={label='Archery Target', type=df.building_type.ArcheryTarget},
    R={label='Traction Bench', type=df.building_type.TractionBench,
       additional_orders={'table', 'mechanisms', 'cloth rope'}},
    N={label='Nest Box', type=df.building_type.NestBox},
    ['{Alt}h']={label='Hive', type=df.building_type.Hive},
    ['{Alt}a']={label='Offering Place', type=df.building_type.OfferingPlace},
    ['{Alt}c']={label='Bookcase', type=df.building_type.Bookcase},
    F={label='Display Furniture', type=df.building_type.DisplayFurniture},

    -- basic building types with extents
    -- in the UI, these are required to be connected regions, which we could
    -- easily enforce with a flood fill check. However, requiring connected
    -- regions can make tested blueprints fail if, for example, you happen to
    -- try to put a farm plot where there is some surface rock. There is no
    -- technical issue with allowing disconnected regions, and so for player
    -- convenience we allow them.
    p={label='Farm Plot',
       type=df.building_type.FarmPlot, has_extents=true,
       no_extents_if_solid=true,
       is_valid_tile_fn=is_valid_tile_dirt,
       is_valid_extent_fn=is_extent_nonempty},
    o={label='Paved Road',
       type=df.building_type.RoadPaved, has_extents=true,
       no_extents_if_solid=true, is_valid_extent_fn=is_extent_nonempty},
    O={label='Dirt Road',
       type=df.building_type.RoadDirt, has_extents=true,
       no_extents_if_solid=true,
       is_valid_tile_fn=is_valid_tile_dirt,
       is_valid_extent_fn=is_extent_nonempty},
    -- workshops
    k={label='Kennels',
       type=df.building_type.Workshop, subtype=df.workshop_type.Kennels,
       min_width=5, max_width=5, min_height=5, max_height=5},
    we={label='Leather Works',
        type=df.building_type.Workshop, subtype=df.workshop_type.Leatherworks},
    wq={label='Quern',
        type=df.building_type.Workshop, subtype=df.workshop_type.Quern,
        min_width=1, max_width=1, min_height=1, max_height=1},
    wM={label='Millstone',
        type=df.building_type.Workshop, subtype=df.workshop_type.Millstone,
        min_width=1, max_width=1, min_height=1, max_height=1},
    wo={label='Loom',
        type=df.building_type.Workshop, subtype=df.workshop_type.Loom},
    wk={label='Clothier\'s shop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Clothiers},
    wb={label='Bowyer\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Bowyers},
    wc={label='Carpenter\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Carpenters},
    wf={label='Metalsmith\'s Forge',
        type=df.building_type.Workshop,
        subtype=df.workshop_type.MetalsmithsForge},
    wv={label='Magma Forge',
        type=df.building_type.Workshop, subtype=df.workshop_type.MagmaForge},
    wj={label='Jeweler\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Jewelers},
    wm={label='Mason\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Masons},
    wu={label='Butcher\'s Shop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Butchers},
    wn={label='Tanner\'s Shop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Tanners},
    wr={label='Craftsdwarf\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Craftsdwarfs},
    ws={label='Siege Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Siege,
        min_width=5, max_width=5, min_height=5, max_height=5},
    wt={label='Mechanic\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Mechanics},
    wl={label='Still',
        type=df.building_type.Workshop, subtype=df.workshop_type.Still},
    ww={label='Farmer\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Farmers},
    wz={label='Kitchen',
        type=df.building_type.Workshop, subtype=df.workshop_type.Kitchen},
    wh={label='Fishery',
        type=df.building_type.Workshop, subtype=df.workshop_type.Fishery},
    wy={label='Ashery',
        type=df.building_type.Workshop, subtype=df.workshop_type.Ashery},
    wd={label='Dyer\'s Shop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Dyers},
    wS={label='Soap Maker\'s Workshop',
        type=df.building_type.Workshop, subtype=df.workshop_type.Custom,
        custom=0},
    wp={label='Screw Press',
        type=df.building_type.Workshop, subtype=df.workshop_type.Custom,
        custom=1, min_width=1, max_width=1, min_height=1, max_height=1},
    -- furnaces
    ew={label='Wood Furnace',
        type=df.building_type.Furnace, subtype=df.furnace_type.WoodFurnace},
    es={label='Smelter',
        type=df.building_type.Furnace, subtype=df.furnace_type.Smelter},
    el={label='Magma Smelter',
        type=df.building_type.Furnace, subtype=df.furnace_type.MagmaSmelter},
    eg={label='Glass Furnace',
        type=df.building_type.Furnace, subtype=df.furnace_type.GlassFurnace},
    ea={label='Magma Glass Furnace', type=df.building_type.Furnace,
        subtype=df.furnace_type.MagmaGlassFurnace},
    ek={label='Kiln',
        type=df.building_type.Furnace, subtype=df.furnace_type.Kiln},
    en={label='Magma Kiln',
        type=df.building_type.Furnace, subtype=df.furnace_type.MagmaKiln},
    -- siege engines
    ib={label='Ballista', type=df.building_type.SiegeEngine,
        subtype=df.siegeengine_type.Ballista},
    ic={label='Catapult', type=df.building_type.SiegeEngine,
        subtype=df.siegeengine_type.Catapult},
    -- constructions
    Cw={label='Wall',
        type=df.building_type.Construction, subtype=df.construction_type.Wall},
    Cf={label='Floor',
        type=df.building_type.Construction, subtype=df.construction_type.Floor},
    Cr={label='Ramp',
        type=df.building_type.Construction, subtype=df.construction_type.Ramp},
    Cu={label='Up Stair',
        type=df.building_type.Construction,
        subtype=df.construction_type.UpStair},
    Cd={label='Down Stair',
        type=df.building_type.Construction,
        subtype=df.construction_type.DownStair},
    Cx={label='Up/Down Stair',
        type=df.building_type.Construction,
        subtype=df.construction_type.UpDownStair},
    CF={label='Fortification',
        type=df.building_type.Construction,
        subtype=df.construction_type.Fortification},
    -- traps
    CS=make_trackstop_entry(nil, 50000),
    CSa=make_trackstop_entry(nil, 10000),
    CSaa=make_trackstop_entry(nil, 500),
    CSaaa=make_trackstop_entry(nil, 50),
    CSaaaa=make_trackstop_entry(nil, 10),
    CSd=make_trackstop_entry({dump_y_shift=-1}, 50000),
    CSda=make_trackstop_entry({dump_y_shift=-1}, 10000),
    CSdaa=make_trackstop_entry({dump_y_shift=-1}, 500),
    CSdaaa=make_trackstop_entry({dump_y_shift=-1}, 50),
    CSdaaaa=make_trackstop_entry({dump_y_shift=-1}, 10),
    CSdd=make_trackstop_entry({dump_y_shift=1}, 50000),
    CSdda=make_trackstop_entry({dump_y_shift=1}, 10000),
    CSddaa=make_trackstop_entry({dump_y_shift=1}, 500),
    CSddaaa=make_trackstop_entry({dump_y_shift=1}, 50),
    CSddaaaa=make_trackstop_entry({dump_y_shift=1}, 10),
    CSddd=make_trackstop_entry({dump_x_shift=1}, 50000),
    CSddda=make_trackstop_entry({dump_x_shift=1}, 10000),
    CSdddaa=make_trackstop_entry({dump_x_shift=1}, 500),
    CSdddaaa=make_trackstop_entry({dump_x_shift=1}, 50),
    CSdddaaaa=make_trackstop_entry({dump_x_shift=1}, 10),
    CSdddd=make_trackstop_entry({dump_x_shift=-1}, 50000),
    CSdddda=make_trackstop_entry({dump_x_shift=-1}, 10000),
    CSddddaa=make_trackstop_entry({dump_x_shift=-1}, 500),
    CSddddaaa=make_trackstop_entry({dump_x_shift=-1}, 50),
    CSddddaaaa=make_trackstop_entry({dump_x_shift=-1}, 10),
    Ts={label='Stone-Fall Trap',
        type=df.building_type.Trap, subtype=df.trap_type.StoneFallTrap},
    -- TODO: by default a weapon trap is configured with a single weapon.
    -- maybe add Tw1 through Tw10 for choosing how many weapons?
    -- material preferences can help here for choosing weapon types.
    Tw={label='Weapon Trap',
        type=df.building_type.Trap, subtype=df.trap_type.WeaponTrap},
    Tl={label='Lever',
        type=df.building_type.Trap, subtype=df.trap_type.Lever,
        additional_orders={'mechanisms', 'mechanisms'}},
    -- TODO: lots of configuration here with no natural order. may need
    -- special-case logic when we read the keys.
    Tp={label='Pressure Plate',
        type=df.building_type.Trap, subtype=df.trap_type.PressurePlate},
    Tc={label='Cage Trap',
        type=df.building_type.Trap, subtype=df.trap_type.CageTrap,
        additional_orders={'wooden cage'}},
    -- TODO: Same as weapon trap above
    TS={label='Upright Spear/Spike', type=df.building_type.Weapon},
    -- tracks (CT...). there aren't any shortcut keys in the UI so we use the
    -- aliases from python quickfort
    trackN=make_track_entry('N', track_end_data, track_end_revmap, false),
    trackS=make_track_entry('S', track_end_data, track_end_revmap, false),
    trackE=make_track_entry('E', track_end_data, track_end_revmap, false),
    trackW=make_track_entry('W', track_end_data, track_end_revmap, false),
    trackNS=make_track_entry('NS', track_through_data, track_through_revmap,
                             false),
    trackEW=make_track_entry('EW', track_through_data, track_through_revmap,
                             false),
    trackNE=make_track_entry('NE', track_corner_data, track_corner_revmap,
                             false),
    trackNW=make_track_entry('NW', track_corner_data, track_corner_revmap,
                             false),
    trackSE=make_track_entry('SE', track_corner_data, track_corner_revmap,
                             false),
    trackSW=make_track_entry('SW', track_corner_data, track_corner_revmap,
                             false),
    trackNSE=make_track_entry('NSE', track_tee_data, track_tee_revmap, false),
    trackNSW=make_track_entry('NSW', track_tee_data, track_tee_revmap, false),
    trackNEW=make_track_entry('NEW', track_tee_data, track_tee_revmap, false),
    trackSEW=make_track_entry('SEW', track_tee_data, track_tee_revmap, false),
    trackNSEW=make_track_entry('NSEW', nil, nil, false),
    trackrampN=make_track_entry('N', track_end_data, track_end_revmap, true),
    trackrampS=make_track_entry('S', track_end_data, track_end_revmap, true),
    trackrampE=make_track_entry('E', track_end_data, track_end_revmap, true),
    trackrampW=make_track_entry('W', track_end_data, track_end_revmap, true),
    trackrampNS=make_track_entry('NS', track_through_data, track_through_revmap,
                                 true),
    trackrampEW=make_track_entry('EW', track_through_data, track_through_revmap,
                                 true),
    trackrampNE=make_track_entry('NE', track_corner_data, track_corner_revmap,
                                 true),
    trackrampNW=make_track_entry('NW', track_corner_data, track_corner_revmap,
                                 true),
    trackrampSE=make_track_entry('SE', track_corner_data, track_corner_revmap,
                                 true),
    trackrampSW=make_track_entry('SW', track_corner_data, track_corner_revmap,
                                 true),
    trackrampNSE=make_track_entry('NSE', track_tee_data, track_tee_revmap,
                                  true),
    trackrampNSW=make_track_entry('NSW', track_tee_data, track_tee_revmap,
                                  true),
    trackrampNEW=make_track_entry('NEW', track_tee_data, track_tee_revmap,
                                  true),
    trackrampSEW=make_track_entry('SEW', track_tee_data, track_tee_revmap,
                                  true),
    trackrampNSEW=make_track_entry('NSEW', nil, nil, true)
}

-- fill in default values if they're not already specified
for _, v in pairs(building_db) do
    if v.has_extents then
        if not v.min_width then
            v.min_width, v.max_width, v.min_height, v.max_height = 1, 10, 1, 10
        end
    elseif v.type == df.building_type.Workshop or
            v.type == df.building_type.Furnace or
            v.type == df.building_type.SiegeEngine then
        if not v.min_width then
            v.min_width, v.max_width, v.min_height, v.max_height = 3, 3, 3, 3
        end
    elseif not v.min_width then
        v.min_width, v.max_width, v.min_height, v.max_height = 1, 1, 1, 1
    end
    if not v.is_valid_tile_fn then
        if v.type == df.building_type.Construction then
            v.is_valid_tile_fn = is_valid_tile_construction
        else
            v.is_valid_tile_fn = is_valid_tile_generic
        end
    end
    if not v.is_valid_extent_fn then
        v.is_valid_extent_fn = is_extent_solid
    end
end

-- case sensitive aliases
building_db.g = building_db.gs
building_db.Ms = building_db.Msu

-- case insensitive aliases for keys in the db
-- this allows us to keep compatibility with the old python quickfort and makes
-- us a little more forgiving for some of the trickier keys in the db.
local building_aliases = {
    rollerh='Mrs',
    rollerv='Mr',
    rollerns='Mr',
    rollersn='Mrss',
    rollerew='Mrs',
    rollerwe='Mrsss',
    rollerhq='Mrsq',
    rollervq='Mrq',
    rollernsq='Mrq',
    rollersnq='Mrssq',
    rollerewq='Mrsq',
    rollerweq='Mrsssq',
    rollerhqq='Mrsqq',
    rollervqq='Mrqq',
    rollernsqq='Mrqq',
    rollersnqq='Mrssqq',
    rollerewqq='Mrsqq',
    rollerweqq='Mrsssqq',
    rollerhqqq='Mrsqqq',
    rollervqqq='Mrqqq',
    rollernsqqq='Mrqqq',
    rollersnqqq='Mrssqqq',
    rollerewqqq='Mrsqqq',
    rollerweqqq='Mrsssqqq',
    rollerhqqqq='Mrsqqqq',
    rollervqqqq='Mrqqqq',
    rollernsqqqq='Mrqqqq',
    rollersnqqqq='Mrssqqqq',
    rollerewqqqq='Mrsqqqq',
    rollerweqqqq='Mrsssqqqq',
    trackstop='CS',
    trackstopn='CSd',
    trackstops='CSdd',
    trackstope='CSddd',
    trackstopw='CSdddd',
    trackstopa='CSa',
    trackstopna='CSda',
    trackstopsa='CSdda',
    trackstopea='CSddda',
    trackstopwa='CSdddda',
    trackstopaa='CSaa',
    trackstopnaa='CSdaa',
    trackstopsaa='CSddaa',
    trackstopeaa='CSdddaa',
    trackstopwaa='CSddddaa',
    trackstopaaa='CSaaa',
    trackstopnaaa='CSdaaa',
    trackstopsaaa='CSddaaa',
    trackstopeaaa='CSdddaaa',
    trackstopwaaa='CSddddaaa',
    trackstopaaaa='CSaaaa',
    trackstopnaaaa='CSdaaaa',
    trackstopsaaaa='CSddaaaa',
    trackstopeaaaa='CSdddaaaa',
    trackstopwaaaa='CSddddaaaa',
    trackn='trackN',
    tracks='trackS',
    tracke='trackE',
    trackw='trackW',
    trackns='trackNS',
    trackne='trackNE',
    tracknw='trackNW',
    trackse='trackSE',
    tracksw='trackSW',
    trackew='trackEW',
    tracknse='trackNSE',
    tracknsw='trackNSW',
    tracknew='trackNEW',
    tracksew='trackSEW',
    tracknsew='trackNSEW',
    trackrampn='trackrampN',
    trackramps='trackrampS',
    trackrampe='trackrampE',
    trackrampw='trackrampW',
    trackrampns='trackrampNS',
    trackrampne='trackrampNE',
    trackrampnw='trackrampNW',
    trackrampse='trackrampSE',
    trackrampsw='trackrampSW',
    trackrampew='trackrampEW',
    trackrampnse='trackrampNSE',
    trackrampnsw='trackrampNSW',
    trackrampnew='trackrampNEW',
    trackrampsew='trackrampSEW',
    trackrampnsew='trackrampNSEW',
    ['~h']='{Alt}h',
    ['~a']='{Alt}a',
    ['~c']='{Alt}c',
    ['~b']='{Alt}b',
    ['~s']='{Alt}s',
}

--
-- ************ command logic functions ************ --
--

local function create_building(b, dry_run)
    local db_entry = building_db[b.type]
    log('creating %dx%d %s at map coordinates (%d, %d, %d), defined from ' ..
        'spreadsheet cells: %s',
        b.width, b.height, db_entry.label, b.pos.x, b.pos.y, b.pos.z,
        table.concat(b.cells, ', '))
    if dry_run then return end
    local fields = {}
    if db_entry.fields then fields = copyall(db_entry.fields) end
    local use_extents = db_entry.has_extents and
            not (db_entry.no_extents_if_solid and is_extent_solid(b))
    if use_extents then
        fields.room = {x=b.pos.x, y=b.pos.y, width=b.width, height=b.height,
                       extents=quickfort_building.make_extents(b, false)}
    end
    local bld, err = dfhack.buildings.constructBuilding{
        type=db_entry.type, subtype=db_entry.subtype, custom=db_entry.custom,
        pos=b.pos, width=b.width, height=b.height, direction=db_entry.direction,
        fields=fields}
    if not bld then
        -- this is an error instead of a qerror since our validity checking
        -- is supposed to prevent this from ever happening
        error(string.format('unable to place %s: %s', db_entry.label, err))
    end
    if buildingplan.isEnabled() and buildingplan.isPlannableBuilding(
            db_entry.type, db_entry.subtype or -1, db_entry.custom or -1) then
        log('registering %s with buildingplan', db_entry.label)
        buildingplan.addPlannedBuilding(bld)
    end
end

local warning_shown = false

function do_run(zlevel, grid, ctx)
    local stats = ctx.stats
    stats.build_designated = stats.build_designated or
            {label='Buildings designated', value=0, always=true}
    stats.build_unsuitable = stats.build_unsuitable or
            {label='Unsuitable tiles for building', value=0}

    if not warning_shown and not buildingplan.isEnabled() then
        dfhack.printerr('the buildingplan plugin is not enabled. buildings '
                        ..'placed with #build blueprints will disappear if you '
                        ..'do not have required building materials in stock.')
        warning_shown = true
    end

    local buildings = {}
    stats.invalid_keys.value =
            stats.invalid_keys.value + quickfort_building.init_buildings(
                ctx, zlevel, grid, buildings, building_db, building_aliases)
    stats.out_of_bounds.value =
            stats.out_of_bounds.value + quickfort_building.crop_to_bounds(
                ctx, buildings, building_db)
    stats.build_unsuitable.value =
            stats.build_unsuitable.value +
            quickfort_building.check_tiles_and_extents(
                ctx, buildings, building_db)

    for _, b in ipairs(buildings) do
        if b.pos then
            create_building(b, ctx.dry_run)
            stats.build_designated.value = stats.build_designated.value + 1
        end
    end
    if not ctx.dry_run then
        buildingplan.scheduleCycle()
    end
end

function do_orders(zlevel, grid, ctx)
    local stats = ctx.stats
    local buildings = {}
    stats.invalid_keys.value =
            stats.invalid_keys.value + quickfort_building.init_buildings(
                ctx, zlevel, grid, buildings, building_db, building_aliases)
    quickfort_orders.enqueue_building_orders(buildings, building_db, ctx)
end

local function is_queued_for_destruction(bld)
    for k,v in ipairs(bld.jobs) do
        if v.job_type == df.job_type.DestroyBuilding then
            return true
        end
    end
    return false
end

function do_undo(zlevel, grid, ctx)
    local stats = ctx.stats
    stats.build_undesignated = stats.build_undesignated or
            {label='Buildings undesignated', value=0, always=true}
    stats.build_marked = stats.build_marked or
            {label='Buildings marked for removal', value=0}

    local buildings = {}
    stats.invalid_keys.value =
            stats.invalid_keys.value + quickfort_building.init_buildings(
                ctx, zlevel, grid, buildings, building_db, building_aliases)

    for _, s in ipairs(buildings) do
        for extent_x, col in ipairs(s.extent_grid) do
            for extent_y, in_extent in ipairs(col) do
                if not s.extent_grid[extent_x][extent_y] then goto continue end
                local pos =
                        xyz2pos(s.pos.x+extent_x-1, s.pos.y+extent_y-1, s.pos.z)
                local bld = dfhack.buildings.findAtTile(pos)
                if bld and bld:getType() ~= df.building_type.Stockpile and
                        not is_queued_for_destruction(bld) then
                    if ctx.dry_run then
                        if bld:getBuildStage() == 0 then
                            stats.build_undesignated.value =
                                    stats.build_undesignated.value + 1
                        else
                            stats.build_marked.value =
                                    stats.build_marked.value + 1
                        end
                    elseif dfhack.buildings.deconstruct(bld) then
                        stats.build_undesignated.value =
                                stats.build_undesignated.value + 1
                    else
                        stats.build_marked.value = stats.build_marked.value + 1
                    end
                end
                ::continue::
            end
        end
    end
end
