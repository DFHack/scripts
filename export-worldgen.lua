-- Export the world generation parameters of the loaded world to world_gen.txt
--@ module = true

local argparse = require('argparse')

-- the six worldgen fields that have both a range token and a frequency token,
-- in the order DF writes them
local RANGE_FIELDS = {
    {token='ELEVATION',   enum=df.worldgen_range_type.ELEVATION},
    {token='RAINFALL',    enum=df.worldgen_range_type.RAINFALL},
    {token='TEMPERATURE', enum=df.worldgen_range_type.TEMPERATURE},
    {token='DRAINAGE',    enum=df.worldgen_range_type.DRAINAGE},
    {token='VOLCANISM',   enum=df.worldgen_range_type.VOLCANISM},
    {token='SAVAGERY',    enum=df.worldgen_range_type.SAVAGERY},
}

local FREQ_FIELDS = {
    {'ELEVATION_FREQUENCY',   'elevation_frequency'},
    {'RAIN_FREQUENCY',        'rain_frequency'},
    {'DRAINAGE_FREQUENCY',    'drainage_frequency'},
    {'TEMPERATURE_FREQUENCY', 'temperature_frequency'},
    {'SAVAGERY_FREQUENCY',    'savagery_frequency'},
    {'VOLCANISM_FREQUENCY',   'volcanism_frequency'},
}

-- world_region_type values that DF writes REGION_COUNTS lines for, in order;
-- Lake is notably absent
local REGION_COUNT_TYPES = {
    {df.world_region_type.Swamp,     'SWAMP'},
    {df.world_region_type.Desert,    'DESERT'},
    {df.world_region_type.Forest,    'FOREST'},
    {df.world_region_type.Mountains, 'MOUNTAINS'},
    {df.world_region_type.Ocean,     'OCEAN'},
    {df.world_region_type.Glacier,   'GLACIER'},
    {df.world_region_type.Tundra,    'TUNDRA'},
    {df.world_region_type.Grassland, 'GRASSLAND'},
    {df.world_region_type.Hills,     'HILLS'},
}

-- POLE file strings by parms.pole option index
local POLE_OPTIONS = {
    'NONE',
    'NORTH_OR_SOUTH',
    'NORTH_AND_OR_SOUTH',
    'NORTH',
    'SOUTH',
    'NORTH_AND_SOUTH',
}

-- resolved pole (world_data.flip_latitude, df.pole_type) to POLE token string
local POLE_RESOLVED = {
    [df.pole_type.None]  = 'NONE',
    [df.pole_type.North] = 'NORTH',
    [df.pole_type.South] = 'SOUTH',
    [df.pole_type.Both]  = 'NORTH_AND_SOUTH',
}

-- REAL_WORLD_EXTINCT file strings by parms.real_world_extinct option index
local EXTINCT_OPTIONS = {
    'EXTINCT',
    'ISOLATED',
    'UNTAMED_WILDS',
    'WILDERNESS',
    'DOMESTICATED',
}

-- PS_* tokens and the data they serialize
local PS_FIELDS = {
    {token='PS_EL', enum=df.worldgen_range_type.ELEVATION,   map_field='elevation'},
    {token='PS_RF', enum=df.worldgen_range_type.RAINFALL,    map_field='rainfall'},
    {token='PS_TP', enum=df.worldgen_range_type.TEMPERATURE, map_field='temperature'},
    {token='PS_DR', enum=df.worldgen_range_type.DRAINAGE,    map_field='drainage'},
    {token='PS_VL', enum=df.worldgen_range_type.VOLCANISM,   map_field='volcanism'},
    {token='PS_SV', enum=df.worldgen_range_type.SAVAGERY,    map_field='savagery'},
}

local function sanitize(text)
    -- [ ] and : are structural characters in world_gen.txt
    return (tostring(text):gsub('[%[%]:]', ''))
end

-- convert a region_map elevation to the world painter scale.
-- region_map: 0-99 ocean, 100-149 land, 150+ mountains (down from 300+),
-- peaks flagged separately.
-- painter:    1-99 water, 100-299 land, 300-399 mountains, 400 peak
local function elevation_to_painter(elevation, is_peak)
    if is_peak then return 400 end
    if elevation < 100 then return elevation end
    if elevation < 150 then return 100 + 4 * (elevation - 100) end
    return math.min(399, elevation + 150)
end

local function tile_to_painter(tile, map_field)
    -- region_map fields are stored in the same scale as the worldgen
    -- parameters and the painter PS_* data: rainfall/drainage/volcanism/
    -- savagery are 0-100 and temperature is the worldgen temperature scale
    -- (region temp * 3/4 + 10000 = degrees Urist), so only elevation needs
    -- conversion
    if map_field == 'elevation' then
        return elevation_to_painter(tile.elevation, tile.flags.is_peak)
    end
    return tile[map_field]
end

local function pole_token(parms)
    -- emit the pole the world was actually generated with (world_data's
    -- flip_latitude holds the resolved pole even when the parameter set used
    -- one of the random options like NORTH_OR_SOUTH)
    local resolved = POLE_RESOLVED[df.global.world.world_data.flip_latitude]
    if resolved then
        return resolved
    end
    return POLE_OPTIONS[parms.pole + 1] or 'NONE'
end

local function extinct_token(parms)
    local option = EXTINCT_OPTIONS[parms.real_world_extinct + 1]
    if not option then
        dfhack.printerr(('unexpected real_world_extinct value %d; emitting EXTINCT')
            :format(parms.real_world_extinct))
        return 'EXTINCT'
    end
    return option
end

-- emit the PS_* rows for one field from the original world painter preset data
local function emit_ps_field_from_preset(lines, spec, ps)
    local columns = ps.data[spec.enum]
    if columns == nil then
        return false
    end
    local ok, err = pcall(function()
        for y = 0, ps.height - 1 do
            local values = {}
            for x = 0, ps.width - 1 do
                values[#values + 1] =
                    tostring(columns:_displace(x).value:_displace(y).value)
            end
            table.insert(lines, '[' .. spec.token .. ':' .. table.concat(values, ':') .. ']')
        end
    end)
    if not ok then
        dfhack.printerr(('warning: could not read preset data for %s (%s); ' ..
            'reconstructing from world map instead'):format(spec.token, err))
    end
    return ok
end

-- emit the PS_* rows for one field reconstructed from the generated world map
local function emit_ps_field_from_map(lines, spec)
    local wdata = df.global.world.world_data
    for y = 0, wdata.world_height - 1 do
        local values = {}
        for x = 0, wdata.world_width - 1 do
            local tile = wdata.region_map[x]:_displace(y)
            values[#values + 1] = tostring(tile_to_painter(tile, spec.map_field))
        end
        table.insert(lines, '[' .. spec.token .. ':' .. table.concat(values, ':') .. ']')
    end
end

-- emit PS_* rows for all six fields. Where the world was generated with a
-- world painter preset (parms.ps), its data is on the painter scale already
-- and is emitted verbatim; fields that were left unpainted in the preset
-- (null) are reconstructed from the generated map, as are all fields when the
-- world had no preset
local function emit_ps(lines)
    local parms = df.global.world.worldgen.worldgen_parms
    local wdata = df.global.world.world_data
    local ps = parms.ps
    if ps ~= nil and
        (ps.width ~= wdata.world_width or ps.height ~= wdata.world_height)
    then
        dfhack.printerr('warning: preset dimensions do not match the world ' ..
            'dimensions; reconstructing all fields from the world map')
        ps = nil
    end
    for _, spec in ipairs(PS_FIELDS) do
        if not ps or not emit_ps_field_from_preset(lines, spec, ps) then
            emit_ps_field_from_map(lines, spec)
        end
    end
end

local function build_stanza(options)
    local parms = df.global.world.worldgen.worldgen_parms
    local lines = {}
    local function emit(line, ...)
        table.insert(lines, (#({...}) > 0) and line:format(...) or line)
    end
    -- with --relax, zero out the minimums DF rejects worlds for and the
    -- post-processing that would alter painted map data
    local function relaxed(value)
        return options.relax and 0 or value
    end

    emit('[WORLD_GEN]')
    emit('[TITLE:%s]', options.title)
    if options.keep_name and #parms.custom_name > 0 then
        emit('[CUSTOM_NAME:%s]', sanitize(parms.custom_name))
    end
    if options.seed and #parms.seed > 0 then
        emit('[SEED:%s]', parms.seed)
    end
    if options.history_seed and #parms.history_seed > 0 then
        emit('[HISTORY_SEED:%s]', parms.history_seed)
    end
    if options.name_seed and #parms.name_seed > 0 then
        emit('[NAME_SEED:%s]', parms.name_seed)
    end
    if options.creature_seed and #parms.creature_seed > 0 then
        emit('[CREATURE_SEED:%s]', parms.creature_seed)
    end
    emit('[DIM:%d:%d]', parms.dim_x, parms.dim_y)
    emit('[EMBARK_POINTS:%d]', parms.embark_points)
    emit('[END_YEAR:%d]', parms.end_year)
    emit('[BEAST_END_YEAR:%d:%d]', parms.beast_end_year, parms.beast_end_year_percent)
    emit('[REVEAL_ALL_HISTORY:%d]', parms.reveal_all_history)
    emit('[CULL_HISTORICAL_FIGURES:%d]', parms.cull_historical_figures)

    -- ranges: min, max, x variance, y variance
    for _, spec in ipairs(RANGE_FIELDS) do
        emit('[%s:%d:%d:%d:%d]', spec.token,
            parms.ranges[0][spec.enum], parms.ranges[1][spec.enum],
            parms.ranges[2][spec.enum], parms.ranges[3][spec.enum])
    end
    for _, spec in ipairs(FREQ_FIELDS) do
        local freq = parms[spec[2]]
        emit('[%s:%d:%d:%d:%d:%d:%d]', spec[1],
            freq[0], freq[1], freq[2], freq[3], freq[4], freq[5])
    end

    emit('[POLE:%s]', pole_token(parms))
    emit('[MINERAL_SCARCITY:%d]', parms.mineral_scarcity)
    emit('[REAL_WORLD_EXTINCT:%s]', extinct_token(parms))
    emit('[MEGABEAST_CAP:%d]', parms.megabeast_cap)
    emit('[SEMIMEGABEAST_CAP:%d]', parms.semimegabeast_cap)
    emit('[TITAN_NUMBER:%d]', parms.titan_number)
    emit('[TITAN_ATTACK_TRIGGER:%d:%d:%d]',
        parms.titan_attack_trigger[0], parms.titan_attack_trigger[1],
        parms.titan_attack_trigger[2])
    emit('[DEMON_NUMBER:%d]', parms.demon_number)
    emit('[NIGHT_TROLL_NUMBER:%d]', parms.night_troll_number)
    emit('[BOGEYMAN_NUMBER:%d]', parms.bogeyman_number)
    emit('[NIGHTMARE_NUMBER:%d]', parms.nightmare_number)
    emit('[VAMPIRE_NUMBER:%d]', parms.vampire_number)
    emit('[WEREBEAST_NUMBER:%d]', parms.werebeast_number)
    emit('[WEREBEAST_ATTACK_TRIGGER:%d:%d:%d]',
        parms.werebeast_attack_trigger[0], parms.werebeast_attack_trigger[1],
        parms.werebeast_attack_trigger[2])
    emit('[SECRET_NUMBER:%d]', parms.secret_number)
    emit('[REGIONAL_INTERACTION_NUMBER:%d]', parms.regional_interaction_number)
    emit('[DISTURBANCE_INTERACTION_NUMBER:%d]', parms.disturbance_interaction_number)
    emit('[EVIL_CLOUD_NUMBER:%d]', parms.evil_cloud_number)
    emit('[EVIL_RAIN_NUMBER:%d]', parms.evil_rain_number)
    emit('[GENERATE_DIVINE_MATERIALS:%d]', parms.generate_divine_materials)
    emit('[GENERATE_MYTHICAL_MATERIALS:%d]', parms.use_mythical_materials)
    emit('[ALLOW_MYTHICAL_HEALING:%d]', parms.allow_mythical_healing)
    emit('[ALLOW_DIVINATION:%d]', parms.allow_divination)
    emit('[ALLOW_DEMONIC_EXPERIMENTS:%d]', parms.allow_demonic_experiments)
    emit('[ALLOW_NECROMANCER_EXPERIMENTS:%d]', parms.allow_necromancer_experiments)
    emit('[ALLOW_NECROMANCER_LIEUTENANTS:%d]', parms.allow_necromancer_lieutenants)
    emit('[ALLOW_NECROMANCER_GHOULS:%d]', parms.allow_necromancer_ghouls)
    emit('[ALLOW_NECROMANCER_SUMMONS:%d]', parms.allow_necromancer_summons)

    emit('[GOOD_SQ_COUNTS:%d:%d:%d]', relaxed(parms.good_sq_counts_0),
        relaxed(parms.good_sq_counts_1), relaxed(parms.good_sq_counts_2))
    emit('[EVIL_SQ_COUNTS:%d:%d:%d]', relaxed(parms.evil_sq_counts_0),
        relaxed(parms.evil_sq_counts_1), relaxed(parms.evil_sq_counts_2))
    emit('[PEAK_NUMBER_MIN:%d]', relaxed(parms.peak_number_min))
    emit('[PARTIAL_OCEAN_EDGE_MIN:%d]', relaxed(parms.partial_ocean_edge_min))
    emit('[COMPLETE_OCEAN_EDGE_MIN:%d]', relaxed(parms.complete_ocean_edge_min))
    emit('[VOLCANO_MIN:%d]', relaxed(parms.volcano_min))
    for _, spec in ipairs(REGION_COUNT_TYPES) do
        emit('[REGION_COUNTS:%s:%d:%d:%d]', spec[2],
            relaxed(parms.region_counts[0][spec[1]]),
            relaxed(parms.region_counts[1][spec[1]]),
            relaxed(parms.region_counts[2][spec[1]]))
    end

    emit('[EROSION_CYCLE_COUNT:%d]', relaxed(parms.erosion_cycle_count))
    emit('[RIVER_MINS:%d:%d]', relaxed(parms.river_mins[0]), relaxed(parms.river_mins[1]))
    emit('[PERIODICALLY_ERODE_EXTREMES:%d]', relaxed(parms.periodically_erode_extremes))
    emit('[OROGRAPHIC_PRECIPITATION:%d]', relaxed(parms.orographic_precipitation))
    emit('[SUBREGION_MAX:%d]', parms.subregion_max)
    emit('[CAVERN_LAYER_COUNT:%d]', parms.cavern_layer_count)
    emit('[CAVERN_LAYER_OPENNESS_MIN:%d]', parms.cavern_layer_openness_min)
    emit('[CAVERN_LAYER_OPENNESS_MAX:%d]', parms.cavern_layer_openness_max)
    emit('[CAVERN_LAYER_PASSAGE_DENSITY_MIN:%d]', parms.cavern_layer_passage_density_min)
    emit('[CAVERN_LAYER_PASSAGE_DENSITY_MAX:%d]', parms.cavern_layer_passage_density_max)
    emit('[CAVERN_LAYER_WATER_MIN:%d]', parms.cavern_layer_water_min)
    emit('[CAVERN_LAYER_WATER_MAX:%d]', parms.cavern_layer_water_max)
    emit('[HAVE_BOTTOM_LAYER_1:%d]', parms.have_bottom_layer_1 and 1 or 0)
    emit('[HAVE_BOTTOM_LAYER_2:%d]', parms.have_bottom_layer_2 and 1 or 0)
    emit('[LEVELS_ABOVE_GROUND:%d]', parms.levels_above_ground)
    emit('[LEVELS_ABOVE_LAYER_1:%d]', parms.levels_above_layer_1)
    emit('[LEVELS_ABOVE_LAYER_2:%d]', parms.levels_above_layer_2)
    emit('[LEVELS_ABOVE_LAYER_3:%d]', parms.levels_above_layer_3)
    emit('[LEVELS_ABOVE_LAYER_4:%d]', parms.levels_above_layer_4)
    emit('[LEVELS_ABOVE_LAYER_5:%d]', parms.levels_above_layer_5)
    emit('[LEVELS_AT_BOTTOM:%d]', parms.levels_at_bottom)
    emit('[CAVE_MIN_SIZE:%d]', parms.cave_min_size)
    emit('[CAVE_MAX_SIZE:%d]', parms.cave_max_size)
    emit('[MOUNTAIN_CAVE_MIN:%d]', parms.mountain_cave_min)
    emit('[NON_MOUNTAIN_CAVE_MIN:%d]', parms.non_mountain_cave_min)
    emit('[MYTHICAL_SITE_NUM:%d]', parms.mythical_site_num)
    emit('[ALL_CAVES_VISIBLE:%d]', parms.all_caves_visible)
    emit('[SHOW_EMBARK_TUNNEL:%d]', parms.show_embark_tunnel)
    emit('[TOTAL_CIV_NUMBER:%d]', parms.total_civ_number)
    emit('[TOTAL_CIV_POPULATION:%d]', parms.total_civ_population)
    emit('[SITE_CAP:%d]', parms.site_cap)
    emit('[PLAYABLE_CIVILIZATION_REQUIRED:%d]', parms.playable_civilization_required)

    emit('[ELEVATION_RANGES:%d:%d:%d]', relaxed(parms.elevation_ranges_0),
        relaxed(parms.elevation_ranges_1), relaxed(parms.elevation_ranges_2))
    emit('[RAIN_RANGES:%d:%d:%d]', relaxed(parms.rain_ranges_0),
        relaxed(parms.rain_ranges_1), relaxed(parms.rain_ranges_2))
    emit('[DRAINAGE_RANGES:%d:%d:%d]', relaxed(parms.drainage_ranges_0),
        relaxed(parms.drainage_ranges_1), relaxed(parms.drainage_ranges_2))
    emit('[SAVAGERY_RANGES:%d:%d:%d]', relaxed(parms.savagery_ranges_0),
        relaxed(parms.savagery_ranges_1), relaxed(parms.savagery_ranges_2))
    emit('[VOLCANISM_RANGES:%d:%d:%d]', relaxed(parms.volcanism_ranges_0),
        relaxed(parms.volcanism_ranges_1), relaxed(parms.volcanism_ranges_2))

    if options.map then
        emit_ps(lines)
    end

    return lines
end

local function default_title()
    local name = dfhack.translation.translateName(
        df.global.world.world_data.name, true)
    name = sanitize(name):upper()
    return #name > 0 and name or 'EXPORTED'
end

local function get_world_gen_path()
    return dfhack.filesystem.getBaseDir() .. 'prefs/world_gen.txt'
end

-- check whether a stanza with this title already exists in the file
local function has_title(path, title)
    local f = io.open(path, 'r')
    if not f then return false end
    local pattern = '[TITLE:' .. title:upper() .. ']'
    for line in f:lines() do
        -- DF indents tokens in world_gen.txt
        line = line:match('^%s*(.-)%s*$')
        if line:upper() == pattern then
            f:close()
            return true
        end
    end
    f:close()
    return false
end

local function append_stanza(path, lines)
    dfhack.filesystem.mkdir_recursive(dfhack.filesystem.getBaseDir() .. 'prefs')
    -- if the file exists and doesn't end in a newline, add one first so the
    -- stanza doesn't get glued to the previous line
    local f = io.open(path, 'r')
    local prefix = ''
    if f then
        f:seek('end')
        local size = f:seek()
        if size > 0 then
            f:seek('set', size - 1)
            if f:read(1) ~= '\n' then
                prefix = '\n'
            end
        end
        f:close()
    end
    f = io.open(path, 'a')
    if not f then
        qerror('could not open ' .. path .. ' for writing')
    end
    f:write(prefix .. '\n' .. table.concat(lines, '\n') .. '\n')
    f:close()
end

local function main(args)
    local options = {
        title = nil,
        map = false,
        relax = false,
        seed = false,
        history_seed = false,
        name_seed = false,
        creature_seed = false,
        keep_name = false,
        print = false,
        help = false,
    }

    local positionals = argparse.processArgsGetopt(args, {
        {'h', 'help',          handler=function() options.help = true end},
        {'t', 'title',         hasArg=true, handler=function(optarg) options.title = sanitize(optarg) end},
        {'m', 'map',           handler=function() options.map = true end},
        {'',  'relax',         handler=function() options.relax = true end},
        {'',  'seed',          handler=function() options.seed = true end},
        {'',  'history-seed',  handler=function() options.history_seed = true end},
        {'',  'name-seed',     handler=function() options.name_seed = true end},
        {'',  'creature-seed', handler=function() options.creature_seed = true end},
        {'',  'all-seeds',     handler=function()
            options.seed = true
            options.history_seed = true
            options.name_seed = true
            options.creature_seed = true
        end},
        {'',  'keep-name',     handler=function() options.keep_name = true end},
        {'p', 'print',         handler=function() options.print = true end},
    })

    if options.help or positionals[1] == 'help' then
        print(dfhack.script_help())
        return
    end

    if not dfhack.isWorldLoaded() then
        qerror('this script requires a loaded world')
    end

    options.title = options.title or default_title()
    local lines = build_stanza(options)

    if options.print then
        print(table.concat(lines, '\n'))
        return
    end

    local path = get_world_gen_path()
    if has_title(path, options.title) then
        dfhack.printerr(('warning: world_gen.txt already contains a parameter ' ..
            'set titled "%s"'):format(options.title))
    end
    append_stanza(path, lines)
    print(('appended parameter set "%s" to %s'):format(options.title, path))
    print('load the parameter set from the "create world" screen to use it')

    local viewscreen = dfhack.gui.getDFViewscreen()
    if df.viewscreen_new_regionst:is_instance(viewscreen) then
        dfhack.printerr('note: DF only reads world_gen.txt when loading the ' ..
            'parameter list; leave and re-enter the create world screen (or ' ..
            'reload the list) to see the new parameter set')
    end
end

if not dfhack_flags.module then
    main({...})
end
