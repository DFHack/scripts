-- Citizens carry extra loose items when hauling goods.
--[====[

multihaul
=========

When a citizen picks up an item for a stockpile, they also grab up to
``max`` additional loose items of the same type within ``radius`` tiles --
both at the pickup site and along the way -- then drop everything off in
one trip. Not enabled by default; run ``multihaul enable`` or
``enable multihaul`` to turn it on.

Usage::

    multihaul enable|disable
    multihaul status
    multihaul max <n>        (default 4, max extra items per trip)
    multihaul radius <n>     (default 2, tiles around the dwarf that are
                             collected while passing)
    multihaul fetch <n>      (default 8, how far around the pickup site the
                             dwarf detours to collect extras)
    multihaul weight <n>     (max combined weight of everything carried,
                             in DF mass units; default 0 = unlimited)
    multihaul weight auto    (derive the cap per dwarf from their
                             strength and body size)
    multihaul weight unlimited
    multihaul types same|all|pile
                             (default same; "all" also grabs items that
                             other haul jobs are taking to the same
                             destination, regardless of type; "pile" is
                             like "all" plus unclaimed items of any type
                             the destination stockpile's filter provably
                             accepts)
    multihaul targets piles|all
                             (default piles; "all" also piggybacks loads
                             into minecarts, barrels, and bins)

]====]

--@ enable=true
--@ module=true

local repeatutil = require('repeat-util')

local GLOBAL_KEY = 'multihaul'
local TIMER_NAME = 'multihaul'

local POLL_FRAMES = 3

-- persisted state
enabled = enabled or false
s_max = s_max or 4
s_radius = s_radius or 2
s_fetch = s_fetch or 8
s_weight = s_weight or 0
s_types = s_types or (s_types_all and 'all' or 'same')
s_targets_all = s_targets_all or false

-- transient state
-- unit_id -> {
--     job_id=number, primary_id=number, extras={item_id -> item},
--     weight=number (weight of primary + container + extras),
--     pile=building        (stockpile destination), or
--     container=item       (vehicle/barrel/bin destination)
-- }
tracked = tracked or {}

function isEnabled()
    return enabled
end

local function persist_state()
    dfhack.persistent.saveSiteData(GLOBAL_KEY, {
        enabled=enabled,
        s_max=s_max,
        s_radius=s_radius,
        s_fetch=s_fetch,
        s_weight=s_weight,
        s_types=s_types,
        s_targets_all=s_targets_all,
    })
end

local function load_state()
    local data = dfhack.persistent.getSiteData(GLOBAL_KEY, {})
    enabled = data.enabled or false
    s_max = data.s_max or 4
    s_radius = data.s_radius or 2
    s_fetch = data.s_fetch or 8
    s_weight = data.s_weight or 0
    -- s_types_all was the original persisted shape: a boolean that is
    -- now the 'same'/'all' modes of s_types
    s_types = data.s_types or (data.s_types_all and 'all' or 'same')
    s_targets_all = data.s_targets_all or false
end

local function get_job_stockpile(job)
    for _,gr in ipairs(job.general_refs) do
        if df.general_ref_building_holderst:is_instance(gr) then
            local bld = gr:getBuilding()
            if bld and df.building_stockpilest:is_instance(bld) then
                return bld
            end
        end
    end
end

-- resolve the job's delivery destination and the item that anchors the
-- pickup. For piles and vehicles the anchor is the carried item; for
-- barrels/bins it is the item being stored, since the dwarf carries the
-- container to the goods.
local function get_job_dest(job)
    if job.job_type == df.job_type.StoreItemInStockpile then
        local pile = get_job_stockpile(job)
        if not pile then return end
        local anchor
        for _,ref in ipairs(job.items) do
            if ref.item and ref.item:isWheelbarrow() then
                -- the wheelbarrow already multi-hauls for this job
                return
            elseif ref.item and (ref.role == df.job_role_type.Hauled
                    or ref.role == df.job_role_type.Reagent) then
                anchor = anchor or ref.item
            end
        end
        if anchor then
            return {pile=pile, anchor=anchor}
        end
    elseif s_targets_all and #job.items > 1 then
        if job.job_type == df.job_type.StoreItemInVehicle then
            local load, vehicle
            for _,ref in ipairs(job.items) do
                if ref.role == df.job_role_type.TargetContainer then
                    vehicle = ref.item
                elseif ref.item and (ref.role == df.job_role_type.Hauled
                        or ref.role == df.job_role_type.Reagent) then
                    load = ref.item
                end
            end
            -- wheelbarrows only ever hold one item
            if load and vehicle and not vehicle:isWheelbarrow() then
                return {container=vehicle, anchor=load}
            end
        elseif job.job_type == df.job_type.StoreItemInBarrel
                or job.job_type == df.job_type.StoreItemInBin then
            local container, queued
            for _,ref in ipairs(job.items) do
                if ref.role == df.job_role_type.Hauled then
                    container = ref.item
                elseif ref.role == df.job_role_type.QueuedContainer then
                    queued = ref.item
                end
            end
            if container and queued then
                return {container=container, anchor=queued}
            end
        end
    end
end

local function near(a, b, radius)
    return a.z == b.z and math.abs(a.x - b.x) <= radius
        and math.abs(a.y - b.y) <= radius
end

-- the container (vehicle, barrel, bin, ...) an item is inside, or nil
local function contained_in(item)
    for _,ref in ipairs(item.general_refs) do
        if ref:getType() == df.general_ref_type.CONTAINED_IN_ITEM then
            return ref:getItem()
        end
    end
end

-- true if a real job claims the item. Our own piggybacked extras only
-- carry the in_job flag and never have a JOB specific_ref, so this
-- distinguishes the two.
local function real_job_claim(item)
    for _,sref in ipairs(item.specific_refs) do
        if sref.type == df.specific_ref_type.JOB and sref.data.job
                and df.isvalid(sref.data.job) == 'ref' then
            return true
        end
    end
    return false
end

-- item:getStockpile() reads a .stockpile field that only exists on some
-- item classes (tools, containers) and throws on others (cloth, bags)
local function stockpile_assigned(item)
    local ok, pile = pcall(function() return item:getStockpile() end)
    return ok and pile ~= nil
end

-- the settings vectors surface as numbers (0/1), not booleans, and 0 is
-- truthy in Lua -- normalize to a real boolean. an empty vector means
-- the sub-filter was never configured (DF populates it lazily when the
-- settings panel opens), which is the default "all allowed" state
local function vget(vec, idx)
    if #vec == 0 then return true end
    if idx == nil or idx < 0 or idx >= #vec then return false end
    local v = vec[idx]
    return v ~= nil and v ~= false and v ~= 0
end

-- 'GLASS_GREEN' -> 'GlassGreen', matching the stockpile_*_mat enum names
local function enum_slot(enum, mat_id)
    local name = mat_id:lower():gsub('_(%l)', string.upper)
        :gsub('^%l', string.upper)
    return enum[name]
end

-- organic settings vectors (food, leather, cloth, sheets) are indexed
-- by position in world.raws.mat_table.organic_types/indexes[category].
-- For most categories the entry is a (mat_type, mat_index) pair; for
-- fish, unprepared fish, and eggs it is a (creature, caste) pair.
-- organic_pos caches the reverse map per category -- raws are immutable
-- during play, and pile_accepts is called once per candidate item
local organic_pos_cache = {}
local function organic_pos(cat_name, mtype, mindx)
    local cat = df.organic_mat_category[cat_name]
    local tab = organic_pos_cache[cat]
    if not tab then
        tab = {}
        local types = df.global.world.raws.mat_table.organic_types[cat]
        local idxs = df.global.world.raws.mat_table.organic_indexes[cat]
        for i = 0, #types - 1 do
            local sub = tab[types[i]]
            if not sub then
                sub = {}
                tab[types[i]] = sub
            end
            sub[idxs[i]] = i
        end
        organic_pos_cache[cat] = tab
    end
    local sub = tab[mtype]
    return sub and sub[mindx]
end

-- other_mats slots are filled by the material's organic class, not its
-- id: a silk glove's material id is just 'THREAD', but its class
-- membership tells us it belongs in the Silk slot. a material can sit
-- in several usage-class tables (a plant fiber is also valid Paper/
-- Paste), so only the material-kind classes are consulted, in order
local ORGANIC_SLOT_CATS = {'Silk', 'PlantFiber', 'Yarn', 'MetalThread',
    'Leather', 'Bone', 'Tooth', 'Horn', 'Pearl', 'Shell'}
local ORGANIC_SLOT_NAME = {PlantFiber='Plant'}

-- does the item's material pass a mats/other_mats pair? inorganic
-- materials index into mats except glass, which lives in other_mats;
-- organic materials map to other_mats slots via material id first, then
-- via their organic class (a silk glove's material id is just 'THREAD',
-- its class tells us it belongs in the Silk slot)
local function mat_ok(item, info, mats, other_mats, enum)
    if item:getMaterial() == 0 then
        local mi = item:getMaterialIndex()
        local inorg = df.global.world.raws.inorganics.all[mi]
        if inorg and inorg.id:sub(1, 6) == 'GLASS_' then
            -- the material id of inorganic items is blank, so glass has
            -- to be detected through the inorganic raw
            local slot = enum_slot(enum, inorg.id)
            return slot ~= nil and vget(other_mats, slot)
        end
        return vget(mats, mi)
    end
    if info == nil or info.material == nil then return false end
    local id = info.material.id
    local slot = enum_slot(enum, id)
    if slot == nil and info.plant then
        slot = enum[id == 'WOOD' and 'Wood' or 'Plant']
    end
    if slot == nil then
        for _, cat_name in ipairs(ORGANIC_SLOT_CATS) do
            if organic_pos(cat_name, item:getMaterial(),
                    item:getMaterialIndex()) then
                slot = enum[ORGANIC_SLOT_NAME[cat_name] or cat_name]
                break
            end
        end
    end
    return slot ~= nil and vget(other_mats, slot)
end

local CRITTER_CATS = {Fish=true, UnpreparedFish=true, Eggs=true}

local function organic_item_pos(cat_name, item)
    local mtype, mindx
    if CRITTER_CATS[cat_name] then
        mtype, mindx = item.race, item.caste
    else
        mtype, mindx = item:getMaterial(), item:getMaterialIndex()
    end
    if not mtype or not mindx or mtype < 0 or mindx < 0 then return nil end
    return organic_pos(cat_name, mtype, mindx)
end

-- item types the food filter covers, each mapped to the (settings
-- vector, organic category) pairs it can match
local FOOD_SPECS = {
    [df.item_type.MEAT] = {{'meat', 'Meat'}},
    [df.item_type.FISH] = {{'fish', 'Fish'}},
    [df.item_type.FISH_RAW] = {{'unprepared_fish', 'UnpreparedFish'}},
    [df.item_type.EGG] = {{'egg', 'Eggs'}},
    [df.item_type.PLANT] = {{'plants', 'Plants'}},
    [df.item_type.DRINK] = {{'drink_plant', 'PlantDrink'},
                          {'drink_animal', 'CreatureDrink'}},
    [df.item_type.CHEESE] = {{'cheese_plant', 'PlantCheese'},
                           {'cheese_animal', 'CreatureCheese'}},
    [df.item_type.SEEDS] = {{'seeds', 'Seed'}},
    [df.item_type.PLANT_GROWTH] = {{'leaves', 'PlantGrowth'}},
    [df.item_type.POWDER_MISC] = {{'powder_plant', 'PlantPowder'},
                                {'powder_creature', 'CreaturePowder'}},
    [df.item_type.GLOB] = {{'glob', 'Glob'}, {'glob_paste', 'Paste'},
                         {'glob_pressed', 'Pressed'}},
    [df.item_type.LIQUID_MISC] = {{'liquid_plant', 'PlantLiquid'},
                                {'liquid_animal', 'CreatureLiquid'},
                                {'liquid_misc', 'MiscLiquid'}},
}

-- threads and cloth are gated by which organic class the material is in
local CLOTH_SPECS = {
    [df.item_type.THREAD] = {{'thread_silk', 'Silk'},
                            {'thread_plant', 'PlantFiber'},
                            {'thread_yarn', 'Yarn'},
                            {'thread_metal', 'MetalThread'}},
    [df.item_type.CLOTH] = {{'cloth_silk', 'Silk'},
                           {'cloth_plant', 'PlantFiber'},
                           {'cloth_yarn', 'Yarn'},
                           {'cloth_metal', 'MetalThread'}},
}

-- corpsepiece materials that have their own per-race toggle in the
-- refuse filter; pieces of other materials must pass all of them
local PIECE_PART_VEC = {
    SKULL='skulls', BONE='bones', HAIR='hair', SHELL='shells',
    TOOTH='teeth', HORN='horns', HOOF='horns',
}

-- a category that was never opened in the pile UI leaves its quality
-- arrays entirely unset; like an empty vector, that means all allowed
local function all_unset(vec)
    for i = 0, #vec - 1 do
        if vec[i] ~= 0 and vec[i] ~= false and vec[i] ~= nil then
            return false
        end
    end
    return true
end

-- core quality covers the item itself; total quality covers each
-- improvement. undecorated items count their own quality as total
local function quality_ok(item, params)
    if all_unset(params.quality_core) and all_unset(params.quality_total) then
        return true
    end
    local q = item:getQuality()
    if not (vget(params.quality_core, q) and vget(params.quality_total, q)) then
        return false
    end
    -- improvements only exist on item_constructed subclasses
    if df.item_constructed:is_instance(item) then
        for _, imp in ipairs(item.improvements) do
            if not vget(params.quality_total, imp.quality) then
                return false
            end
        end
    end
    return true
end

-- usable/unusable needs civ-context we cannot read reliably, so a pile
-- that restricts it is a reject. both-unset again means unconfigured =
-- all allowed
local function unrestricted(a, b)
    return (a and b) or (not a and not b)
end

-- the dye on an item is a COLORATION improvement whose dye material
-- reports the stockpile color index via mill_dye_color. returns the
-- color index, false when undyed, nil when dyed but undecidable
local function dye_color(item)
    if not df.item_constructed:is_instance(item) then return false end
    for _, imp in ipairs(item.improvements) do
        if imp:getType() == df.improvement_type.COLORATION then
            local info = dfhack.matinfo.decode(imp.dye_matgloss,
                imp.dye_material)
            if info and info.material then
                local c = info.material.mill_dye_color
                if c and c >= 0 then return c end
            end
            return nil
        end
    end
    return false
end

-- dyed/undyed is a real filter pair; equal values (both on or the
-- unconfigured both-off) accept everything. an unreadable dye still
-- counts as dyed -- the coloration improvement exists even when its
-- profile is empty
local function dye_ok(item, params)
    if params.dyed == params.undyed then return true end
    return (dye_color(item) ~= false) == params.dyed
end

-- the color vector gates the dye color of dyed goods; undyed items
-- carry no dye color so they pass. when the dye cannot be resolved,
-- only a fully-enabled vector is provably compatible
local function colors_ok(item, params)
    if all_unset(params.color) then return true end
    local c = dye_color(item)
    if c == false then return true end
    if c ~= nil then return vget(params.color, c) end
    for i = 0, #params.color - 1 do
        if params.color[i] == 0 or params.color[i] == false then
            return false
        end
    end
    return true
end

-- does the pile's filter provably accept this item? DF exposes no
-- item-vs-filter check, so this re-implements matching for every
-- category whose settings have usable indices: stone, wood,
-- bars/blocks, gems, coins, weapons/trapcomps/ammo, armor, furniture,
-- finished goods, food, leather, cloth, sheets, corpses, corpse
-- pieces/remains, and caged/trapped animals. Anything we cannot prove is
-- rejected, so a wrong answer never mis-stores an item; it only means
-- fewer extras are grabbed. Exported for tests.
function pile_accepts(pile, item)
    if not pile or df.isvalid(pile) ~= 'ref' then return false end
    -- a links-only pile only receives items delivered via its links;
    -- opportunistic extras would violate that intent
    if pile.stockpile_flag.use_links_only then return false end
    local s = pile.settings
    local f = s.flags
    local it = item:getType()
    -- the raw field names differ per item class; the vmethods always work
    local mi = item:getMaterialIndex()
    local st = item:getSubtype()
    local info = dfhack.matinfo.decode(item)

    if it == df.item_type.BOULDER then
        return f.stone and item:getMaterial() == 0
            and vget(s.stone.mats, mi)
    elseif it == df.item_type.WOOD then
        if not f.wood then return false end
        -- wood.mats is indexed by plant raw index, not material index
        return info ~= nil and info.plant ~= nil
            and vget(s.wood.mats, info.plant.index)
    elseif it == df.item_type.BAR then
        return f.bars_blocks and mat_ok(item, info, s.bars_blocks.bars_mats,
            s.bars_blocks.bars_other_mats, df.stockpile_bar_mat)
    elseif it == df.item_type.BLOCKS then
        return f.bars_blocks and mat_ok(item, info, s.bars_blocks.blocks_mats,
            s.bars_blocks.blocks_other_mats, df.stockpile_block_mat)
    elseif it == df.item_type.ROUGH then
        if not f.gems then return false end
        -- other_mats is indexed by mat_type for non-inorganic roughs
        if item:getMaterial() == 0 then return vget(s.gems.rough_mats, mi) end
        return vget(s.gems.rough_other_mats, item:getMaterial())
    elseif it == df.item_type.GEM or it == df.item_type.SMALLGEM then
        if not f.gems then return false end
        if item:getMaterial() == 0 then return vget(s.gems.cut_mats, mi) end
        return vget(s.gems.cut_other_mats, item:getMaterial())
    elseif it == df.item_type.COIN then
        return f.coins and item:getMaterial() == 0
            and vget(s.coins.mats, mi)
    elseif it == df.item_type.WEAPON or it == df.item_type.TRAPCOMP then
        local p = s.weapons
        return f.weapons and unrestricted(p.usable, p.unusable)
            and vget(it == df.item_type.WEAPON
                and p.weapon_type or p.trapcomp_type, st)
            and quality_ok(item, p)
            and mat_ok(item, info, p.mats, p.other_mats,
                df.stockpile_weapon_mat)
    elseif it == df.item_type.AMMO then
        local p = s.ammo
        return f.ammo and vget(p.type, st) and quality_ok(item, p)
            and mat_ok(item, info, p.mats, p.other_mats,
                df.stockpile_ammo_mat)
    elseif it == df.item_type.ARMOR or it == df.item_type.HELM
            or it == df.item_type.SHOES or it == df.item_type.GLOVES
            or it == df.item_type.PANTS or it == df.item_type.SHIELD then
        local p = s.armor
        local vec = it == df.item_type.ARMOR and p.body
            or it == df.item_type.HELM and p.head
            or it == df.item_type.SHOES and p.feet
            or it == df.item_type.GLOVES and p.hands
            or it == df.item_type.PANTS and p.legs
            or p.shield
        return f.armor and unrestricted(p.usable, p.unusable)
            and dye_ok(item, p)
            and vget(vec, st) and quality_ok(item, p)
            and colors_ok(item, p)
            and mat_ok(item, info, p.mats, p.other_mats,
                df.stockpile_armor_mat)
    end

    if it == df.item_type.FOOD then
        -- prepared meals are a single toggle, not a vector
        return f.food and s.food.prepared_meals == true
    end
    local fspec = FOOD_SPECS[it]
    if fspec then
        if not f.food then return false end
        for _, spec in ipairs(fspec) do
            local pos = organic_item_pos(spec[2], item)
            if pos and vget(s.food[spec[1]], pos) then return true end
        end
        return false
    end

    if it == df.item_type.SKIN_TANNED then
        local p = s.leather
        local pos = organic_item_pos('Leather', item)
        return f.leather and pos ~= nil and vget(p.mats, pos)
            and dye_ok(item, p) and colors_ok(item, p)
    end
    local cspec = CLOTH_SPECS[it]
    if cspec then
        local p = s.cloth
        if not f.cloth then return false end
        if not dye_ok(item, p) or not colors_ok(item, p) then
            return false
        end
        for _, spec in ipairs(cspec) do
            local pos = organic_item_pos(spec[2], item)
            if pos and vget(p[spec[1]], pos) then return true end
        end
        return false
    end
    if it == df.item_type.SHEET then
        if not f.sheet then return false end
        local pos = organic_item_pos('Paper', item)
        if pos and vget(s.sheet.paper, pos) then return true end
        pos = organic_item_pos('Parchment', item)
        return pos ~= nil and vget(s.sheet.parchment, pos)
    end
    if it == df.item_type.CORPSE then
        -- citizen corpses are graveyard-bound, wildlife goes to refuse;
        -- either filter accepting the race means DF stores it there
        if f.corpses and vget(s.corpses.corpses, item.race) then
            return true
        end
        return f.refuse and vget(s.refuse.type, it)
            and vget(s.refuse.corpses, item.race)
    end
    if it == df.item_type.CORPSEPIECE or it == df.item_type.REMAINS then
        if not (f.refuse and vget(s.refuse.type, it)) then
            return false
        end
        local race = item.race
        if not vget(s.refuse.body_parts, race) then return false end
        -- pieces of specific part materials must also pass that part's
        -- per-race toggle; raw hide has its own freshness flags
        local mat_id = info and info.material and info.material.id
        if mat_id == 'SKIN' then
            return s.refuse[item.flags.rotten
                and 'rotten_raw_hide' or 'fresh_raw_hide']
        end
        local vec = mat_id and PIECE_PART_VEC[mat_id]
        if vec then return vget(s.refuse[vec], race) end
        -- unrecognized part material: only provably allowed when the
        -- race is enabled in every part-kind vector
        for _, v in ipairs({'skulls', 'bones', 'hair', 'shells', 'teeth',
                'horns'}) do
            if not vget(s.refuse[v], race) then return false end
        end
        return true
    end
    if it == df.item_type.CAGE or it == df.item_type.ANIMALTRAP then
        if f.animals then
            local unit
            for _, ref in ipairs(item.general_refs) do
                if df.general_ref_contains_unitst:is_instance(ref) then
                    unit = df.unit.find(ref.unit_id)
                    break
                end
            end
            if unit then
                if vget(s.animals.enabled, unit.race) then return true end
            elseif (it == df.item_type.CAGE and s.animals.empty_cages)
                    or (it == df.item_type.ANIMALTRAP
                        and s.animals.empty_traps) then
                return true
            end
        end
        -- cages and traps without an accepted occupant may still be
        -- storable as furniture, so fall through
    end

    -- furniture and finished goods have type-indexed vectors that only
    -- hold true for types in their category, so a single generic check
    -- covers every member type; TOOL items are skipped because their
    -- furniture_type slot depends on itemdef flags we cannot map
    local ft = df.furniture_type[df.item_type[it]]
    if f.furniture and ft and ft >= 0 and vget(s.furniture.type, ft) then
        return quality_ok(item, s.furniture)
            and mat_ok(item, info, s.furniture.mats, s.furniture.other_mats,
                df.stockpile_furniture_mat)
    end
    if f.finished_goods and vget(s.finished_goods.type, it) then
        return dye_ok(item, s.finished_goods)
            and quality_ok(item, s.finished_goods)
            and colors_ok(item, s.finished_goods)
            and mat_ok(item, info, s.finished_goods.mats,
                s.finished_goods.other_mats, df.stockpile_finished_mat)
    end
    return false
end

-- the item is already claimed by a job; true only if that job is also
-- delivering it to the given destination
local function claimed_for_dest(item, dest)
    if not item.flags.in_job then return false end
    for _,sref in ipairs(item.specific_refs) do
        if sref.type == df.specific_ref_type.JOB and sref.data.job
                and df.isvalid(sref.data.job) == 'ref' then
            local job = sref.data.job
            if job.job_type == df.job_type.StoreItemInStockpile
                    and dest.pile
                    and get_job_stockpile(job) == dest.pile then
                return true
            end
            if dest.container then
                local other = get_job_dest(job)
                if other and other.container == dest.container then
                    return true
                end
            end
        end
    end
    return false
end

local function extra_ok(cand, anchor, dest, origin, radius,
        taken_weight, cap)
    local f = cand.flags
    if cand.id == anchor.id or not f.on_ground or f.in_inventory
            or f.in_building or f.forbid or f.owned or f.hostile
            or f.trader or f.spider_web or f.construction or f.encased
            or f.removed or f.garbage_collect or f.rotten or f.dump
            or f.melt or f.hidden or f.on_fire
            or not near(cand.pos, origin, radius)
            or contained_in(cand) then
        return false
    end
    if f.in_job then
        -- claimed item: only valid if a job is already taking it to our
        -- destination (lets one trip do several jobs' work)
        if s_types == 'same' or not claimed_for_dest(cand, dest) then
            return false
        end
    else
        -- unclaimed items: 'same' and 'all' only take the anchor's type
        -- (a real job claim is the only trustworthy signal there);
        -- 'pile' also takes anything the destination filter provably
        -- accepts
        if cand:getType() ~= anchor:getType() then
            if not (s_types == 'pile' and dest.pile
                    and pile_accepts(dest.pile, cand)) then
                return false
            end
        end
        if stockpile_assigned(cand)
                or dfhack.buildings.findAtTile(
                    cand.pos.x, cand.pos.y, cand.pos.z) then
            return false
        end
    end
    if cap > 0 and cand.weight
            and taken_weight + cand.weight.whole > cap then
        return false
    end
    return true
end

local function held_by(unit, item)
    for _,e in ipairs(unit.inventory) do
        if e.item == item then return true end
    end
end

-- find the stockpile tile nearest to pos, or nil if pos is far from the pile
local function nearest_pile_tile(pile, pos, max_dist)
    if not pile or df.isvalid(pile) ~= 'ref' then return nil end
    local best, best_dist
    for x = pile.x1, pile.x2 do
        for y = pile.y1, pile.y2 do
            local d = math.abs(x - pos.x) + math.abs(y - pos.y)
                + 50 * math.abs(pile.z - pos.z)
            if (not best_dist or d < best_dist)
                    and dfhack.buildings.findAtTile(x, y, pile.z) == pile then
                best, best_dist = xyz2pos(x, y, pile.z), d
            end
        end
    end
    return (best_dist and best_dist <= max_dist) and best or nil
end

-- did the job's primary item actually reach the destination?
local function primary_delivered(t, primary)
    if t.pile then
        return primary and df.isvalid(primary) == 'ref'
            and dfhack.buildings.findAtTile(
                primary.pos.x, primary.pos.y, primary.pos.z) == t.pile
    end
    -- containers: a stored item can merge into a stack inside the container
    -- and be deleted, so a missing anchor counts as delivered
    if not primary or df.isvalid(primary) ~= 'ref' then return true end
    return contained_in(primary) == t.container
end

-- release all piggybacked items. If the job completed normally, land the
-- extras at the destination too: on the primary's pile tile (or the nearest
-- pile tile if the unit finished next to the pile, e.g. vehicle handoffs),
-- or inside the container. Otherwise drop them at the unit's feet.
local function release_all(unit_id)
    local t = tracked[unit_id]
    if not t then return end
    tracked[unit_id] = nil

    local unit = df.unit.find(unit_id)
    local drop_pos
    local container
    local primary = t.primary_id and df.item.find(t.primary_id)
    if t.pile then
        if primary_delivered(t, primary) then
            drop_pos = primary.pos
        elseif unit then
            drop_pos = nearest_pile_tile(t.pile, unit.pos, 4) or unit.pos
        end
    elseif t.container then
        if primary_delivered(t, primary)
                and df.isvalid(t.container) == 'ref' then
            container = t.container
        elseif unit then
            drop_pos = unit.pos
        end
    end
    for item_id, item in pairs(t.extras) do
        t.extras[item_id] = nil
        -- if a real job claimed the extra in the meantime its in_job flag
        -- is legitimate; leave it alone
        if df.isvalid(item) == 'ref' and not real_job_claim(item) then
            item.flags.in_job = false
            if container then
                -- insert items the unit still holds, and any the engine
                -- dropped at the unit's feet during the handoff
                if unit and (held_by(unit, item)
                        or near(item.pos, unit.pos, 4)) then
                    if not dfhack.items.moveToContainer(item, container) then
                        dfhack.items.moveToGround(item, unit.pos)
                    end
                end
                -- otherwise it was dropped mid-route: leave it there
            elseif unit and drop_pos then
                if held_by(unit, item) then
                    dfhack.items.moveToGround(item, drop_pos)
                elseif t.pile and item.flags.on_ground
                        and near(item.pos, drop_pos, 4) then
                    -- dropped by the engine at the destination
                    dfhack.items.moveToGround(item, drop_pos)
                end
            end
        end
    end
end

local function attached_count(t)
    local n = 0
    for _ in pairs(t.extras) do n = n + 1 end
    return n
end

local function item_weight(item)
    return (item and item.weight) and item.weight.whole or 0
end

-- 'weight auto': derive a per-unit carry cap from strength scaled by body
-- size (a child or small race carries less). A typical dwarf (~1200
-- strength) can manage ~900 units -- roughly three boulders of load.
local AUTO_CAP_FACTOR = 0.75
local AUTO_CAP_FALLBACK = 900

local function unit_carry_cap(unit)
    local ok, cap = pcall(function()
        local attrs = unit.body.physical_attrs
        local str = attrs.STRENGTH and attrs.STRENGTH.value or 0
        local base = unit.body.size_info.size_base
        local cur = unit.body.size_info.size_cur
        local ratio = (base and base > 0) and (cur / base) or 1
        ratio = math.max(0.25, math.min(ratio, 1.5))
        return math.floor(str * ratio * AUTO_CAP_FACTOR)
    end)
    return (ok and cap > 0) and cap or AUTO_CAP_FALLBACK
end

-- 0 = unlimited, 'auto' = per-unit, >0 = fixed cap
local function effective_weight_cap(unit)
    if s_weight == 'auto' then return unit_carry_cap(unit) end
    return s_weight
end

-- attach extras near origin until the count and weight caps are reached,
-- nearest first
local function grab_extras(t, unit, dest, anchor, origin, radius)
    local cands = {}
    for _,cand in ipairs(df.global.world.items.other[
            df.items_other_id.IN_PLAY]) do
        if near(cand.pos, origin, radius) then
            cands[#cands+1] = cand
        end
    end
    table.sort(cands, function(a, b)
        return math.abs(a.pos.x - origin.x) + math.abs(a.pos.y - origin.y)
            < math.abs(b.pos.x - origin.x) + math.abs(b.pos.y - origin.y)
    end)
    local cap = effective_weight_cap(unit)
    for _,cand in ipairs(cands) do
        if attached_count(t) >= s_max then break end
        if extra_ok(cand, anchor, dest, origin, radius, t.weight, cap)
                and dfhack.items.moveToInventory(
                    cand, unit, df.inv_item_role_type.Hauled, -1) then
            cand.flags.in_job = true
            t.extras[cand.id] = cand
            t.weight = t.weight + item_weight(cand)
        end
    end
end

local function scan_unit(unit)
    local job = unit.job.current_job
    local t = tracked[unit.id]

    -- drop tracking if the job ended or changed
    if t and (not job or job.id ~= t.job_id) then
        release_all(unit.id)
        t = nil
    end

    if not job then return end
    local dest = get_job_dest(job)
    if not dest then return end
    local anchor = dest.anchor
    if not anchor or df.isvalid(anchor) ~= 'ref' then return end

    local ready
    if dest.pile or job.job_type == df.job_type.StoreItemInVehicle then
        -- wait until the anchor item is actually picked up
        ready = anchor.flags.in_inventory and held_by(unit, anchor)
    else
        -- barrel/bin jobs: the dwarf carries the container to the goods;
        -- grab extras once the dwarf reaches the goods
        ready = near(unit.pos, anchor.pos, math.max(s_radius, 2))
    end
    if not ready then return end

    if not t then
        -- weight covers the whole carried load: the primary item, the
        -- container itself for barrel/bin runs, and every extra
        local weight = item_weight(anchor)
        if job.job_type == df.job_type.StoreItemInBarrel
                or job.job_type == df.job_type.StoreItemInBin then
            weight = weight + item_weight(dest.container)
        end
        t = {job_id=job.id, primary_id=anchor.id, pile=dest.pile,
             container=dest.container, extras={}, weight=weight,
             scan_cd=5}
        tracked[unit.id] = t
        -- the dwarf detours around the pickup site to collect extras
        grab_extras(t, unit, dest, anchor, anchor.pos, s_fetch)
    else
        -- the game drops non-job-linked hauled items; keep re-attaching our
        -- extras while the job is in flight so they ride along
        for item_id, extra in pairs(t.extras) do
            local valid = df.isvalid(extra) == 'ref'
            local real_claim = valid and real_job_claim(extra)
            if not valid or real_claim or extra.flags.forbid
                    or extra.flags.removed
                    or stockpile_assigned(extra) then
                if valid and not real_claim then
                    extra.flags.in_job = false
                end
                t.extras[item_id] = nil
            elseif t.pile and extra.flags.on_ground
                    and dfhack.buildings.findAtTile(
                        extra.pos.x, extra.pos.y, extra.pos.z) == t.pile then
                -- the game dropped it directly inside the pile: done
                extra.flags.in_job = false
                t.extras[item_id] = nil
            elseif t.container and contained_in(extra) == t.container then
                -- it is already inside the destination container: done
                extra.flags.in_job = false
                t.extras[item_id] = nil
            elseif not extra.flags.in_inventory then
                if dfhack.items.moveToInventory(
                        extra, unit, df.inv_item_role_type.Hauled, -1) then
                    extra.flags.in_job = true
                end
            end
        end
        -- opportunistically pick up more extras the dwarf walks past,
        -- throttled to every few polls
        t.scan_cd = (t.scan_cd or 0) - 1
        if t.scan_cd <= 0 and attached_count(t) < s_max then
            t.scan_cd = 5
            grab_extras(t, unit, dest, anchor, unit.pos, s_radius)
        end
    end
end

-- self-healing sweep: our extras carry only the in_job flag, never a JOB
-- specific_ref. If the tracking table is ever lost (script reload, env
-- reset) a dropped extra would keep that flag forever and become
-- unclaimable. Clear any in_job flag that has no job behind it and is not
-- a currently-tracked extra.
local function sweep_orphans()
    local riding = {}
    for _,t in pairs(tracked) do
        for id in pairs(t.extras) do riding[id] = true end
    end
    for _,item in ipairs(df.global.world.items.all) do
        if item.flags.in_job and not riding[item.id]
                and not real_job_claim(item) then
            item.flags.in_job = false
        end
    end
end

local sweep_countdown = 0

local function event_loop()
    if not enabled then return end
    for _,unit in ipairs(dfhack.units.getCitizens()) do
        local ok, err = pcall(scan_unit, unit)
        if not ok then
            dfhack.printerr(('multihaul: scan_unit(%d): %s\n'):format(
                unit.id, tostring(err)))
        end
    end
    sweep_countdown = sweep_countdown - 1
    if sweep_countdown <= 0 then
        sweep_countdown = 500
        local ok, err = pcall(sweep_orphans)
        if not ok then
            dfhack.printerr(('multihaul: sweep: %s\n'):format(tostring(err)))
        end
    end
    repeatutil.scheduleUnlessAlreadyScheduled(
        TIMER_NAME, POLL_FRAMES, 'frames', event_loop)
end

local function print_status()
    print(('multihaul is %s (max=%d, radius=%d, fetch=%d, weight=%s, types=%s, targets=%s)')
        :format(enabled and 'enabled' or 'disabled', s_max, s_radius, s_fetch,
            s_weight == 'auto' and 'auto'
                or (s_weight > 0 and tostring(s_weight) or 'unlimited'),
            s_types,
            s_targets_all and 'all' or 'piles'))
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc == SC_WORLD_UNLOADED or sc == SC_MAP_UNLOADED then
        -- best effort: unmark extras before the save is written so they
        -- don't persist with a bogus in_job flag
        for _,t in pairs(tracked) do
            for _,item in pairs(t.extras) do
                pcall(function()
                    if df.isvalid(item) == 'ref'
                            and not real_job_claim(item) then
                        item.flags.in_job = false
                    end
                end)
            end
        end
        tracked = {}
    elseif sc == SC_WORLD_LOADED then
        load_state()
        if enabled then event_loop() end
    end
end

if dfhack_flags.module then
    return
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
    table.insert(args, dfhack_flags.enable_state and 'enable' or 'disable')
end
local cmd = args[1]

if cmd == 'enable' then
    enabled = true
    persist_state()
    sweep_orphans()
    event_loop()
    print_status()
elseif cmd == 'disable' then
    enabled = false
    for unit_id in pairs(tracked) do release_all(unit_id) end
    repeatutil.cancel(TIMER_NAME)
    persist_state()
    print_status()
elseif cmd == 'max' then
    s_max = math.max(1, math.floor(tonumber(args[2]) or s_max))
    persist_state()
    print_status()
elseif cmd == 'radius' then
    s_radius = math.max(0, math.floor(tonumber(args[2]) or s_radius))
    persist_state()
    print_status()
elseif cmd == 'fetch' then
    s_fetch = math.max(0, math.floor(tonumber(args[2]) or s_fetch))
    persist_state()
    print_status()
elseif cmd == 'weight' then
    if args[2] == 'auto' then
        s_weight = 'auto'
    elseif args[2] == 'unlimited' then
        s_weight = 0
    else
        local n = tonumber(args[2])
        if not n then
            qerror('usage: multihaul weight <n>|auto|unlimited')
        end
        s_weight = math.max(0, math.floor(n))
    end
    persist_state()
    print_status()
elseif cmd == 'types' then
    if args[2] ~= 'same' and args[2] ~= 'all' and args[2] ~= 'pile' then
        qerror('usage: multihaul types same|all|pile')
    end
    s_types = args[2]
    persist_state()
    print_status()
elseif cmd == 'targets' then
    if args[2] ~= 'piles' and args[2] ~= 'all' then
        qerror('usage: multihaul targets piles|all')
    end
    s_targets_all = args[2] == 'all'
    persist_state()
    print_status()
elseif cmd == 'help' or cmd == '--help' then
    print(dfhack.script_help())
elseif cmd == 'status' or not cmd then
    print_status()
else
    qerror(('unknown command: %s'):format(cmd))
end
