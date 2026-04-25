-- Instantly harvest plants, shrubs, and crops in a selected area.
--[====[
gui/harvest
===========

Tags: fort | armok | plants

Instantly harvest shrubs, farm crops, and fallen fruit/plant
items within a box-selected area. Harvested goods are placed
into a container or on the ground.

Usage
-----

    gui/harvest

Click and drag a box on the map to select harvestable plants.
Double-click empty ground to execute the harvest. The tool will
auto-locate an empty barrel or bag in the fortress, or you can
double-click an existing container to use it.

Options (in-window toggles)
---------------------------

Ctrl-A
    Select all harvestable tiles on the current z-level.

Ctrl-C
    Clear the current selection.

Ctrl-M
    Toggle between simulating your best dwarf's skill level
    and forcing maximum yields.

Ctrl-S
    Toggle whether saplings are included in the harvest.
]====]

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

-- Debug logging: set to false to disable all file I/O for maximum performance
local DEBUG_LOGGING = false
local LOG_PATH = 'harvest_debug.log'
local log_buffer = {}

local function log(msg)
    if not DEBUG_LOGGING then return end
    log_buffer[#log_buffer + 1] = tostring(msg)
end

local function flush_log()
    if not DEBUG_LOGGING or #log_buffer == 0 then return end
    local f = io.open(LOG_PATH, 'a')
    if f then
        f:write(table.concat(log_buffer, '\n') .. '\n')
        f:close()
    end
    log_buffer = {}
end

-- Clear log on script load
if DEBUG_LOGGING then
    local f = io.open(LOG_PATH, 'w')
    if f then f:write('=== harvest.lua loaded ===\n'); f:close() end
end

local function is_empty_container(item)
    if not item.flags.on_ground or item.flags.in_building or item.flags.in_job or item.flags.in_inventory or item.flags.forbid or item.flags.garbage_collect then
        return false
    end
    local item_type = item:getType()
    if item_type ~= df.item_type.BOX and item_type ~= df.item_type.BAG and item_type ~= df.item_type.BARREL then
        return false
    end
    return #dfhack.items.getContainedItems(item) == 0
end

-- Pre-build tiletype lookup: material_id -> floor tiletype id
-- Built once on script load, O(1) lookups during harvest
local FLOOR_TILETYPE_CACHE = {}
do
    for k = 0, 600 do
        local v = df.tiletype.attrs[k]
        if v and v.shape == df.tiletype_shape.FLOOR and v.variant == 0 then
            local mat = v.material
            if not FLOOR_TILETYPE_CACHE[mat] then
                FLOOR_TILETYPE_CACHE[mat] = k
            end
        end
    end
end

local function remove_shrub_tile(plant)
    local pos = plant.pos
    local block = dfhack.maps.ensureTileBlock(pos)
    if not block then return end

    local lx, ly = pos.x % 16, pos.y % 16
    local tt = block.tiletype[lx][ly]
    local attrs = df.tiletype.attrs[tt]
    log('  remove_shrub_tile: tt=' .. tt .. ' shape=' .. tostring(attrs.shape) .. ' mat=' .. tostring(attrs.material))

    if attrs.shape == df.tiletype_shape.SHRUB or attrs.shape == df.tiletype_shape.SAPLING then
        local floor_tt = FLOOR_TILETYPE_CACHE[attrs.material]
        if floor_tt then
            block.tiletype[lx][ly] = floor_tt
            log('  remove_shrub_tile: set tiletype=' .. floor_tt .. ' (cached)')
        else
            block.tiletype[lx][ly] = 348  -- generic soil floor fallback
            log('  remove_shrub_tile: set tiletype=348 (fallback)')
        end
    else
        log('  remove_shrub_tile: tile is not SHRUB/SAPLING shape, skipping')
    end
end

local function pure_ensure_key(t, k, default)
    if t[k] == nil then
        t[k] = default or {}
    end
    return t[k]
end

-- Check if a shrub (non-tree) has harvestable growths or is a plain harvestable plant
local function is_shrub_harvestable(plant_obj)
    local raw = df.global.world.raws.plants.all[plant_obj.material]
    if not raw then return false end
    -- Shrubs with no growths are just base plants (plump helmets, etc.)
    if #raw.growths == 0 then return true end

    local tick = df.global.cur_year_tick
    for _, g in ipairs(raw.growths) do
        if g.timing_1 == -1 or g.timing_2 == -1 then
            return true
        elseif g.timing_1 >= 0 and g.timing_2 >= 0 then
            local active = false
            if g.timing_1 <= g.timing_2 then
                active = (tick >= g.timing_1 and tick <= g.timing_2)
            else
                active = (tick >= g.timing_1 or tick <= g.timing_2)
            end
            if active then return true end
        end
    end
    return false
end

-- Check if a growth produces a harvestable item (fruit/nut/berry, not leaves/twigs)
local function is_harvestable_growth(growth, raw)
    -- Check if this growth has a harvest product defined in the material
    local matinfo = dfhack.matinfo.decode(growth)
    if not matinfo then return false end
    -- Check the material flags for edibility/harvestability
    local mat = matinfo.material
    if not mat then return false end
    -- If the material is edible raw, edible cooked, or is a seed-bearing fruit, it's harvestable
    if mat.flags.EDIBLE_RAW or mat.flags.EDIBLE_COOKED then
        return true
    end
    -- Also check if the growth ID suggests it's a fruit/nut/berry/pod
    local gid = growth.id:upper()
    if gid:find('FRUIT') or gid:find('NUT') or gid:find('BERRY') or gid:find('POD')
       or gid:find('CONE') or gid:find('SEED') or gid:find('FLOWER') then
        return true
    end
    return false
end

-- Check if a tree has any currently-active harvestable fruit growths
local function tree_has_harvestable_fruit(plant_obj)
    local raw = df.global.world.raws.plants.all[plant_obj.material]
    if not raw or #raw.growths == 0 then return false end

    local tick = df.global.cur_year_tick
    for _, g in ipairs(raw.growths) do
        local active = false
        if g.timing_1 == -1 or g.timing_2 == -1 then
            active = true
        elseif g.timing_1 >= 0 and g.timing_2 >= 0 then
            if g.timing_1 <= g.timing_2 then
                active = (tick >= g.timing_1 and tick <= g.timing_2)
            else
                active = (tick >= g.timing_1 or tick <= g.timing_2)
            end
        end
        if active and is_harvestable_growth(g, raw) then
            return true
        end
    end
    return false
end

local function spawn_plant_yield_raw(mat_index, target_container, pos, stack_size, check_season)
    local raw = df.global.world.raws.plants.all[mat_index]
    if not raw then
        log('  spawn_plant_yield_raw: raw not found for mat_index=' .. tostring(mat_index))
        return 0
    end

    local creator = nil
    for _, u in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(u) then
            creator = u
            break
        end
    end

    log('  spawn_plant_yield_raw: plant=' .. raw.id .. ' mat_index=' .. mat_index .. ' growths=' .. #raw.growths .. ' stack=' .. stack_size .. ' check_season=' .. tostring(check_season))
    local tick = df.global.cur_year_tick
    log('  cur_year_tick=' .. tostring(tick))
    local spawned_any = false
    local count = 0

    for gi, g in ipairs(raw.growths) do
        local active = true
        log('    growth[' .. gi .. ']: timing_1=' .. tostring(g.timing_1) .. ' timing_2=' .. tostring(g.timing_2))
        if g.timing_1 == -1 or g.timing_2 == -1 then
            active = true
            log('      -> perpetual, active=true')
        elseif g.timing_1 >= 0 and g.timing_2 >= 0 then
            if check_season then
                active = false
                if g.timing_1 <= g.timing_2 then
                    active = (tick >= g.timing_1 and tick <= g.timing_2)
                else
                    active = (tick >= g.timing_1 or tick <= g.timing_2)
                end
                log('      -> seasonal check, active=' .. tostring(active))
            else
                log('      -> skipping season check, active=true')
            end
        else
            active = false
            log('      -> unknown timing, active=false')
        end

        if active then
            local matinfo = dfhack.matinfo.decode(g)
            log('      matinfo.decode result: ' .. tostring(matinfo))
            if matinfo then
                log('      matinfo.type=' .. tostring(matinfo.type) .. ' matinfo.index=' .. tostring(matinfo.index))
                log('      calling createItem(creator, PLANT_GROWTH, ' .. tostring(g.item_subtype) .. ', ' .. tostring(matinfo.type) .. ', ' .. tostring(matinfo.index) .. ')')
                local ok, new_items = pcall(dfhack.items.createItem, creator, df.item_type.PLANT_GROWTH, g.item_subtype, matinfo.type, matinfo.index)
                log('      createItem ok=' .. tostring(ok) .. ' result=' .. tostring(new_items))
                if ok and new_items and type(new_items) == 'table' and new_items[1] then
                    new_items[1]:setStackSize(stack_size)
                    if target_container then dfhack.items.moveToContainer(new_items[1], target_container)
                    else dfhack.items.moveToGround(new_items[1], pos) end
                    spawned_any = true
                    count = count + 1
                    log('      >>> SPAWNED growth item!')
                else
                    log('      createItem FAILED or returned empty')
                end
            else
                log('      matinfo.decode FAILED')
            end
        end
    end

    if not spawned_any then
        log('    No growths spawned, trying base plant material...')
        local matinfo = dfhack.matinfo.find('PLANT', raw.id)
        if matinfo then
            log('    matinfo.find(PLANT, ' .. raw.id .. ') = type:' .. tostring(matinfo.type) .. ' idx:' .. tostring(matinfo.index))
            local ok, new_items = pcall(dfhack.items.createItem, creator, df.item_type.PLANT, -1, matinfo.type, matinfo.index)
            log('    createItem ok=' .. tostring(ok) .. ' result=' .. tostring(new_items))
            if ok and new_items and type(new_items) == 'table' and new_items[1] then
                new_items[1]:setStackSize(stack_size)
                if target_container then dfhack.items.moveToContainer(new_items[1], target_container)
                else dfhack.items.moveToGround(new_items[1], pos) end
                count = count + 1
                log('    >>> SPAWNED base plant item!')
            else
                log('    createItem FAILED for base plant')
            end
        else
            log('    matinfo.find FAILED for structural material')
        end
    end
    log('  spawn_plant_yield_raw returning count=' .. count)
    return count
end

local function get_fortress_max_harvest_skills()
    local max_grower = 0
    local max_herbalist = 0

    for _, unit in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(unit) and not dfhack.units.isDead(unit) then
            local grower = dfhack.units.getNominalSkill(unit, df.job_skill.PLANT)
            local herbalist = dfhack.units.getNominalSkill(unit, df.job_skill.HERBALISM)

            if grower > max_grower then max_grower = grower end
            if herbalist > max_herbalist then max_herbalist = herbalist end

            if max_grower >= 15 and max_herbalist >= 15 then
                break
            end
        end
    end
    return math.max(0, max_grower), math.max(0, max_herbalist)
end

-----------------
-- Harvest Window
-----------------

Harvest = defclass(Harvest, widgets.Window)
Harvest.ATTRS {
    frame_title = 'Instant Harvest',
    frame = {w = 52, h = 18, r = 2, t = 18},
    resizable = true,
    resize_min = {h = 10},
    autoarrange_subviews = true,
}

function Harvest:init()
    self.mark = nil
    self:reset_selected_state()
    self:reset_double_click()

    self:addviews{
        widgets.WrappedLabel{
            frame = {l = 0},
            text_to_wrap = self:callback('get_help_text'),
        },
        widgets.Panel{frame = {h = 1}},
        widgets.HotkeyLabel{
            frame = {l = 0},
            label = 'Select all tiles on this z-level',
            key = 'CUSTOM_CTRL_A',
            auto_width = true,
            on_activate = function()
                self:select_harvestables_in_box(self:get_bounds(
                    {x=0, y=0, z=df.global.window_z},
                    {x=df.global.world.map.x_count-1,
                     y=df.global.world.map.y_count-1,
                     z=df.global.window_z}))
                self.mark = nil
                self:updateLayout()
            end,
        },
        widgets.HotkeyLabel{
            frame = {l = 0},
            label = 'Clear selected area',
            key = 'CUSTOM_CTRL_C',
            auto_width = true,
            on_activate = self:callback('reset_selected_state'),
            enabled = function() return next(self.selected_coords) or self.mark end,
        },
        widgets.Panel{frame = {h = 1}},
        widgets.ToggleHotkeyLabel{
            view_id = 'force_max_yield',
            frame = {l = 0},
            label = 'Skill Simulation',
            key = 'CUSTOM_CTRL_M',
            options = {
                {label = 'Simulate Fortress Skill', value = false},
                {label = 'Force Maximum Yields', value = true},
            },
            auto_width = true,
            initial_option = false,
        },
        widgets.ToggleHotkeyLabel{
            view_id = 'include_saplings',
            frame = {l = 0},
            label = 'Saplings',
            key = 'CUSTOM_CTRL_S',
            options = {
                {label = 'Skip Saplings', value = false},
                {label = 'Include Saplings', value = true},
            },
            auto_width = true,
            initial_option = false,
        },
        widgets.Panel{frame = {h = 1}},
        widgets.WrappedLabel{
            frame = {l = 0},
            text_to_wrap = 'Double-click empty ground to auto-summon an empty bag or barrel from the fortress, or double-click an existing container to use it.',
        },
    }
end

function Harvest:reset_double_click()
    self.last_map_click_ms = 0
    self.last_map_click_pos = {}
end

function Harvest:reset_selected_state()
    self.selected_items = {}
    self.selected_plants = {}
    self.selected_coords = {} -- z -> y -> x -> true
    self.selected_bounds = {}
    self.mark = nil
    if next(self.subviews) then
        self:updateLayout()
    end
end

function Harvest:get_help_text()
    local item_count = 0
    for k, v in pairs(self.selected_items) do item_count = item_count + 1 end
    local plant_count = 0
    for k, v in pairs(self.selected_plants) do plant_count = plant_count + 1 end

    local ret = 'Double-click to harvest ' .. tostring(item_count) .. ' fallen items and ' .. tostring(plant_count) .. ' plants.'
    if item_count == 0 and plant_count == 0 then
        ret = 'Drag a box to select plants and dropped fruit. ' .. ret
    end
    return ret
end

function Harvest:get_bounds(cursor, mark)
    cursor = cursor or self.mark
    mark = mark or self.mark or cursor
    if not mark then return end

    return {
        x1 = math.min(cursor.x, mark.x),
        x2 = math.max(cursor.x, mark.x),
        y1 = math.min(cursor.y, mark.y),
        y2 = math.max(cursor.y, mark.y),
        z1 = math.min(cursor.z, mark.z),
        z2 = math.max(cursor.z, mark.z)
    }
end

function Harvest:find_global_empty_container()
    local first_bag = nil
    for _, item in ipairs(df.global.world.items.other.IN_PLAY) do
        if is_empty_container(item) then
            if item:getType() == df.item_type.BARREL then
                return item
            else
                if not first_bag then first_bag = item end
            end
        end
    end
    return first_bag
end

function Harvest:get_last_container()
    if self.last_container_id then
        local item = df.item.find(self.last_container_id)
        if item and item.flags.on_ground and not item.flags.in_building and not item.flags.in_job and not item.flags.in_inventory and not item.flags.forbid and not item.flags.garbage_collect then
            return item
        end
    end
    return nil
end

function Harvest:select_harvestables_in_box(bounds)
    if not bounds then
        log('select_harvestables_in_box: bounds is nil!')
        return
    end

    log('=== HARVEST DEBUG: select_harvestables_in_box ===')
    log('Bounds: x=' .. bounds.x1 .. '-' .. bounds.x2 .. ' y=' .. bounds.y1 .. '-' .. bounds.y2 .. ' z=' .. bounds.z1 .. '-' .. bounds.z2)

    local seen_buildings = {}
    local seen_blocks = {}
    local tiles_checked = 0

    for z = bounds.z1, bounds.z2 do
        for y = bounds.y1, bounds.y2 do
            for x = bounds.x1, bounds.x2 do
                tiles_checked = tiles_checked + 1
                local pos = xyz2pos(x, y, z)

                local bld = dfhack.buildings.findAtTile(pos)
                local is_farm = bld and bld:getType() == df.building_type.FarmPlot

                -- 1. Try getPlantAtTile: only select SHRUBS, NOT trees
                if not is_farm then
                    local ok_gp, plant_at = pcall(dfhack.maps.getPlantAtTile, pos)
                    if not ok_gp then
                        log('  getPlantAtTile CRASHED at (' .. x .. ',' .. y .. ',' .. z .. '): ' .. tostring(plant_at))
                    end
                    if ok_gp and plant_at then
                        local raw = df.global.world.raws.plants.all[plant_at.material]
                        local name = raw and raw.id or 'UNKNOWN'
                        local is_tree = (plant_at.tree_info ~= nil)
                        local tree_str = is_tree and 'TREE' or 'SHRUB'
                        log('  getPlantAtTile(' .. x .. ',' .. y .. ',' .. z .. '): ' .. name .. ' type=' .. tostring(plant_at.type) .. ' hp=' .. tostring(plant_at.hitpoints) .. ' gc=' .. tostring(plant_at.grow_counter) .. ' ' .. tree_str)

                        local dominated = not plant_at.damage_flags.dead
                        -- For trees, ignore season_dead (it's a normal seasonal state)
                        -- For shrubs, check both dead and season_dead
                        if not is_tree then
                            dominated = dominated and not plant_at.damage_flags.season_dead
                        end
                        -- A sapling is a tree species (type 0) that hasn't grown tree_info yet
                        -- type=2 is always a shrub, type=0 with tree_info is a mature tree
                        local is_sapling = (not is_tree and plant_at.type ~= 2)
                        local allow_saplings = self.subviews.include_saplings:getOptionValue()
                        log('    alive=' .. tostring(dominated) .. ' is_sapling=' .. tostring(is_sapling) .. ' allow_saplings=' .. tostring(allow_saplings))

                        if dominated and (not is_sapling or allow_saplings) then
                            if is_tree then
                                log('    TREE: skipped (trees cannot be harvested via script safely)')
                            else
                                -- Shrubs: select as before
                                local hg = is_shrub_harvestable(plant_at)
                                log('    is_shrub_harvestable=' .. tostring(hg))
                                if hg then
                                    local pid = tostring(plant_at)
                                    if not self.selected_plants[pid] then
                                        self.selected_plants[pid] = {plant=plant_at, is_tree=false}
                                        local px, py, pz = plant_at.pos.x, plant_at.pos.y, plant_at.pos.z
                                        pure_ensure_key(pure_ensure_key(self.selected_coords, pz), py)[px] = true
                                        local sb = pure_ensure_key(self.selected_bounds, pz, {x1=px, x2=px, y1=py, y2=py})
                                        sb.x1 = math.min(sb.x1, px); sb.x2 = math.max(sb.x2, px)
                                        sb.y1 = math.min(sb.y1, py); sb.y2 = math.max(sb.y2, py)
                                        log('    >>> SELECTED SHRUB via getPlantAtTile!')
                                    else
                                        log('    (already selected)')
                                    end
                                end
                            end
                        else
                            log('    SKIPPED (alive=' .. tostring(dominated) .. ' is_sapling=' .. tostring(is_sapling) .. ')')
                        end
                    end
                end

                -- 2. Farm plot evaluations
                if is_farm then
                    local bid = tostring(bld)
                    if not seen_buildings[bid] then
                        seen_buildings[bid] = true
                        log('  FarmPlot at (' .. x .. ',' .. y .. ',' .. z .. '), contained_items=' .. #bld.contained_items)
                        for ci, item_v in ipairs(bld.contained_items) do
                            local item = item_v.item
                            local itype = item:getType()
                            if itype == df.item_type.SEEDS then
                                local crop_raw = df.global.world.raws.plants.all[item.mat_index]
                                if crop_raw then
                                    log('    seed: ' .. crop_raw.id .. ' grow=' .. item.grow_counter .. '/' .. crop_raw.growdur)
                                    if item.grow_counter >= crop_raw.growdur then
                                        if not self.selected_items[item.id] then
                                            self.selected_items[item.id] = item
                                            local ix, iy, iz = dfhack.items.getPosition(item)
                                            if ix then
                                                pure_ensure_key(pure_ensure_key(self.selected_coords, iz), iy)[ix] = true
                                                local sb = pure_ensure_key(self.selected_bounds, iz, {x1=ix, x2=ix, y1=iy, y2=iy})
                                                sb.x1 = math.min(sb.x1, ix); sb.x2 = math.max(sb.x2, ix)
                                                sb.y1 = math.min(sb.y1, iy); sb.y2 = math.max(sb.y2, iy)
                                                log('    >>> SELECTED farm crop!')
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end

                -- 3. Scan block items once, bucket by tile position
                local block = dfhack.maps.getTileBlock(pos)
                local block_key = block and (math.floor(x/16) .. ',' .. math.floor(y/16) .. ',' .. z) or nil
                if block and not seen_blocks[block_key] then
                    seen_blocks[block_key] = true
                    log('  Scanning block ' .. block_key .. ' (' .. #block.items .. ' items)')
                    for _, item_id in ipairs(block.items) do
                        local item = df.item.find(item_id)
                        if item and not item.flags.garbage_collect then
                            local ix, iy, iz = dfhack.items.getPosition(item)
                            if ix and ix >= bounds.x1 and ix <= bounds.x2 and iy >= bounds.y1 and iy <= bounds.y2 and iz >= bounds.z1 and iz <= bounds.z2 then
                                local itype = item:getType()
                                local on_gnd = item.flags.on_ground
                                local rotten = item.flags.rotten
                                local is_plant_type = (itype == df.item_type.PLANT or itype == df.item_type.PLANT_GROWTH)
                                log('    item id=' .. item_id .. ' type=' .. tostring(itype) .. ' on_ground=' .. tostring(on_gnd) .. ' rotten=' .. tostring(rotten) .. ' at (' .. ix .. ',' .. iy .. ',' .. iz .. ')')

                                if on_gnd and not rotten and is_plant_type and not self.selected_items[item_id] then
                                    self.selected_items[item_id] = item
                                    pure_ensure_key(pure_ensure_key(self.selected_coords, iz), iy)[ix] = true
                                    local sb = pure_ensure_key(self.selected_bounds, iz, {x1=ix, x2=ix, y1=iy, y2=iy})
                                    sb.x1 = math.min(sb.x1, ix); sb.x2 = math.max(sb.x2, ix)
                                    sb.y1 = math.min(sb.y1, iy); sb.y2 = math.max(sb.y2, iy)
                                    log('    >>> SELECTED fallen item id=' .. item_id)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Final tally
    local item_count = 0
    for _ in pairs(self.selected_items) do item_count = item_count + 1 end
    local plant_count = 0
    for _ in pairs(self.selected_plants) do plant_count = plant_count + 1 end
    log('=== TOTAL: ' .. item_count .. ' items, ' .. plant_count .. ' plants (checked ' .. tiles_checked .. ' tiles) ===')
    flush_log()
end

function Harvest:do_harvest(pos)
    log('=== do_harvest at (' .. pos.x .. ',' .. pos.y .. ',' .. pos.z .. ') ===')
    -- 1. Identify container Target
    local target_container = nil

    -- First check if we double clicked ON a container
    local items_on_tile = dfhack.maps.getTileBlock(pos).items
    for _, item_id in ipairs(items_on_tile) do
        local item = df.item.find(item_id)
        if item and item.pos.x == pos.x and item.pos.y == pos.y and item.pos.z == pos.z then
            local itype = item:getType()
            if itype == df.item_type.BOX or itype == df.item_type.BAG or itype == df.item_type.BARREL then
                if not item.flags.forbid and not item.flags.in_job then
                    target_container = item
                    break
                end
            end
        end
    end

    if not target_container then
        target_container = self:get_last_container()
    end

    if not target_container then
        target_container = self:find_global_empty_container()
    end

    if target_container then
        self.last_container_id = target_container.id
        if not dfhack.items.moveToGround(target_container, pos) then
            target_container = nil
            self.last_container_id = nil
        end
    end

    if not target_container then
        log('WARNING: No free containers! Items will drop on floor.')
    else
        log('Using container: ' .. tostring(target_container))
    end

    -- 2. Setup skill values
    local sim_grower, sim_herbalist = 0, 0
    local ok, err = pcall(function()
        sim_grower, sim_herbalist = get_fortress_max_harvest_skills()
        if self.subviews.force_max_yield:getOptionValue() then
            sim_grower = 15
            sim_herbalist = 15
        end
    end)
    if not ok then
        log('CRASH in setup: ' .. tostring(err))
    end

    local stack_size = 1
    if sim_herbalist >= 5 then stack_size = 2 end
    if sim_herbalist >= 10 then stack_size = 4 end
    if sim_herbalist >= 15 then stack_size = 5 end
    log('  skill: grower=' .. sim_grower .. ' herbalist=' .. sim_herbalist .. ' stack=' .. stack_size)

    -- 3. Iterate collected selections and Harvest
    local harvested_count = 0

    -- Find a citizen to act as the creator for spawned items
    local creator_unit = nil
    for _, u in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(u) then
            creator_unit = u
            break
        end
    end

    for item_id, item in pairs(self.selected_items) do
        if item:getType() == df.item_type.SEEDS and item.flags.in_building then
            local mat_index = item.mat_index
            dfhack.items.moveToGround(item, pos)
            item.flags.garbage_collect = true
            harvested_count = harvested_count + spawn_plant_yield_raw(mat_index, target_container, pos, stack_size, false)
        else
            if target_container then
                dfhack.items.moveToContainer(item, target_container)
            else
                dfhack.items.moveToGround(item, pos)
            end
            harvested_count = harvested_count + 1
        end
    end

    for plant_id, plant_data in pairs(self.selected_plants) do
        local plant = plant_data.plant
        local is_tree = plant_data.is_tree
        log('  harvesting plant: ' .. tostring(plant) .. ' mat=' .. plant.material .. ' is_tree=' .. tostring(is_tree))

        if is_tree then
            log('    TREE: skipped (trees cannot be harvested via script safely)')
        else
            -- Shrub: spawn yield and kill the shrub
            harvested_count = harvested_count + spawn_plant_yield_raw(plant.material, target_container, pos, stack_size, true)
            plant.hitpoints = 0
            plant.damage_flags.dead = true
            remove_shrub_tile(plant)
        end
    end

    log('=== Successfully harvested ' .. tostring(harvested_count) .. ' items ===')
    flush_log()
    self:reset_selected_state()
end

function Harvest:onInput(keys)
    if Harvest.super.onInput(self, keys) then return true end

    if keys._MOUSE_R and self.mark then
        log('RIGHT CLICK: clearing mark')
        self.mark = nil
        self:updateLayout()
        return true
    elseif keys._MOUSE_L then
        if self:getMouseFramePos() then return true end
        local pos = dfhack.gui.getMousePos()
        if not pos then
            self:reset_double_click()
            return false
        end
        log('LEFT CLICK at (' .. pos.x .. ',' .. pos.y .. ',' .. pos.z .. ') mark=' .. tostring(self.mark ~= nil))
        local now_ms = dfhack.getTickCount()
        local is_dbl = same_xyz(pos, self.last_map_click_pos) and
                now_ms - self.last_map_click_ms <= widgets.getDoubleClickMs()
        log('  double_click=' .. tostring(is_dbl) .. ' has_selected=' .. tostring(next(self.selected_coords) ~= nil))
        if is_dbl then
            self:reset_double_click()
            if next(self.selected_coords) then
                log('  -> HARVESTING!')
                self:do_harvest(pos)
            else
                log('  -> No harvestables selected! Dumping tile debug...')
                local plant_at = dfhack.maps.getPlantAtTile(pos)
                log('  getPlantAtTile=' .. tostring(plant_at))
                if plant_at then
                    local raw = df.global.world.raws.plants.all[plant_at.material]
                    log('    plant=' .. (raw and raw.id or '?') .. ' type=' .. plant_at.type .. ' hp=' .. plant_at.hitpoints .. ' gc=' .. plant_at.grow_counter .. ' tree=' .. tostring(plant_at.tree_info ~= nil))
                end
            end
            self.mark = nil
            self:updateLayout()
            return true
        end
        self.last_map_click_ms = now_ms
        self.last_map_click_pos = pos
        if self.mark then
            log('  -> COMPLETING BOX SELECTION')
            self:select_harvestables_in_box(self:get_bounds(pos))
            self.mark = nil
            self:updateLayout()
            return true
        end
        log('  -> SETTING MARK')
        self.mark = pos
        self:updateLayout()
        return true
    end
end

local to_pen = dfhack.pen.parse
local CURSOR_PEN = to_pen{ch='o', fg=COLOR_GREEN, tile=dfhack.screen.findGraphicsTile('CURSORS', 5, 22)}
local BOX_PEN = to_pen{ch='X', fg=COLOR_GREEN, tile=dfhack.screen.findGraphicsTile('CURSORS', 0, 0)}

local SELECTED_PEN = to_pen{ch='I', fg=COLOR_GREEN, tile=dfhack.screen.findGraphicsTile('CURSORS', 1, 2)}

function Harvest:onRenderFrame(dc, rect)
    Harvest.super.onRenderFrame(self, dc, rect)

    local highlight_coords = self.selected_coords[df.global.window_z]
    if highlight_coords then
        local function get_overlay_pen(pos)
            if safe_index(highlight_coords, pos.y, pos.x) then
                return SELECTED_PEN
            end
        end
        guidm.renderMapOverlay(get_overlay_pen, self.selected_bounds[df.global.window_z])
    end

    local cursor = dfhack.gui.getMousePos()
    local hover_bounds = self:get_bounds(cursor)
    if hover_bounds and (dfhack.screen.inGraphicsMode() or gui.blink_visible(500)) then
        guidm.renderMapOverlay(
            function() return self.mark and BOX_PEN or CURSOR_PEN end,
            hover_bounds)
    end
end

-----------------------
-- Harvest Screen Layer
-----------------------

HarvestScreen = defclass(HarvestScreen, gui.ZScreen)
HarvestScreen.ATTRS {
    focus_path = 'harvest',
    pass_movement_keys = true,
    pass_mouse_clicks = false,
}

function HarvestScreen:init()
    self.window = Harvest{}
    self:addviews{
        self.window,
        widgets.DimensionsTooltip{
            get_anchor_pos_fn = function() return self.window.mark end,
        },
    }
end

function HarvestScreen:onDismiss()
    view = nil
end

view = view and view:raise() or HarvestScreen{}:show()
