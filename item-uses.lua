-- Lists all workshops and tasks where a specific item can be used.
--[====[

item-uses
=========

Tags: fort | inspection

This script analyzes the selected item and determines exactly which workshops
can accept it as a reagent, and what reactions or tasks can be performed with it.
It automatically distinguishes between raw materials (like ores or logs) and finished
goods, as well as checking for applicable tasks like encrusting, melting, and milling.

Usage
-----

    item-uses

Select an item in the game UI (e.g. using the ``k`` cursor, or viewing an item
in a stockpile or inventory) and run the command. The script will output a
categorized list of all compatible workshops and their relevant tasks.

]====]

local item = dfhack.gui.getSelectedItem(true)
if not item then qerror('Select an item first!') end

local desc = dfhack.items.getReadableDescription(item)
local item_type = item:getType()
local item_subtype = item:getSubtype()
local mat_type = item:getMaterial()
local mat_index = item:getMaterialIndex()
local mi = dfhack.matinfo.decode(item)
local material = mi and mi.material or nil

local uses = {}
local function add_use(workshop, task)
    if not uses[workshop] then uses[workshop] = {} end
    for _, v in ipairs(uses[workshop]) do if v == task then return end end
    table.insert(uses[workshop], task)
end

-- Helper: check material reaction product
local function mat_has_product(mat, pid)
    if not mat then return false end
    local ok, r = pcall(function()
        for i = 0, #mat.reaction_product.id - 1 do
            if tostring(mat.reaction_product.id[i].value) == pid then return true end
        end
        return false
    end)
    return ok and r or false
end

-- Helper: check material reaction class
local function mat_has_class(mat, cname)
    if not mat then return false end
    local ok, r = pcall(function()
        for i = 0, #mat.reaction_class - 1 do
            if tostring(mat.reaction_class[i].value) == cname then return true end
        end
        return false
    end)
    return ok and r or false
end

local function has_flag(name)
    if not material then return false end
    local ok, v = pcall(function() return material.flags[name] end)
    return ok and v
end

-- Map enum names to readable workshop names
local workshop_readable = {
    None='Workshop', Carpenters="Carpenter's workshop", Farmers="Farmer's workshop",
    Masons="Mason's workshop", Craftsdwarfs="Craftsdwarf's workshop",
    Jewelers="Jeweler's workshop", MetalsmithsForge="Metalsmith's forge",
    MagmaForge="Magma forge", Bowyers="Bowyer's workshop",
    Mechanics="Mechanic's workshop", Siege='Siege workshop',
    Butchers="Butcher's shop", Leatherworks='Leatherworks',
    Tanners="Tanner's shop", Clothiers="Clothier's shop",
    Fishery='Fishery', Still='Still', Loom='Loom', Quern='Quern',
    Kennels='Kennels', Kitchen='Kitchen', Ashery='Ashery',
    Dyers="Dyer's shop", Millstone='Millstone', Tool='Tool workshop',
}
local furnace_readable = {
    WoodFurnace='Wood furnace', Smelter='Smelter', GlassFurnace='Glass furnace',
    Kiln='Kiln', MagmaSmelter='Magma smelter',
    MagmaGlassFurnace='Magma glass furnace', MagmaKiln='Magma kiln',
}

local BTYPE_WORKSHOP = tonumber(df.building_type.Workshop)
local BTYPE_FURNACE = tonumber(df.building_type.Furnace)

local function get_workshop_name(r)
    local count = 0
    pcall(function() count = #r.building.type end)
    if count == 0 then return 'Unknown workshop' end

    for idx = 0, count - 1 do
        local name = nil
        pcall(function()
            local btype = tonumber(r.building.type[idx])
            local st = tonumber(r.building.subtype[idx])
            local custom = tonumber(r.building.custom[idx])

            if btype == BTYPE_WORKSHOP then
                local enum_name = df.workshop_type[st]
                if enum_name and enum_name ~= 'Custom' then
                    name = workshop_readable[enum_name] or enum_name
                elseif custom and custom >= 0 then
                    name = df.global.world.raws.buildings.all[custom].name
                end
            elseif btype == BTYPE_FURNACE then
                local enum_name = df.furnace_type[st]
                if enum_name and enum_name ~= 'Custom' then
                    name = furnace_readable[enum_name] or enum_name
                elseif custom and custom >= 0 then
                    name = df.global.world.raws.buildings.all[custom].name
                end
            end
        end)
        if name and #name > 0 then return name end
    end
    return 'Unknown workshop'
end

-- Container/tool reagent codes to skip
local skip_codes = {
    ['barrel/pot']=true, ['barrel']=true, ['pot']=true, ['jug']=true,
    ['container']=true, ['bucket']=true, ['bag']=true, ['empty container']=true,
    ['lye-bearing item']=true, ['anvil']=true, ['die']=true,
}

---------------------------------------------------------------------------
-- 1. BUILT-IN USES (material flags)
---------------------------------------------------------------------------
-- Raw material item types (where "make items from X" applies)
local raw_material_types = {}
for _, tname in ipairs({
    'WOOD','BAR','BOULDER','BLOCKS','SKIN_TANNED','CLOTH','THREAD','ROUGH',
    'SMALLGEM','BONE','SHELL','GLOB','PLANT','PLANT_GROWTH','MEAT',
    'FISH_RAW','SEEDS','LIQUID_MISC','POWDER_MISC','CHEESE','EGG',
}) do
    local v = df.item_type[tname]
    if v then raw_material_types[v] = true end
end
local is_raw = raw_material_types[item_type] or false

if has_flag('EDIBLE_RAW') then add_use('General', 'Eat raw') end
if has_flag('EDIBLE_COOKED') then
    add_use('Kitchen', 'Cook in meal (easy/fine/lavish)')
end
if has_flag('ALCOHOL_PLANT') and is_raw then add_use('Still', 'Brew drink from plant') end
if has_flag('IS_DYE') then
    add_use("Dyer's shop", 'Dye thread')
    add_use("Dyer's shop", 'Dye cloth')
end
-- "Make items from X" uses gated behind raw material types
if has_flag('WOOD') and is_raw then
    add_use("Carpenter's workshop", 'Make wooden items/furniture')
    add_use('Wood furnace', 'Make charcoal/ash')
end
if has_flag('IS_METAL') then
    if is_raw then add_use("Metalsmith's forge", 'Forge metal items') end
    add_use('Smelter', 'Melt metal item')  -- any metal item can be melted
end
if has_flag('IS_STONE') and is_raw then
    add_use("Mason's workshop", 'Construct stone furniture/blocks')
    add_use("Craftsdwarf's workshop", 'Make stone crafts')
end
if has_flag('LEATHER') and is_raw then add_use('Leatherworks', 'Make leather items') end
if has_flag('BONE') and is_raw then add_use("Craftsdwarf's workshop", 'Make bone crafts') end
if has_flag('SHELL') and is_raw then add_use("Craftsdwarf's workshop", 'Make shell crafts') end
if has_flag('POWDER_MISC_PLANT') and is_raw then add_use('Millstone/Quern', 'Mill plant') end
if has_flag('LIQUID_MISC_PLANT') and is_raw then add_use('Still', 'Extract from plants') end
if has_flag('SOAP') then add_use('Hospital', 'Use for cleaning') end
if has_flag('IS_GLASS') and is_raw then add_use('Glass furnace', 'Make glass items') end

-- Encrusting: finished goods can be encrusted with gems at Jeweler's
if not is_raw and not (item_type == df.item_type.DRINK or item_type == df.item_type.COIN) then
    add_use("Jeweler's workshop", 'Encrust with gem')
end

-- Material reaction products
if mat_has_product(material, 'DRINK_MAT') then add_use('Still', 'Brew drink') end
if mat_has_product(material, 'BAG_ITEM') and is_raw then add_use("Farmer's workshop", 'Process plant to bag') end
if mat_has_product(material, 'THREAD') and is_raw then add_use("Farmer's workshop", 'Process plant to thread') end
if mat_has_product(material, 'MILL_MAT') and is_raw then add_use('Millstone/Quern', 'Mill into powder') end
if mat_has_product(material, 'PRESS_LIQUID_MAT') and is_raw then add_use('Screw press', 'Press liquid') end
if mat_has_product(material, 'CHEESE_MAT') and is_raw then add_use("Farmer's workshop", 'Make cheese') end
if mat_has_product(material, 'RENDER_MAT') then add_use('Kitchen', 'Render fat') end
if mat_has_product(material, 'SOAP_MAT') and is_raw then add_use("Soap maker's workshop", 'Make soap') end
if mat_has_product(material, 'DYE_MAT') and item_type == df.item_type.PLANT then
    add_use('Millstone/Quern', 'Mill into dye')
    add_use("Dyer's shop", 'Use as dye (after milling)')
end

---------------------------------------------------------------------------
-- 2. PLANT FLAGS
---------------------------------------------------------------------------
if mi and mi.plant then
    local function has_pflag(n)
        local ok, v = pcall(function() return mi.plant.flags[n] end)
        return ok and v
    end
    -- These plant flags only apply to PLANT items (not growths)
    local is_plant = (item_type == df.item_type.PLANT)
    if has_pflag('DRINK') and is_plant then add_use('Still', 'Brew drink from plant') end
    if has_pflag('EDIBLE_GROWTH') and item_type == df.item_type.PLANT_GROWTH then
        -- Growth is only cookable if its own material has EDIBLE_COOKED
        if has_flag('EDIBLE_COOKED') or has_flag('EDIBLE_RAW') then
            add_use('Kitchen', 'Cook in meal (edible growth)')
        end
    end
    if has_pflag('MILL') and is_plant then add_use('Millstone/Quern', 'Mill plant') end
    if has_pflag('THREAD') and is_plant then add_use("Farmer's workshop", 'Process to thread') end
    if has_pflag('EXTRACT_BARREL') and is_plant then add_use('Still', 'Extract to barrel') end
    if has_pflag('EXTRACT_VIAL') and is_plant then add_use('Still', 'Extract to vial') end
    if has_pflag('DRY') and is_plant then add_use("Farmer's workshop", 'Process plant (dry)') end
end

-- Growth material checks
if item_type == df.item_type.PLANT_GROWTH then
    pcall(function()
        local plant_raw = df.global.world.raws.plants.all[mat_index]
        local growth = plant_raw.growths[item_subtype]
        local gmi = dfhack.matinfo.decode(growth.mat_type, growth.mat_index)
        if gmi and gmi.material then
            -- DYE_MAT milling only applies to PLANT items, not growths
            if mat_has_product(gmi.material, 'DRINK_MAT') then
                add_use('Still', 'Brew drink from growth')
            end
        end
    end)
end

---------------------------------------------------------------------------
-- 3. ITEM TYPE USES
---------------------------------------------------------------------------
if item_type == df.item_type.PLANT then
    add_use("Farmer's workshop", 'Process plant')
elseif item_type == df.item_type.SEEDS then
    add_use('Farm plot', 'Plant seeds')
elseif item_type == df.item_type.BOULDER then
    add_use("Mason's workshop", 'Construct furniture')
    add_use("Craftsdwarf's workshop", 'Make crafts')
elseif item_type == df.item_type.ROUGH then
    add_use("Jeweler's workshop", 'Cut rough gem')
elseif item_type == df.item_type.SMALLGEM then
    add_use("Jeweler's workshop", 'Encrust with gem')
elseif item_type == df.item_type.WOOD then
    add_use("Carpenter's workshop", 'Make wooden furniture/items')
    add_use('Wood furnace', 'Make charcoal/ash')
    add_use("Bowyer's workshop", 'Make crossbow')
elseif item_type == df.item_type.CLOTH then
    add_use("Clothier's shop", 'Make clothing')
    add_use("Dyer's shop", 'Dye cloth')
elseif item_type == df.item_type.THREAD then
    add_use('Loom', 'Weave into cloth')
    add_use("Dyer's shop", 'Dye thread')
elseif item_type == df.item_type.SKIN_TANNED then
    add_use('Leatherworks', 'Make leather items')
elseif item_type == df.item_type.MEAT then
    add_use('Kitchen', 'Cook in meal')
elseif item_type == df.item_type.FISH_RAW then
    add_use('Fishery', 'Prepare raw fish')
elseif item_type == df.item_type.EGG then
    add_use('Kitchen', 'Cook in meal')
    add_use('Nest box', 'Hatch (if fertile)')
elseif item_type == df.item_type.GLOB then
    add_use('Kitchen', 'Render fat / Cook tallow')
elseif item_type == df.item_type.CHEESE then
    add_use('Kitchen', 'Cook in meal')
elseif item_type == df.item_type.DRINK then
    add_use('Tavern', 'Drink')
elseif item_type == df.item_type.BAR then
    if has_flag('IS_METAL') then
        add_use("Metalsmith's forge", 'Forge weapons/armor/items')
    end
    if has_flag('SOAP') then add_use('Hospital', 'Cleaning') end
elseif item_type == df.item_type.BLOCKS then
    add_use('Construction', 'Build walls/floors/stairs')
end

add_use('Trade depot', 'Trade with merchants')

---------------------------------------------------------------------------
-- 4. REACTION MATCHING (with proper filtering)
---------------------------------------------------------------------------
for _, r in ipairs(df.global.world.raws.reactions.reactions) do
    -- Find the primary (first non-container) reagent and match against it
    local primary_ir = nil
    for _, reagent in ipairs(r.reagents) do
        if df.reaction_reagent_itemst:is_instance(reagent) then
            local code = ''
            pcall(function() code = reagent.code end)
            if not skip_codes[code] then
                primary_ir = reagent
                break
            end
        end
    end
    if not primary_ir then goto next_reaction end

    do
        local ir = primary_ir

        -- Item type check
        if ir.item_type ~= -1 and ir.item_type ~= item_type then goto next_reaction end

        -- Item subtype check
        if ir.item_subtype ~= -1 and ir.item_subtype ~= item_subtype then goto next_reaction end

        -- Material type check
        if ir.mat_type ~= -1 and ir.mat_type ~= mat_type then goto next_reaction end

        -- Material index check
        if ir.mat_index ~= -1 and ir.mat_index ~= mat_index then goto next_reaction end

        -- If BOTH item_type and mat_type are -1 (accepts anything),
        -- require at least has_material_reaction_product or reaction_class
        local has_hmrp = false
        local hmrp_val = nil
        pcall(function()
            if ir.has_material_reaction_product and #ir.has_material_reaction_product > 0 then
                has_hmrp = true
                hmrp_val = ir.has_material_reaction_product
            end
        end)

        local has_rc = false
        local rc_val = nil
        pcall(function()
            if ir.reaction_class and #ir.reaction_class > 0 then
                has_rc = true
                rc_val = ir.reaction_class
            end
        end)

        -- Skip overly generic reagents (both type and mat are wildcard, no extra filters)
        if ir.item_type == -1 and ir.mat_type == -1 and not has_hmrp and not has_rc then
            goto next_reaction
        end

        -- Verify has_material_reaction_product
        if has_hmrp then
            if not mat_has_product(material, hmrp_val) then goto next_reaction end
        end

        -- Verify reaction_class
        if has_rc then
            if not mat_has_class(material, rc_val) then goto next_reaction end
        end

        -- Match!
        add_use(get_workshop_name(r), r.name)
    end

    ::next_reaction::
end

---------------------------------------------------------------------------
-- 5. OUTPUT
---------------------------------------------------------------------------
print('')
print(('=== Uses for: %s ==='):format(desc))
print(('    Type: %s | Material: %s'):format(
    df.item_type[item_type], mi and mi:getToken() or '?'))
print('')

local names = {}
for n in pairs(uses) do table.insert(names, n) end
table.sort(names)

local total = 0
for _, ws in ipairs(names) do
    local tasks = uses[ws]
    table.sort(tasks)
    print(('  %s:'):format(ws))
    for _, t in ipairs(tasks) do
        print(('    - %s'):format(t))
        total = total + 1
    end
end
print(('\n  Total: %d uses across %d workshops'):format(total, #names))
