-- convenient way to ban cooking categories of food
-- based on ban-cooking.rb by Putnam: https://github.com/DFHack/scripts/pull/427/files
-- Putnams work completed by TBSTeun

local argparse = require('argparse')

local kitchen = df.global.plotinfo.kitchen

local options = {}
local banned = {}
local count = 0

local function make_key(mat_type, mat_index, type, subtype)
    return ('%s:%s:%s:%s'):format(mat_type, mat_index, type, subtype)
end

local function ban_cooking(print_name, mat_type, mat_index, type, subtype)
    local key = make_key(mat_type, mat_index, type, subtype)
    -- Skip adding a new entry further below if there's nothing to do
    if (banned[key] and not options.unban) or (not banned[key] and options.unban) then
        return
    end
    -- The item hasn't already been (un)banned, so we do that here by appending/removing
    -- its values to/from the various arrays
    count = count + 1
    if options.verbose then
        print(print_name .. ' has been ' .. (options.unban and 'un' or '') .. 'banned!')
    end

    if options.unban then
        dfhack.kitchen.removeExclusion({Cook=true}, type, subtype, mat_type, mat_index)
        banned[key] = nil
    else
        dfhack.kitchen.addExclusion({Cook=true}, type, subtype, mat_type, mat_index)
        banned[key] = {
            mat_type=mat_type,
            mat_index=mat_index,
            type=type,
            subtype=subtype,
        }
    end
end

local function init_banned()
    -- Iterate over the elements of the kitchen.item_types list
    for i in ipairs(kitchen.item_types) do
        if kitchen.exc_types[i].Cook then
            local key = make_key(kitchen.mat_types[i], kitchen.mat_indices[i], kitchen.item_types[i], kitchen.item_subtypes[i])
            if not banned[key] then
                banned[key] = {
                    mat_type=kitchen.mat_types[i],
                    mat_index=kitchen.mat_indices[i],
                    type=kitchen.item_types[i],
                    subtype=kitchen.item_subtypes[i],
                }
            end
        end
    end
end

local funcs = {}

funcs.booze = function()
    for _, p in ipairs(df.global.world.raws.plants.all) do
        for _, m in ipairs(p.material) do
            if m.flags.ALCOHOL and m.flags.EDIBLE_COOKED then
                local matinfo = dfhack.matinfo.find(p.id, m.id)
                ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.DRINK, -1)
            end
        end
    end
    for _, c in ipairs(df.global.world.raws.creatures.all) do
        for _, m in ipairs(c.material) do
            if m.flags.ALCOHOL and m.flags.EDIBLE_COOKED then
                local matinfo = dfhack.matinfo.find(c.creature_id, m.id)
                ban_cooking(c.name[2] .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.DRINK, -1)
            end
        end
    end
end

funcs.honey = function()
    local mat = dfhack.matinfo.find("CREATURE:HONEY_BEE:HONEY")
    ban_cooking('honey bee honey', mat.type, mat.index, df.item_type.LIQUID_MISC, -1)
end

funcs.tallow = function()
    for _, c in ipairs(df.global.world.raws.creatures.all) do
        for _, m in ipairs(c.material) do
            if m.flags.EDIBLE_COOKED then
                for _, s in ipairs(m.reaction_product.id) do
                    if s.value == "SOAP_MAT" then
                        local matinfo = dfhack.matinfo.find(c.creature_id, m.id)
                        ban_cooking(c.name[2] .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.GLOB, -1)
                        break
                    end
                end
            end
        end
    end
end

funcs.milk = function()
    for _, c in ipairs(df.global.world.raws.creatures.all) do
        for _, m in ipairs(c.material) do
            if m.flags.EDIBLE_COOKED then
                for _, s in ipairs(m.reaction_product.id) do
                    if s.value == "CHEESE_MAT" then
                        local matinfo = dfhack.matinfo.find(c.creature_id, m.id)
                        ban_cooking(c.name[2] .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.LIQUID_MISC, -1)
                        break
                    end
                end
            end
        end
    end
end

funcs.oil = function()
    for _, p in ipairs(df.global.world.raws.plants.all) do
        for _, m in ipairs(p.material) do
            if m.flags.EDIBLE_COOKED then
                for _, s in ipairs(m.reaction_product.id) do
                    if s.value == "SOAP_MAT" then
                        local matinfo = dfhack.matinfo.find(p.id, m.id)
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.LIQUID_MISC, -1)
                        break
                    end
                end
            end
        end
    end
end

funcs.seeds = function()
    for _, p in ipairs(df.global.world.raws.plants.all) do
        if p.material_defs.type.seed == -1 or p.material_defs.idx.seed == -1 or p.flags.TREE then goto continue end
        ban_cooking(p.name .. ' seeds', p.material_defs.type.seed, p.material_defs.idx.seed, df.item_type.SEEDS, -1)
        for _, m in ipairs(p.material) do
            if m.id == "STRUCTURAL" and m.flags.EDIBLE_COOKED then
                local has_drink = false
                local has_seed = false
                for _, s in ipairs(m.reaction_product.id) do
                    has_seed = has_seed or s.value == "SEED_MAT"
                    has_drink = has_drink or s.value == "DRINK_MAT"
                end
                if has_seed and has_drink then
                    local matinfo = dfhack.matinfo.find(p.id, m.id)
                    ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT, -1)
                end
            end
        end
        for k, g in ipairs(p.growths) do
            local matinfo = dfhack.matinfo.decode(g)
            local m = matinfo.material
            if m.flags.EDIBLE_COOKED then
                local has_drink = false
                local has_seed = false
                for _, s in ipairs(m.reaction_product.id) do
                    has_seed = has_seed or s.value == "SEED_MAT"
                    has_drink = has_drink or s.value == "DRINK_MAT"
                end
                if has_seed and has_drink then
                    ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT_GROWTH, k)
                end
            end
        end

        ::continue::
    end
end

funcs.brew = function()
    for _, p in ipairs(df.global.world.raws.plants.all) do
        if p.material_defs.type.drink == -1 or p.material_defs.idx.drink == -1 then goto continue end
        for _, m in ipairs(p.material) do
            if m.id == "STRUCTURAL" and m.flags.EDIBLE_COOKED then
                for _, s in ipairs(m.reaction_product.id) do
                    if s.value == "DRINK_MAT" then
                        local matinfo = dfhack.matinfo.find(p.id, m.id)
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT, -1)
                        break
                    end
                end
            end
        end
        for k, g in ipairs(p.growths) do
            local matinfo = dfhack.matinfo.decode(g)
            local m = matinfo.material
            if m.flags.EDIBLE_COOKED then
                for _, s in ipairs(m.reaction_product.id) do
                    if s.value == "DRINK_MAT" then
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT_GROWTH, k)
                        break
                    end
                end
            end
        end

        ::continue::
    end
end

funcs.mill = function()
    for _, p in ipairs(df.global.world.raws.plants.all) do
        if p.material_defs.idx.mill ~= -1 then
            for _, m in ipairs(p.material) do
                if m.id == "STRUCTURAL" and m.flags.EDIBLE_COOKED then
                    local matinfo = dfhack.matinfo.find(p.id, m.id)
                    ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT, -1)
                end
            end
        end
    end
end

funcs.thread = function()
    for _, p in ipairs(df.global.world.raws.plants.all) do
        if p.material_defs.idx.thread == -1 then goto continue end
        for _, m in ipairs(p.material) do
            if m.id == "STRUCTURAL" and m.flags.EDIBLE_COOKED then
                for _, s in ipairs(m.reaction_product.id) do
                    if s.value == "THREAD" then
                        local matinfo = dfhack.matinfo.find(p.id, m.id)
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT, -1)
                        break
                    end
                end
            end
        end
        for k, g in ipairs(p.growths) do
            local matinfo = dfhack.matinfo.decode(g)
            local m = matinfo.material
            if m.flags.EDIBLE_COOKED then
                for _, s in ipairs(m.reaction_product.id) do
                    if s.value == "THREAD" then
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT_GROWTH, k)
                        break
                    end
                end
            end
        end

        ::continue::
    end
end

funcs.fruit = function()
    for _, p in ipairs(df.global.world.raws.plants.all) do
        for k, g in ipairs(p.growths) do
            local matinfo = dfhack.matinfo.decode(g)
            local m = matinfo.material
            if m.id == "FRUIT" and m.flags.EDIBLE_COOKED and m.flags.STOCKPILE_PLANT_GROWTH then
                for _, s in ipairs(m.reaction_product.id) do
                    if s.value == "DRINK_MAT" then
                        ban_cooking(p.name .. ' ' .. m.id, matinfo.type, matinfo.index, df.item_type.PLANT_GROWTH, k)
                        break
                    end
                end
            end
        end
    end
end

local classes = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() options.help = true end},
    {'u', 'unban', handler=function() options.unban = true end},
    {'v', 'verbose', handler=function() options.verbose = true end},
})

if options.help == true then
    print(dfhack.script_help())
    return
end

init_banned()

if classes[1] == 'all' then
    for _, func in pairs(funcs) do
        func()
    end
else
    for _, v in ipairs(classes) do
        if funcs[v] then
            funcs[v]()
        end
    end
end

print((options.unban and 'un' or '') .. 'banned ' .. count .. ' types.')
