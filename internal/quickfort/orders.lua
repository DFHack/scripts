-- generates manager orders for the quickfort script
--@ module = true
--[[
Enqueues manager orders to produce the materials required to build the buildings
in a specified blueprint.
]]

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')

-- local ok, stockflow = pcall(require, 'plugins.stockflow')
-- if not ok then
--     stockflow = nil
-- end

-- use our own copy of stockflow logic until stockflow becomes available again
local stockflow = reqscript('internal/quickfort/stockflow')

local log = quickfort_common.log

local function inc_order_spec(order_specs, quantity, reactions, label)
    if label == 'wood' then
        log('no manager order for creating wood; go chop some!')
        return
    end
    label = label:gsub('_', ' ')
    log('needs job to build: %s %s', tostring(quantity), label)
    if not order_specs[label] then
        local order = nil
        for _,v in ipairs(reactions) do
            local name = v.name:lower()
            -- just find the first procedurally generated instrument
            if label == 'instrument' and name:find('^assemble [^ ]+$') then
                order = v.order
                break
            -- the success of these matchers depends on the job name that is
            -- generated by stockflow.lua, which mimics the job name generated
            -- in the UI. I'm not particularly fond of this fragile method of
            -- finding jobs, but I can't find a better one (without duplicating
            -- a lot of the logic that's already in stockflow for deciding which
            -- jobs are valid).
            elseif name:find('^'..label..'$') or
                    name:find('^construct rock '..label..'$') or
                    name:find('^make wooden '..label..'$') or
                    name:find('^make '..label..'$') or
                    name:find('^construct '..label..'$') or
                    name:find('^forge '..label..'$') or
                    name:find('^smelt '..label..'$') then
                order = v.order
                break
            end
        end
        if not order then error(string.format('unhandled label: %s', label)) end
        order_specs[label] = {order=order, quantity=0}
    end
    order_specs[label].quantity = order_specs[label].quantity + quantity
end

-- translates item_type names into something we can find in the job names,
-- adding some strategic prefixes so we choose materials in this order:
-- rock, wood, iron.
local function process_filter(order_specs, filter, reactions)
    local label = nil
    if filter.flags2 and filter.flags2.building_material then
        if filter.flags2.magma_safe then
            -- TODO: restrict this to magma-safe materials?
            label = 'blocks'
        elseif filter.flags2.fire_safe then
            -- TODO: restrict this to fire-safe materials?
            label = 'blocks'
        else label = 'blocks' end
    elseif filter.item_type == df.item_type.TOOL then
        label = df.tool_uses[filter.has_tool_use]:lower()
        if filter.has_tool_use == df.tool_uses.PLACE_OFFERING then
            label = 'altar'
        elseif filter.has_tool_use == df.tool_uses.DISPLAY_OBJECT then
            label = 'display case'
        end
        label = 'rock ' .. label
    elseif filter.item_type == df.item_type.ANIMALTRAP then
        label = 'animal trap'
    elseif filter.item_type == df.item_type.ARMORSTAND then
        label = 'armor stand'
    elseif filter.item_type == df.item_type.ANVIL then label = 'iron anvil'
    elseif filter.item_type == df.item_type.BALLISTAPARTS then
        label = 'ballista parts'
    elseif filter.item_type == df.item_type.BAR then label = 'magnetite ore'
    elseif filter.item_type == df.item_type.BOX then label = 'coffer'
    elseif filter.item_type == df.item_type.CAGE then label = 'wooden cage'
    elseif filter.item_type == df.item_type.CATAPULTPARTS then
        label = 'catapult parts'
    elseif filter.item_type == df.item_type.CHAIN then label = 'cloth rope'
    elseif filter.item_type == df.item_type.CHAIR then label = 'throne'
    elseif filter.item_type == df.item_type.SMALLGEM then
        label = 'cut green glass'
    elseif filter.item_type == df.item_type.TRAPCOMP then
        label = 'enormous wooden corkscrew'
    elseif filter.item_type == df.item_type.TRAPPARTS then label = 'mechanisms'
    elseif filter.item_type == df.item_type.WEAPONRACK then
        label = 'weapon rack'
    elseif filter.item_type == df.item_type.WINDOW then
        label = 'green glass window'
    elseif filter.item_type then label = df.item_type[filter.item_type]:lower()
    elseif filter.vector_id == df.job_item_vector_id.ANY_WEAPON then
        label = 'iron battle axe'
    elseif filter.vector_id == df.job_item_vector_id.ANY_SPIKE then
        label = 'iron spear'
    end
    if not label then
        dfhack.printerr('unhandled filter:')
        printall_recurse(filter)
        error('quickfort out of sync with DFHack filters; please file a bug')
    end
    inc_order_spec(order_specs, filter.quantity or 1, reactions, label)
end

-- returns the number of materials required for this extent-based structure
local function get_num_items(b)
    local num_tiles = 0
    for extent_x, col in ipairs(b.extent_grid) do
        for extent_y, in_extent in ipairs(col) do
            if in_extent then num_tiles = num_tiles + 1 end
        end
    end
    return math.floor(num_tiles/4) + 1
end

function create_orders(ctx)
    for k,order_spec in pairs(ctx.order_specs or {}) do
        local quantity = math.ceil(order_spec.quantity)
        log('ordering %d %s', quantity, k)
        if not ctx.dry_run and stockflow then
            stockflow.create_orders(order_spec.order, quantity)
        end
        table.insert(ctx.stats, {label=k, value=quantity, is_order=true})
    end
end

-- we only need to init this once, even if a new save is loaded, since we only
-- care about the built-in reactions, not the mod-added ones.
-- note that we also shouldn't reinit this because it contains allocated memory
local function get_reactions()
    g_reactions = g_reactions or (stockflow and stockflow.collect_reactions()) or {}
    return g_reactions
end

local function ensure_order_specs(ctx)
    local order_specs = ctx.order_specs or {}
    ctx.order_specs = order_specs
    return order_specs
end

function enqueue_additional_order(ctx, label)
    local order_specs = ensure_order_specs(ctx)
    inc_order_spec(order_specs, 1, get_reactions(), label)
end

function enqueue_building_orders(buildings, ctx)
    local order_specs = ensure_order_specs(ctx)
    local reactions = get_reactions()
    for _, b in ipairs(buildings) do
        local db_entry = b.db_entry
        log('processing %s, defined from spreadsheet cell(s): %s',
            db_entry.label, table.concat(b.cells, ', '))
        local filters = dfhack.buildings.getFiltersByType(
            {}, db_entry.type, db_entry.subtype, db_entry.custom)
        if not filters then
            error(string.format(
                    'unhandled building type: "%s:%s:%s"; buildings.lua ' ..
                    'needs updating',
                    db_entry.type, db_entry.subtype, db_entry.custom))
        end
        if db_entry.additional_orders then
            for _,label in ipairs(db_entry.additional_orders) do
                inc_order_spec(order_specs, 1, reactions, label)
            end
        end
        for _,filter in ipairs(filters) do
            if filter.quantity == -1 then filter.quantity = get_num_items(b) end
            if filter.flags2 and filter.flags2.building_material then
                -- rock blocks get produced at a ratio of 4:1
                -- note that this can be a fraction; math.ceil() is used in create_orders to compensate
                filter.quantity = (filter.quantity or 1) / 4
            end
            process_filter(order_specs, filter, reactions)
        end
    end
end

function enqueue_container_orders(ctx, num_bins, num_barrels, num_wheelbarrows)
    local order_specs = ctx.order_specs or {}
    ctx.order_specs = order_specs
    local reactions = get_reactions()
    if num_bins and num_bins > 0 then
        inc_order_spec(order_specs, num_bins, reactions, "wooden bin")
    end
    if num_barrels and num_barrels > 0 then
        inc_order_spec(order_specs, num_barrels, reactions, "rock pot")
    end
    if num_wheelbarrows and num_wheelbarrows > 0 then
        inc_order_spec(
            order_specs, num_wheelbarrows, reactions, "wooden wheelbarrow")
    end
end
