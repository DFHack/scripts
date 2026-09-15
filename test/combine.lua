config.target = 'combine'

local combine = reqscript('combine')
local p = combine.unit_test_hooks

local POWDER_MISC = df.item_type.POWDER_MISC
local DRINK = df.item_type.DRINK

local function mock_item(item_type, fields)
    local item = {
        getType=function() return item_type end,
        isCrafted=function() return false end,
    }
    for k,v in pairs(fields) do item[k] = v end
    return item
end

local function mock_dye(color_index, materials)
    return mock_item(POWDER_MISC, {
        mat_type=0, mat_index=0,
        dye_profile={
            color_index=color_index,
            dye_material=materials,
            dye_matg={},
            degree={},
            target_index={},
        },
    })
end

function test.dye_same_profile_same_key()
    local stack_type = {type_id=POWDER_MISC}
    local dye_a = mock_dye(5, {10})
    local dye_b = mock_dye(5, {10})
    expect.eq(p.make_comp_key(stack_type, dye_a),
              p.make_comp_key(stack_type, dye_b))
end

function test.dye_different_color_different_key()
    local stack_type = {type_id=POWDER_MISC}
    local dye_a = mock_dye(5, {10})
    local dye_b = mock_dye(7, {10})
    expect.ne(p.make_comp_key(stack_type, dye_a),
              p.make_comp_key(stack_type, dye_b))
end

function test.dye_mix_different_key_than_component()
    -- a mixed dye shares mat_type/mat_index with its components but has a
    -- different dye_profile; it must not be merged into a component stack
    local stack_type = {type_id=POWDER_MISC}
    local dye_a = mock_dye(5, {10})
    local dye_mix = mock_dye(5, {10, 20})
    expect.ne(p.make_comp_key(stack_type, dye_a),
              p.make_comp_key(stack_type, dye_mix))
end

function test.powder_without_profile()
    -- non-dye powders have an empty/unset profile and still merge as before
    local stack_type = {type_id=POWDER_MISC}
    local p1 = mock_item(POWDER_MISC, {mat_type=1, mat_index=2})
    local p2 = mock_item(POWDER_MISC, {mat_type=1, mat_index=2})
    expect.eq(p.make_comp_key(stack_type, p1),
              p.make_comp_key(stack_type, p2))
end

function test.dye_key_ignores_other_types()
    local stack_type = {type_id=DRINK}
    local d1 = mock_item(DRINK, {mat_type=1, mat_index=2})
    local d2 = mock_item(DRINK, {mat_type=1, mat_index=2,
                               dye_profile={color_index=9, dye_material={1},
                                            dye_matg={}, degree={},
                                            target_index={}}})
    expect.eq(p.make_comp_key(stack_type, d1),
              p.make_comp_key(stack_type, d2))
end
