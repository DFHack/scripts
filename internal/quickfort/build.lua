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
local quickfort_common = reqscript('internal/quickfort/common')
local quickfort_building = reqscript('internal/quickfort/building')
local log = quickfort_common.log

--
-- ************ tile validity checking functions ************ --
--

local function is_valid_tile_base(pos)
    local flags, occupancy = dfhack.maps.getTileFlags(pos)
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

local function is_valid_tile_construction(pos)
    local material = df.tiletype.attrs[dfhack.maps.getTileType(pos)].material
    return is_valid_tile_has_space(pos) and
            material ~= df.tiletype_material.CONSTRUCTION
end

local function is_shape_at(pos, allowed_shapes)
    if not quickfort_common.is_within_map_bounds(pos) and
            not quickfort_common.is_on_map_edge(pos) then return false end
    return allowed_shapes[df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape]
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

-- for wells
local function is_tile_empty_and_floor_adjacent(pos)
    if not is_valid_tile_base(pos) or
            df.tiletype.attrs[dfhack.maps.getTileType(pos)].shape ~=
            df.tiletype_shape.EMPTY then
        return false
    end
    return is_valid_tile_generic(xyz2pos(pos.x+1, pos.y, pos.z)) or
            is_valid_tile_generic(xyz2pos(pos.x-1, pos.y, pos.z)) or
            is_valid_tile_generic(xyz2pos(pos.x, pos.y+1, pos.z)) or
            is_valid_tile_generic(xyz2pos(pos.x, pos.y-1, pos.z))
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
-- ************ post construction fixup functions ************ --
--

local function post_construction_init_workshop(bld)
    bld.profile.max_general_orders = 5
end

local function post_construction_open_gate(bld)
    bld.gate_flags.closed = false
end

--
-- ************ the database ************ --
--

local roller_data = {
    [df.screw_pump_direction.FromNorth]={label='Rollers (N->S)', vertical=true},
    [df.screw_pump_direction.FromEast]={label='Rollers (E->W)'},
    [df.screw_pump_direction.FromSouth]={label='Rollers (S->N)', vertical=true},
    [df.screw_pump_direction.FromWest]={label='Rollers (W->E)'}
}
local function make_roller_entry(direction, speed)
    return {
        label=roller_data[direction].label,
        type=df.building_type.Rollers,
        min_width=1,
        max_width=not roller_data[direction].vertical and 10 or 1,
        min_height=1,
        max_height=roller_data[direction].vertical and 10 or 1,
        direction=direction,
        fields={speed=speed},
        is_valid_tile_fn=is_valid_tile_has_space
    }
end

local trackstop_data = {
    dump_y_shift={[-1]='Track Stop (Dump North)',
                  [1]='Track Stop (Dump South)'},
    dump_x_shift={[-1]='Track Stop (Dump West)',
                  [1]='Track Stop (Dump East)'}
}
local function make_trackstop_entry(direction, friction)
    local label, fields = nil, {friction=friction}
    if not direction then
        label = 'Track Stop (No Dump)'
    else
        fields.use_dump = 1
        for k,v in pairs(direction) do
            label = trackstop_data[k][v]
            fields[k] = v
        end
    end
    return {
        label=label,
        type=df.building_type.Trap,
        subtype=df.trap_type.TrackStop,
        fields=fields
    }
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
    H={label='Floor Hatch', type=df.building_type.Hatch},
    W={label='Wall Grate', type=df.building_type.GrateWall},
    G={label='Floor Grate', type=df.building_type.GrateFloor},
    B={label='Vertical Bars', type=df.building_type.BarsVertical},
    ['{Alt}b']={label='Floor Bars', type=df.building_type.BarsFloor},
    f={label='Cabinet', type=df.building_type.Cabinet},
    h={label='Container', type=df.building_type.Box},
    r={label='Weapon Rack', type=df.building_type.Weaponrack},
    s={label='Statue', type=df.building_type.Statue},
    ['{Alt}s']={label='Slab', type=df.building_type.Slab},
    t={label='Table', type=df.building_type.Table},
    g={label='Bridge (Retracting)', type=df.building_type.Bridge,
       direction=df.building_bridgest.T_direction.Retracting},
    gs={label='Bridge (Retracting)', type=df.building_type.Bridge,
       direction=df.building_bridgest.T_direction.Retracting},
    ga={label='Bridge (Raises to West)', type=df.building_type.Bridge,
       direction=df.building_bridgest.T_direction.Left},
    gd={label='Bridge (Raises to East)', type=df.building_type.Bridge,
       direction=df.building_bridgest.T_direction.Right},
    gw={label='Bridge (Raises to North)', type=df.building_type.Bridge,
       direction=df.building_bridgest.T_direction.Up},
    gx={label='Bridge (Raises to South)', type=df.building_type.Bridge,
       direction=df.building_bridgest.T_direction.Down},
    l={label='Well', type=df.building_type.Well,
       is_valid_tile_fn=is_tile_empty_and_floor_adjacent},
    y={label='Glass Window', type=df.building_type.WindowGlass},
    Y={label='Gem Window', type=df.building_type.WindowGem},
    D={label='Trade Depot', type=df.building_type.TradeDepot,
       min_width=5, max_width=5, min_height=5, max_height=5},
    Ms={label='Screw Pump (Pump From North)', type=df.building_type.ScrewPump,
        min_width=1, max_width=1, min_height=2, max_height=2,
        direction=df.screw_pump_direction.FromNorth,
        is_valid_tile_fn=is_valid_tile_has_space},
    Msu={label='Screw Pump (Pump From North)', type=df.building_type.ScrewPump,
         min_width=1, max_width=1, min_height=2, max_height=2,
         direction=df.screw_pump_direction.FromNorth,
         is_valid_tile_fn=is_valid_tile_has_space},
    Msk={label='Screw Pump (Pump From East)', type=df.building_type.ScrewPump,
         min_width=2, max_width=2, min_height=1, max_height=1,
         direction=df.screw_pump_direction.FromEast,
         is_valid_tile_fn=is_valid_tile_has_space},
    Msm={label='Screw Pump (Pump From South)', type=df.building_type.ScrewPump,
         min_width=1, max_width=1, min_height=2, max_height=2,
         direction=df.screw_pump_direction.FromSouth,
         is_valid_tile_fn=is_valid_tile_has_space},
    Msh={label='Screw Pump (Pump From West)', type=df.building_type.ScrewPump,
         min_width=2, max_width=2, min_height=1, max_height=1,
         direction=df.screw_pump_direction.FromWest,
         is_valid_tile_fn=is_valid_tile_has_space},
    -- there is no enum for water wheel and horiz axle directions, we just have
    -- to pass a non-zero integer (but not a boolean)
    Mw={label='Water Wheel (N/S)', type=df.building_type.WaterWheel,
        min_width=1, max_width=1, min_height=3, max_height=3, direction=1,
        is_valid_tile_fn=is_valid_tile_has_space},
    Mws={label='Water Wheel (E/W)', type=df.building_type.WaterWheel,
         min_width=3, max_width=3, min_height=1, max_height=1,
         is_valid_tile_fn=is_valid_tile_has_space},
    Mg={label='Gear Assembly', type=df.building_type.GearAssembly,
        is_valid_tile_fn=is_valid_tile_has_space},
    Mh={label='Horizontal Axle (E/W)', type=df.building_type.AxleHorizontal,
        min_width=1, max_width=10, min_height=1, max_height=1,
        is_valid_tile_fn=is_valid_tile_has_space},
    Mhs={label='Horizontal Axle (N/S)', type=df.building_type.AxleHorizontal,
         min_width=1, max_width=1, min_height=1, max_height=10, direction=1,
         is_valid_tile_fn=is_valid_tile_has_space},
    Mv={label='Vertical Axle', type=df.building_type.AxleVertical,
        is_valid_tile_fn=is_valid_tile_has_space},
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
    --I={label='Instrument', type=df.building_type.Instrument},
    S={label='Support', type=df.building_type.Support,
       is_valid_tile_fn=is_valid_tile_has_space},
    m={label='Animal Trap', type=df.building_type.AnimalTrap},
    v={label='Restraint', type=df.building_type.Chain},
    j={label='Cage', type=df.building_type.Cage},
    A={label='Archery Target', type=df.building_type.ArcheryTarget},
    R={label='Traction Bench', type=df.building_type.TractionBench},
    N={label='Nest Box', type=df.building_type.NestBox},
    ['{Alt}h']={label='Hive', type=df.building_type.Hive},
    -- Offering Places, Bookcases, and Display Furniture are not yet supported
    -- by dfhack
    --['{Alt}a']={label='Offering Place', type=df.building_type.OfferingPlace},
    --['{Alt}c']={label='Bookcase', type=df.building_type.Bookcase},
    --F={label='Display Furniture', type=df.building_type.DisplayFurniture},

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
        type=df.building_type.Trap, subtype=df.trap_type.Lever},
    -- TODO: lots of configuration here with no natural order. may need
    -- special-case logic when we read the keys.
    Tp={label='Pressure Plate',
        type=df.building_type.Trap, subtype=df.trap_type.PressurePlate},
    Tc={label='Cage Trap',
        type=df.building_type.Trap, subtype=df.trap_type.CageTrap},
    -- TODO: Same as weapon trap above
    TS={label='Upright Spear/Spike',
        type=df.building_type.Weapon, subtype=df.trap_type.StoneFallTrap},
    -- tracks (CT...). there aren't any shortcut keys in the UI so we use the
    -- aliases from python quickfort
    trackN={label='Track (N)',
            type=df.building_type.Construction,
            subtype=df.construction_type.TrackN},
    trackS={label='Track (S)',
            type=df.building_type.Construction,
            subtype=df.construction_type.TrackS},
    trackE={label='Track (E)',
            type=df.building_type.Construction,
            subtype=df.construction_type.TrackE},
    trackW={label='Track (W)',
            type=df.building_type.Construction,
            subtype=df.construction_type.TrackW},
    trackNS={label='Track (NS)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackNS},
    trackNE={label='Track (NE)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackNE},
    trackNW={label='Track (NW)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackNW},
    trackSE={label='Track (SE)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackSE},
    trackSW={label='Track (SW)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackSW},
    trackEW={label='Track (EW)',
             type=df.building_type.Construction,
             subtype=df.construction_type.TrackEW},
    trackNSE={label='Track (NSE)',
              type=df.building_type.Construction,
              subtype=df.construction_type.TrackNSE},
    trackNSW={label='Track (NSW)',
              type=df.building_type.Construction,
              subtype=df.construction_type.TrackNSW},
    trackNEW={label='Track (NEW)',
              type=df.building_type.Construction,
              subtype=df.construction_type.TrackNEW},
    trackSEW={label='Track (SEW)',
              type=df.building_type.Construction,
              subtype=df.construction_type.TrackSEW},
    trackNSEW={label='Track (NSEW)',
               type=df.building_type.Construction,
               subtype=df.construction_type.TrackNSEW},
    trackrampN={label='Track/Ramp (N)',
                type=df.building_type.Construction,
                subtype=df.construction_type.TrackRampN},
    trackrampS={label='Track/Ramp (S)',
                type=df.building_type.Construction,
                subtype=df.construction_type.TrackRampS},
    trackrampE={label='Track/Ramp (E)',
                type=df.building_type.Construction,
                subtype=df.construction_type.TrackRampE},
    trackrampW={label='Track/Ramp (W)',
                type=df.building_type.Construction,
                subtype=df.construction_type.TrackRampW},
    trackrampNS={label='Track/Ramp (NS)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampNS},
    trackrampNE={label='Track/Ramp (NE)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampNE},
    trackrampNW={label='Track/Ramp (NW)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampNW},
    trackrampSE={label='Track/Ramp (SE)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampSE},
    trackrampSW={label='Track/Ramp (SW)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampSW},
    trackrampEW={label='Track/Ramp (EW)',
                 type=df.building_type.Construction,
                 subtype=df.construction_type.TrackRampEW},
    trackrampNSE={label='Track/Ramp (NSE)',
                  type=df.building_type.Construction,
                  subtype=df.construction_type.TrackRampNSE},
    trackrampNSW={label='Track/Ramp (NSW)',
                  type=df.building_type.Construction,
                  subtype=df.construction_type.TrackRampNSW},
    trackrampNEW={label='Track/Ramp (NEW)',
                  type=df.building_type.Construction,
                  subtype=df.construction_type.TrackRampNEW},
    trackrampSEW={label='Track/Ramp (SEW)',
                  type=df.building_type.Construction,
                  subtype=df.construction_type.TrackRampSEW},
    trackrampNSEW={label='Track/Ramp (NSEW)',
                   type=df.building_type.Construction,
                   subtype=df.construction_type.TrackRampNSEW},
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
    else
        if not v.min_width then
            v.min_width, v.max_width, v.min_height, v.max_height = 1, 1, 1, 1
        end
    end
    if v.type == df.building_type.Workshop then
        v.post_construction_fn = post_construction_init_workshop
    end
    if v.type == df.building_type.Bridge then
       v.min_width, v.max_width, v.min_height, v.max_height = 1, 10, 1, 10
       v.is_valid_tile_fn = is_valid_tile_has_space
       v.post_construction_fn = post_construction_open_gate
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

local function create_building(b)
    db_entry = building_db[b.type]
    log('creating %dx%d %s at map coordinates (%d, %d, %d), defined from ' ..
        'spreadsheet cells: %s',
        b.width, b.height, db_entry.label, b.pos.x, b.pos.y, b.pos.z,
        table.concat(b.cells, ', '))
    local extents, room = nil, nil
    local fields = {}
    if db_entry.fields then fields = copyall(db_entry.fields) end
    local use_extents = db_entry.has_extents and
            not (db_entry.no_extents_if_solid and is_extent_solid(b))
    if use_extents then
        fields.room = {x=b.pos.x, y=b.pos.y, width=b.width, height=b.height}
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
    -- constructBuilding deallocates extents, so we have to assign it after
    if use_extents then
        bld.room.extents = quickfort_building.make_extents(b, building_db)
    end
    if db_entry.post_construction_fn then db_entry.post_construction_fn(bld) end
end

function do_run(zlevel, grid)
    local stats = {
        designated={label='Buildings designated', value=0, always=true},
        unsuitable={label='Unsuitable tiles', value=0},
        out_of_bounds={label='Tiles outside map boundary', value=0},
        invalid_keys={label='Invalid key sequences', value=0},
    }

    local buildings = {}
    stats.invalid_keys.value = quickfort_building.init_buildings(
        zlevel, grid, buildings, building_db, building_aliases)
    stats.out_of_bounds.value = quickfort_building.crop_to_bounds(
        buildings, building_db)
    stats.unsuitable.value = quickfort_building.check_tiles_and_extents(
        buildings, building_db)

    for _, b in ipairs(buildings) do
        if b.pos then
            create_building(b)
            stats.designated.value = stats.designated.value + 1
        end
    end
    dfhack.job.checkBuildingsNow()
    return stats
end

function do_orders(zlevel, grid)
    local stats = nil
    print('"quickfort orders" not yet implemented for mode: build')
    return stats
end

local function is_queued_for_destruction(bld)
    for k,v in ipairs(bld.jobs) do
        if v.job_type == df.job_type.DestroyBuilding then
            return true
        end
    end
    return false
end

function do_undo(zlevel, grid)
    local stats = {
        removed={label='Buildings removed', value=0, always=true},
        marked={label='Buildings marked for removal', value=0},
        invalid_keys={label='Invalid key sequences', value=0},
    }

    local buildings = {}
    stats.invalid_keys.value = quickfort_building.init_buildings(
        zlevel, grid, buildings, building_db, building_aliases)

    for _, s in ipairs(buildings) do
        for extent_x, col in ipairs(s.extent_grid) do
            for extent_y, in_extent in ipairs(col) do
                if not s.extent_grid[extent_x][extent_y] then goto continue end
                local pos =
                        xyz2pos(s.pos.x+extent_x-1, s.pos.y+extent_y-1, s.pos.z)
                local bld = dfhack.buildings.findAtTile(pos)
                if bld and bld:getType() ~= df.building_type.Stockpile and
                        not is_queued_for_destruction(bld) then
                    if dfhack.buildings.deconstruct(bld) then
                        stats.removed.value = stats.removed.value + 1
                    else
                        stats.marked.value = stats.marked.value + 1
                    end
                end
                ::continue::
            end
        end
    end
    return stats
end
