-- unit tests for multihaul's pile_accepts destination filter matcher.
-- piles and items are plain mock tables; df enums and the organic
-- material raws come from the real loaded world.

config = {mode = 'fortress', target = 'multihaul'}

local m = reqscript('multihaul')

-- a 0-based settings vector: keys 0..n-1 hold values, a dummy entry at
-- n makes #vec == n so bounds checks behave like df vectors. an empty
-- table stays empty, matching the "never configured = allow all"
-- lazy-fill semantics the matcher relies on
local function vec(vals)
    local t, n = {}, 0
    for i in pairs(vals or {}) do
        if i + 1 > n then n = i + 1 end
    end
    for i = 0, n - 1 do t[i] = vals[i] or 0 end
    if n > 0 then t[n] = 0 end
    return t
end

local function mock_item(itype, opts)
    opts = opts or {}
    local item = {
        id = opts.id or 1,
        flags = opts.flags or {},
        general_refs = {},
        pos = {x=0, y=0, z=0},
        race = opts.race or 0,
        caste = opts.caste or 0,
        improvements = opts.improvements,
    }
    function item:getType() return itype end
    function item:getMaterial() return opts.mat or -1 end
    function item:getMaterialIndex() return opts.mindx or -1 end
    function item:getSubtype() return opts.subtype or -1 end
    function item:getQuality() return opts.quality or 0 end
    function item:isWheelbarrow() return false end
    return item
end

local function base_flags()
    return {stone=false, wood=false, gems=false, bars_blocks=false,
            coins=false, weapons=false, armor=false, ammo=false,
            furniture=false, finished_goods=false, food=false,
            leather=false, cloth=false, sheet=false, refuse=false,
            corpses=false, animals=false}
end

-- real stockpile_settings always carries every category struct and
-- every vector field, so the mock does too: a missing key yields the
-- shared empty vector, matching "never configured" semantics
local EMPTY = {}
local function empty_category()
    return setmetatable({}, {__index=function() return EMPTY end})
end
local CATEGORY_KEYS = {'stone', 'wood', 'gems', 'bars_blocks', 'coins',
    'weapons', 'armor', 'ammo', 'furniture', 'finished_goods', 'food',
    'leather', 'cloth', 'sheet', 'refuse', 'corpses', 'animals'}

local function mock_pile(flags, settings, use_links_only)
    local s = {flags=flags}
    for _, k in ipairs(CATEGORY_KEYS) do s[k] = empty_category() end
    s.misc = {allow_organic=true, allow_inorganic=true}
    for k, v in pairs(settings or {}) do
        s[k] = setmetatable(v, {__index=function() return EMPTY end})
    end
    return {stockpile_flag={use_links_only=use_links_only or false},
            settings=s}
end

-- df and dfhack are read-only, so pile_accepts's df.isvalid and
-- dfhack.matinfo.decode calls are redirected by patching the module
-- env's own bindings with proxy tables
local INFO_MAP = {}
local DF_PROXY = setmetatable(
    {isvalid=function() return 'ref' end,
     -- is_instance errors on plain mock tables, so the check for
     -- improvement-bearing items is proxied to the improvements field
     item_constructed={is_instance=function(_, item)
         return item.improvements ~= nil
     end}},
    {__index=df})
local MATINFO_PROXY = setmetatable(
    {decode=function(item) return INFO_MAP[item] end},
    {__index=dfhack.matinfo})
local DFHACK_PROXY = setmetatable(
    {matinfo=MATINFO_PROXY},
    {__index=dfhack})

local function with_info(info_map, fn)
    INFO_MAP = info_map
    fn()
end

local function run(fn)
    mock.patch({{m, 'df', DF_PROXY}, {m, 'dfhack', DFHACK_PROXY}}, fn)
end

-- find a real (mat_type, mat_index) pair occupying position 0 of the
-- given organic category table, so tests ride on real raws
local function organic_pair(cat_name, pos)
    local cat = df.organic_mat_category[cat_name]
    local types = df.global.world.raws.mat_table.organic_types[cat]
    return types[pos or 0], df.global.world.raws.mat_table.organic_indexes[cat][pos or 0]
end

function test.links_only_rejects()
    run(function()
        local pile = mock_pile(base_flags(), {}, true)
        local item = mock_item(df.item_type.BOULDER, {mat=0, mindx=0})
        expect.false_(m.pile_accepts(pile, item))
    end)
end

function test.stone_boulder()
    run(function()
        local flags = base_flags()
        flags.stone = true
        -- only slot 2 enabled
        local mats = vec({[2]=1})
        local pile = mock_pile(flags, {stone={mats=mats}})
        local yes = mock_item(df.item_type.BOULDER, {mat=0, mindx=2})
        local no = mock_item(df.item_type.BOULDER, {mat=0, mindx=5})
        local organic = mock_item(df.item_type.BOULDER, {mat=42, mindx=1})
        expect.true_(m.pile_accepts(pile, yes))
        expect.false_(m.pile_accepts(pile, no))
        expect.false_(m.pile_accepts(pile, organic))
    end)
end

function test.stone_empty_vector_allows()
    -- a pile whose filter was never opened has an empty mats vector,
    -- which means "all allowed", not "none"
    run(function()
        local flags = base_flags()
        flags.stone = true
        local pile = mock_pile(flags, {stone={mats=vec({})}})
        local item = mock_item(df.item_type.BOULDER, {mat=0, mindx=37})
        expect.true_(m.pile_accepts(pile, item))
    end)
end

function test.flag_off_rejects()
    run(function()
        -- everything configured, but the category flag is off
        local pile = mock_pile(base_flags(), {stone={mats=vec({})}})
        local item = mock_item(df.item_type.BOULDER, {mat=0, mindx=0})
        expect.false_(m.pile_accepts(pile, item))
    end)
end

function test.wood_via_plant_index()
    run(function()
        local flags = base_flags()
        flags.wood = true
        local pile = mock_pile(flags, {wood={mats=vec({[3]=1})}})
        local item = mock_item(df.item_type.WOOD, {mat=419, mindx=10})
        -- decode reports a plant raw whose index is 3
        with_info({[item]={material={id='PLANT:TEST'}, plant={index=3}}},
            function()
                expect.true_(m.pile_accepts(pile, item))
            end)
        -- a non-plant "wood" cannot be verified: reject
        with_info({[item]=nil}, function()
            expect.false_(m.pile_accepts(pile, item))
        end)
    end)
end

function test.bar_metal_and_other()
    run(function()
        local flags = base_flags()
        flags.bars_blocks = true
        local pile = mock_pile(flags, {bars_blocks={
            bars_mats=vec({[7]=1}),
            bars_other_mats=vec({[df.stockpile_bar_mat.Soap]=1}),
        }})
        local metal = mock_item(df.item_type.BAR, {mat=0, mindx=7})
        local metal_no = mock_item(df.item_type.BAR, {mat=0, mindx=9})
        expect.true_(m.pile_accepts(pile, metal))
        expect.false_(m.pile_accepts(pile, metal_no))
        -- a soap bar: creature material whose id maps to the Soap slot
        local soap = mock_item(df.item_type.BAR, {mat=200, mindx=5})
        with_info({[soap]={material={id='SOAP'}}}, function()
            expect.true_(m.pile_accepts(pile, soap))
        end)
    end)
end

function test.food_meat()
    run(function()
        local flags = base_flags()
        flags.food = true
        local mtype, mindx = organic_pair('Meat')
        -- enable only position 0 of the meat vector
        local pile = mock_pile(flags, {food={meat=vec({[0]=1})}})
        local meat = mock_item(df.item_type.MEAT, {mat=mtype, mindx=mindx})
        expect.true_(m.pile_accepts(pile, meat))
        -- a meat item whose (type,index) maps to a disabled position
        local mtype2, mindx2 = organic_pair('Meat', 1)
        local meat2 = mock_item(df.item_type.MEAT, {mat=mtype2, mindx=mindx2})
        expect.false_(m.pile_accepts(pile, meat2))
    end)
end

function test.prepared_meals_toggle()
    run(function()
        local flags = base_flags()
        flags.food = true
        local meal = mock_item(df.item_type.FOOD)
        local on = mock_pile(flags, {food={prepared_meals=true}})
        local off = mock_pile(flags, {food={prepared_meals=false}})
        expect.true_(m.pile_accepts(on, meal))
        expect.false_(m.pile_accepts(off, meal))
    end)
end

function test.corpse_race_vector()
    run(function()
        local flags = base_flags()
        flags.refuse = true
        local type_vec = vec({})
        type_vec[df.item_type.CORPSE] = 1
        local corpses = vec({[526]=1})
        local pile = mock_pile(flags, {refuse={
            type=type_vec, corpses=corpses}})
        local yes = mock_item(df.item_type.CORPSE, {race=526})
        local no = mock_item(df.item_type.CORPSE, {race=7})
        expect.true_(m.pile_accepts(pile, yes))
        expect.false_(m.pile_accepts(pile, no))
        -- refuse.type entry off: reject even with the race enabled.
        -- an empty vector would mean "all allowed", so another slot
        -- is enabled to make the vector configured
        local type_vec2 = vec({})
        type_vec2 = vec({[df.item_type.REMAINS]=1})
        local pile2 = mock_pile(flags, {refuse={
            type=type_vec2, corpses=corpses}})
        expect.false_(m.pile_accepts(pile2, yes))
    end)
end

function test.corpsepiece_hide_freshness()
    run(function()
        local flags = base_flags()
        flags.refuse = true
        local type_vec = vec({})
        type_vec[df.item_type.CORPSEPIECE] = 1
        local parts = vec({[10]=1})
        local fresh = mock_pile(flags, {refuse={
            type=type_vec, body_parts=parts,
            fresh_raw_hide=true, rotten_raw_hide=false}})
        local rotten = mock_pile(flags, {refuse={
            type=type_vec, body_parts=parts,
            fresh_raw_hide=false, rotten_raw_hide=true}})
        local fresh_hide = mock_item(df.item_type.CORPSEPIECE,
            {race=10, mat=1, mindx=1, flags={rotten=false}})
        local rotten_hide = mock_item(df.item_type.CORPSEPIECE,
            {race=10, mat=1, mindx=1, flags={rotten=true}})
        local info = {material={id='SKIN'}}
        with_info({[fresh_hide]=info, [rotten_hide]=info}, function()
            expect.true_(m.pile_accepts(fresh, fresh_hide))
            -- a rotten hide must not fall through to the fresh toggle
            expect.false_(m.pile_accepts(fresh, rotten_hide))
            expect.true_(m.pile_accepts(rotten, rotten_hide))
            expect.false_(m.pile_accepts(rotten, fresh_hide))
        end)
    end)
end

function test.quality_unset_means_all()
    run(function()
        local flags = base_flags()
        flags.finished_goods = true
        local type_vec = vec({})
        type_vec[df.item_type.CROWN] = 1
        local pile = mock_pile(flags, {finished_goods={
            type=type_vec,
            quality_core=vec({}), quality_total=vec({}),
            mats=vec({}), other_mats=vec({}), color=vec({}),
        }})
        local item = mock_item(df.item_type.CROWN,
            {quality=4, mat=0, mindx=0})
        expect.true_(m.pile_accepts(pile, item))
    end)
end

function test.quality_restricted()
    run(function()
        local flags = base_flags()
        flags.finished_goods = true
        local type_vec = vec({})
        type_vec[df.item_type.CROWN] = 1
        -- only masterwork (quality 4) allowed
        local q = vec({[4]=1})
        local pile = mock_pile(flags, {finished_goods={
            type=type_vec, quality_core=q, quality_total=q,
            mats=vec({}), other_mats=vec({}), color=vec({}),
        }})
        local good = mock_item(df.item_type.CROWN,
            {quality=4, mat=0, mindx=0})
        local bad = mock_item(df.item_type.CROWN,
            {quality=1, mat=0, mindx=0})
        expect.true_(m.pile_accepts(pile, good))
        expect.false_(m.pile_accepts(pile, bad))
    end)
end

function test.dye_filters()
    run(function()
        local flags = base_flags()
        flags.finished_goods = true
        local type_vec = vec({})
        type_vec[df.item_type.CROWN] = 1
        local function pile(dyed, undyed, color)
            return mock_pile(flags, {finished_goods={
                type=type_vec, dyed=dyed, undyed=undyed,
                quality_core=vec({}), quality_total=vec({}),
                mats=vec({}), other_mats=vec({}), color=color or vec({}),
            }})
        end
        local imp = {}
        function imp:getType() return df.improvement_type.COLORATION end
        imp.dye_matgloss, imp.dye_material = -1, -1
        local dyed_item = mock_item(df.item_type.CROWN,
            {improvements={imp}, mat=0, mindx=0})
        local plain_item = mock_item(df.item_type.CROWN,
            {mat=0, mindx=0})
        do
            -- unrestricted pile takes both
            expect.true_(m.pile_accepts(pile(true, true), dyed_item))
            expect.true_(m.pile_accepts(pile(true, true), plain_item))
            -- unconfigured (both off) also takes both
            expect.true_(m.pile_accepts(pile(false, false), dyed_item))
            expect.true_(m.pile_accepts(pile(false, false), plain_item))
            -- dyed-only takes only the dyed item
            expect.true_(m.pile_accepts(pile(true, false), dyed_item))
            expect.false_(m.pile_accepts(pile(true, false), plain_item))
            -- undyed-only takes only the plain item
            expect.false_(m.pile_accepts(pile(false, true), dyed_item))
            expect.true_(m.pile_accepts(pile(false, true), plain_item))
            -- restricted colors reject a dye whose color is unreadable
            local colors = vec({[2]=1})
            expect.false_(m.pile_accepts(pile(true, true, colors),
                dyed_item))
            -- ...but undyed items carry no color and pass
            expect.true_(m.pile_accepts(pile(true, true, colors),
                plain_item))
        end
    end)
end

function test.usable_restriction_rejects()
    run(function()
        local flags = base_flags()
        flags.weapons = true
        -- usable-only is a restriction we cannot verify item-side
        local pile = mock_pile(flags, {weapons={
            usable=true, unusable=false,
            weapon_type=vec({}), trapcomp_type=vec({}),
            quality_core=vec({}), quality_total=vec({}),
            mats=vec({}), other_mats=vec({}),
        }})
        local item = mock_item(df.item_type.WEAPON,
            {subtype=1, mat=0, mindx=0})
        expect.false_(m.pile_accepts(pile, item))
        -- both enabled is no restriction
        local pile2 = mock_pile(flags, {weapons={
            usable=true, unusable=true,
            weapon_type=vec({}), trapcomp_type=vec({}),
            quality_core=vec({}), quality_total=vec({}),
            mats=vec({}), other_mats=vec({}),
        }})
        expect.true_(m.pile_accepts(pile2, item))
    end)
end

function test.empty_cage()
    run(function()
        local flags = base_flags()
        flags.animals = true
        local pile = mock_pile(flags, {animals={
            enabled=vec({}), empty_cages=true, empty_traps=false}})
        local cage = mock_item(df.item_type.CAGE)
        local trap = mock_item(df.item_type.ANIMALTRAP)
        expect.true_(m.pile_accepts(pile, cage))
        expect.false_(m.pile_accepts(pile, trap))
    end)
end

function test.furniture_type_and_material()
    run(function()
        local flags = base_flags()
        flags.furniture = true
        local ft = df.furniture_type[df.item_type[df.item_type.CHAIR]]
        local type_vec = vec({})
        type_vec[ft] = 1
        -- wooden materials disallowed via mats
        local pile = mock_pile(flags, {furniture={
            type=type_vec,
            quality_core=vec({}), quality_total=vec({}),
            mats=vec({}), other_mats=vec({[0]=1}), -- Wood only
        }})
        local chair = mock_item(df.item_type.CHAIR,
            {mat=419, mindx=5})
        -- the chair's material resolves to a wood (organic) material
        -- with no matching other_mats slot enabled: reject
        with_info({[chair]={material={id='PLANT:OAK'},
                            plant={index=1}}}, function()
            expect.false_(m.pile_accepts(pile, chair))
        end)
        -- inorganic chair with mats slot enabled: accept
        local mats = vec({[3]=1})
        local pile2 = mock_pile(flags, {furniture={
            type=type_vec,
            quality_core=vec({}), quality_total=vec({}),
            mats=mats, other_mats=vec({}),
        }})
        local stone_chair = mock_item(df.item_type.CHAIR,
            {mat=0, mindx=3})
        with_info({[stone_chair]={material={id='SLATE'}}}, function()
            expect.true_(m.pile_accepts(pile2, stone_chair))
        end)
    end)
end

function test.tool_furniture_buckets()
    run(function()
        local tools = df.global.world.raws.itemdefs.tools
        local function find_tool(pred)
            for i = 0, #tools - 1 do
                if pred(tools[i]) then return i end
            end
        end
        local function has_use(def, use)
            for _, u in ipairs(def.tool_use) do
                if u == use then return true end
            end
        end
        local wheelbarrow = find_tool(function(d)
            return has_use(d, df.tool_uses.HEAVY_OBJECT_HAULING)
        end)
        local bookcase = find_tool(function(d)
            return d.flags.FURNITURE and not has_use(d,
                df.tool_uses.HEAVY_OBJECT_HAULING)
                and not has_use(d, df.tool_uses.TRACK_CART)
                and not has_use(d, df.tool_uses.FOOD_STORAGE)
        end)
        expect.true_(wheelbarrow ~= nil)
        expect.true_(bookcase ~= nil)

        -- a furniture pile allowing only wheelbarrows
        local flags = base_flags()
        flags.furniture = true
        local wb_pile = mock_pile(flags, {furniture={
            type=vec({[df.furniture_type.WHEELBARROW]=1})}})
        local wb = mock_item(df.item_type.TOOL,
            {subtype=wheelbarrow, mat=0, mindx=0})
        local bk = mock_item(df.item_type.TOOL,
            {subtype=bookcase, mat=0, mindx=0})
        expect.true_(m.pile_accepts(wb_pile, wb))
        expect.false_(m.pile_accepts(wb_pile, bk))

        -- the same wheelbarrow must not leak into a finished-goods
        -- pile even when its TOOL slot is enabled
        local flags2 = base_flags()
        flags2.finished_goods = true
        local fg_vec = vec({})
        fg_vec[df.item_type.TOOL] = 1
        local fg_pile = mock_pile(flags2, {finished_goods={type=fg_vec}})
        expect.false_(m.pile_accepts(fg_pile, wb))

        -- a small tool (jug: no FURNITURE flag, no bucket use) is
        -- finished-goods only
        local jug = find_tool(function(d)
            return not d.flags.FURNITURE and #d.tool_use > 0
                and not has_use(d, df.tool_uses.HEAVY_OBJECT_HAULING)
                and not has_use(d, df.tool_uses.TRACK_CART)
                and not has_use(d, df.tool_uses.FOOD_STORAGE)
        end)
        expect.true_(jug ~= nil)
        local jug_item = mock_item(df.item_type.TOOL,
            {subtype=jug, mat=0, mindx=0})
        expect.true_(m.pile_accepts(fg_pile, jug_item))
        expect.false_(m.pile_accepts(wb_pile, jug_item))
    end)
end

function test.unhandled_type_rejects()
    run(function()
        local flags = base_flags()
        for k in pairs(flags) do flags[k] = true end
        local pile = mock_pile(flags, {})
        -- loose vermin have no provable home in any category
        local vermin = mock_item(df.item_type.VERMIN)
        expect.false_(m.pile_accepts(pile, vermin))
    end)
end

function test.misc_organic_gate()
    run(function()
        local flags = base_flags()
        flags.stone = true
        local no_organic = mock_pile(flags,
            {stone={mats=vec({})}},
            false)
        no_organic.settings.misc.allow_organic = false
        local no_inorg = mock_pile(flags, {stone={mats=vec({})}})
        no_inorg.settings.misc.allow_inorganic = false
        local rock = mock_item(df.item_type.BOULDER, {mat=0, mindx=2})
        -- inorganic item on an organic-forbidding pile: still fine
        expect.true_(m.pile_accepts(no_organic, rock))
        -- inorganic item on an inorganic-forbidding pile: rejected
        expect.false_(m.pile_accepts(no_inorg, rock))
        -- organic item on an organic-forbidding pile: rejected
        local log = mock_item(df.item_type.BOULDER, {mat=42, mindx=1})
        expect.false_(m.pile_accepts(no_organic, log))
    end)
end
