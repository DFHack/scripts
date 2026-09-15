config.target = 'idle-crafting'

local ic = reqscript('idle-crafting')
local p = ic.unit_test_hooks

local MakeCrafts = df.job_type.MakeCrafts
local CLOTH = df.item_type.CLOTH
local CLOTH_VEC = df.job_item_vector_id.CLOTH
local CLOTHESMAKER = df.unit_labor.CLOTHESMAKER
local STONE_CRAFT = df.unit_labor.STONE_CRAFT
local BONE_CARVE = df.unit_labor.BONE_CARVE

local function fake_matinfo(flag)
    local flags = {}
    if flag then flags[flag] = true end
    return {material={flags=flags}}
end

local function patched_jobs(fn)
    local made = {}
    mock.patch({{dfhack.job, 'createLinked',
                 function() local j = df.job:new(); table.insert(made, j); return j end},
                {dfhack.job, 'assignToWorkshop', mock.func()},
                {dfhack.job, 'addWorker', function() return true end}},
               function() fn(made) end)
end

function test.cloth_crafts_plant()
    patched_jobs(function(made)
        expect.true_(ic.makeClothCraft({}, {}, 'cloth'))
        local job = made[1]
        expect.eq(job.job_type, MakeCrafts)
        expect.true_(job.material_category.cloth)
        expect.false_(job.material_category.silk)
        expect.false_(job.material_category.yarn)
        local jitem = job.job_items.elements[0]
        expect.eq(jitem.item_type, CLOTH)
        expect.eq(jitem.vector_id, CLOTH_VEC)
        expect.eq(jitem.quantity, 1)
        expect.eq(jitem.mat_type, -1)
        expect.eq(jitem.mat_index, -1)
        expect.true_(jitem.flags2.plant)
        expect.false_(jitem.flags2.silk)
        expect.false_(jitem.flags2.yarn)
    end)
end

function test.cloth_crafts_silk()
    patched_jobs(function(made)
        expect.true_(ic.makeClothCraft({}, {}, 'silk'))
        local job = made[1]
        expect.true_(job.material_category.silk)
        expect.false_(job.material_category.cloth)
        local jitem = job.job_items.elements[0]
        expect.true_(jitem.flags2.silk)
        expect.false_(jitem.flags2.plant)
        expect.false_(jitem.flags2.yarn)
    end)
end

function test.cloth_crafts_yarn()
    patched_jobs(function(made)
        expect.true_(ic.makeClothCraft({}, {}, 'yarn'))
        local job = made[1]
        expect.true_(job.material_category.yarn)
        expect.false_(job.material_category.cloth)
        local jitem = job.job_items.elements[0]
        expect.true_(jitem.flags2.yarn)
        expect.false_(jitem.flags2.plant)
        expect.false_(jitem.flags2.silk)
    end)
end

function test.cloth_category_classification()
    local item = df.item_clothst:new()
    mock.patch({{dfhack.matinfo, 'decode',
                 function() return fake_matinfo('THREAD_PLANT') end}},
        function() expect.eq(p.cloth_category(item), 'cloth') end)
    mock.patch({{dfhack.matinfo, 'decode',
                 function() return fake_matinfo('SILK') end}},
        function() expect.eq(p.cloth_category(item), 'silk') end)
    mock.patch({{dfhack.matinfo, 'decode',
                 function() return fake_matinfo('YARN') end}},
        function() expect.eq(p.cloth_category(item), 'yarn') end)
    -- neither silk, yarn, nor plant-derived: not a usable craft cloth
    mock.patch({{dfhack.matinfo, 'decode',
                 function() return fake_matinfo() end}},
        function() expect.nil_(p.cloth_category(item)) end)
    mock.patch({{dfhack.matinfo, 'decode', function() return nil end}},
        function() expect.nil_(p.cloth_category(item)) end)
end

local function mock_workshop(blocked_labors)
    return {
        profile = {
            links = {take_from_pile={{id=1}}},
            blocked_labors = blocked_labors or {},
        },
        contained_items = {},
    }
end

-- pairs of {item, mat} so the real df objects stay field-free
local function with_stockpile_items(entries, fn)
    local items, mats = {}, {}
    for i, entry in ipairs(entries) do
        items[i] = entry.item
        mats[entry.item] = entry.mat
    end
    mock.patch({{dfhack.buildings, 'getStockpileContents',
                 function() return items end},
                {dfhack.matinfo, 'decode', function(item) return mats[item] end}},
               fn)
end

local function cloth_entry(mat)
    return {item=df.item_clothst:new(), mat=mat}
end

function test.select_picks_cloth_category()
    with_stockpile_items({cloth_entry(fake_matinfo('SILK'))}, function()
        patched_jobs(function(made)
            local job_fn = ic.select_crafting_job(mock_workshop())
            expect.true_(job_fn ~= nil)
            expect.true_(job_fn({}, {}))
            local job = made[1]
            expect.true_(job.material_category.silk)
            expect.true_(job.job_items.elements[0].flags2.silk)
        end)
    end)
end

function test.select_respects_blocked_clothesmaking()
    with_stockpile_items({cloth_entry(fake_matinfo('THREAD_PLANT'))}, function()
        local ws = mock_workshop({[CLOTHESMAKER]=true})
        expect.nil_(ic.select_crafting_job(ws))
    end)
end

function test.select_cloth_unaffected_by_other_blocked_labors()
    with_stockpile_items({cloth_entry(fake_matinfo('THREAD_PLANT'))}, function()
        local ws = mock_workshop({[STONE_CRAFT]=true, [BONE_CARVE]=true})
        local job_fn = ic.select_crafting_job(ws)
        expect.true_(job_fn ~= nil)
    end)
end
