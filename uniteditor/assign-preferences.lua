-- Change the preferences of a unit.
--@ module = true

local help = [====[

assign-preferences
==================
A script to change the preferences of a unit.

Preferences are classified into 12 types. The first 9 are:
* like material;
* like creature;
* like food;
* hate creature;
* like item;
* like plant;
* like tree;
* like colour;
* like shape.

These can be changed using this script.

The remaining three are not currently managed by this script,
and are: like poetic form, like musical form, like dance form.

To produce the correct description in the "thoughts and preferences"
page, you must specify the particular type of preference. For
each type, a description is provided in the section below.

You will need to know the token of the object you want your dwarf to like.
Unless told otherwise, the best way to get those tokens is to activate
the plugin `stonesense`, load a world and let the plugin generate a file
named "MatList.csv" in the root DF folder. Browse this file (import it
as a .csv file with Excel or similar program) to get the desired token
(in the "id" column). Otherwise, in the folder "/raw/objects/" under
the main DF directory you will find all the raws defined in the game.

For more information:
`<https://dwarffortresswiki.org/index.php/DF2014:Preferences>`_.

Usage:
* ``-help``: print the help page.

* ``-unit <UNIT_ID>``:
                    set the target unit ID. If not present, the
                    currently selected unit will be the target.

* ``-likematerial <TOKEN [TOKEN] [...]>``:
                    usually a type of stone, a type of metal and a type
                    of gem, plus it can also be a type of wood, a type of
                    glass, a type of leather, a type of horn, a type of
                    pearl, a type of ivory, a decoration material - coral
                    or amber, a type of bone, a type of shell, a type
                    of silk, a type of yarn, or a type of plant cloth.
                    Write the tokens as found in the "id" column of the
                    file ""MatList.csv", generated as explained above.

* ``-likecreature <TOKEN [TOKEN] [...]>``:
                    one or more creatures liked by the unit. You can
                    just list the species: if you are using the file
                    "MatList.csv" as explained above, the creature token
                    will be something similar to `CREATURE:SPARROW:SKIN`,
                    so the name of the species will be `SPARROW`. Nothing
                    will stop you to write the full token, if you want: the
                    script will just ignore the first and the last parts.

* ``-likefood <TOKEN [TOKEN] [...]>``:
                    usually a type of alcohol, plus it can be a type of
                    meat, a type of fish, a type of cheese, a type of edible
                    plant, a cookable plant/creature extract, a cookable
                    mill powder, a cookable plant seed or a cookable plant
                    leaf. Write the tokens as found in the "id" column of
                    the file "MatList.csv", generated as explained above.

* ``-hatecreature <TOKEN [TOKEN] [...]>``:
                    works the same way as `-likecreature`, but this time
                    it's one or more creatures that the unit detests. They
                    should be a type of `HATEABLE` vermin which isn't already
                    explicitly liked, but no check is performed about this.
                    Like before, you can just list the creature species.

* ``-likeitem <TOKEN [TOKEN] [...]>``:
                    a kind of weapon, a kind of ammo, a kind of piece of
                    armor, a piece of clothing (including backpacks or
                    quivers), a type of furniture (doors, floodgates, beds,
                    chairs, windows, cages, barrels, tables, coffins,
                    statues, boxes, armor stands, weapon racks, cabinets,
                    bins, hatch covers, grates, querns, millstones, traction
                    benches, or slabs), a kind of craft (figurines, amulets,
                    scepters, crowns, rings, earrings, bracelets, or large
                    gems), or a kind of miscellaneous item (catapult parts,
                    ballista parts, a type of siege ammo, a trap component,
                    coins, anvils, totems, chains, flasks, goblets,
                    buckets, animal traps, an instrument, a toy, splints,
                    crutches, or a tool). The item tokens can be found here:
                    `<https://dwarffortresswiki.org/index.php/DF2014:Item_token>`_.
                    If you want to specify an item subtype, look into the files
                    listed under the column `Subtype` of the wiki page (they are
                    in the "/raw/ojects/" folder), then specify the items using 
                    the full tokens found in those files (see examples below).

* ``-likeplant <TOKEN [TOKEN] [...]``:
                    works in a similar way as `-likecreature`, this time
                    with plants. You can just List the plant species (the
                    middle part of the token as listed in "MatList.csv").

* ``-liketree <TOKEN [TOKEN] [...]``:
                    works exactly as `-likeplant`. I think this
                    preference type is here for backward compatibility (?).
                    You can still use it, however. As before,
                    you can just list the tree (plant) species.

* ``-likecolor <TOKEN [TOKEN] [...]``:
                    you can find the color tokens here:
                    `<https://dwarffortresswiki.org/index.php/DF2014:Color#Color_tokens>`_,
                    or inside the "descriptor_color_standard.txt" file
                    (in the "/raw/ojects/" folder). You can use the full token or
                    just the color name.

* ``-likeshape <TOKEN [TOKEN] [...]``:
                    I couldn't find a list of shape tokens in the wiki, but you
                    can find them inside the "descriptor_shape_standard.txt"
                    file (in the "/raw/ojects/" folder). You can
                    use the full token or just the shape name.

* ``-reset``:
                    clear all preferences. If the script is called
                    with both this option and one or more preferences,
                    first all the unit preferences will be cleared
                    and then the listed preferences will be added.

Examples:
``-reset -likematerial INORGANIC:OBSIDAN PLANT:WILLOW:WOOD``
> "likes alabaster and willow wood"

``-reset -likecreature SPARROW``
> "likes sparrows for their ..."

``-reset -likefood PLANT:MUSHROOM_HELMET_PLUMP:DRINK PLANT:OLIVE:FRUIT``
> "prefers to consume dwarven wine and olives"

``-reset -hatecreature SPIDER_JUMPING``
> "absolutely detests jumping spiders

``-reset -likeitem WOOD ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE``
> "likes logs and battle axes"

``-reset -likeplant BERRIES_STRAW``
> "likes straberry plants for their ..."

``-reset -liketree OAK``
> "likes oaks for their ..."

``-reset -likecolor AQUA``
> "likes the color aqua"

``-reset -likeshape STAR``
> "likes stars"
]====]

local utils = require("utils")

local valid_args = {
    HELP = "-help",
    UNIT = "-unit",
    LIKEMATERIAL = "-likematerial",
    LIKECREATURE = "-likecreature",
    LIKEFOOD = "-likefood",
    HATECREATURE = "-hatecreature",
    LIKEITEM = "-likeitem",
    LIKEPLANT = "-likeplant",
    LIKETREE = "-liketree",
    LIKECOLOR = "-likecolor",
    LIKESHAPE = "-likeshape",
    RESET = "-reset",
}

-- ----------------------------------------------- UTILITY FUNCTIONS ------------------------------------------------ --
local function print_yellow(text)
    dfhack.color(COLOR_YELLOW)
    print(text)
    dfhack.color(-1)
end

local function contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- initialise random number generator
local rng = dfhack.random.new()

-- ----------------------------------------------- ASSIGN PREFERENCES ----------------------------------------------- --
--[[
This table stores all the information needed to instantiate a new df.unit_preference object.
The keys are the names of the different types of preferences, the values are functions that
return a table with all the fields of a df.unit_preference object and their values.
I find it easier to just overwrite every single field instead of keeping track of the default
values assigned to the field at object creation.
--]]
local preference_functions = {
    -- ---------------- LIKEMATERIAL ---------------- --
    LIKEMATERIAL = function(token)
        local mat_info = dfhack.matinfo.find(token)
        if mat_info then
            return {
                type = df.unit_preference.T_type.LikeMaterial,
                item_type = -1,
                creature_id = -1,
                color_id = -1,
                shape_id = -1,
                plant_id = -1,
                poetic_form_id = -1,
                musical_form_id = -1,
                dance_form_id = -1,
                item_subtype = -1,
                mattype = mat_info.type,
                matindex = mat_info.index,
                mat_state = 0,
                active = true,
                prefstring_seed = rng:random()
            }
        else
            print_yellow("WARNING: '" .. token .. "' does not seem to be a valid material token. Skipping...")
            return {}
        end
    end,
    -- ---------------- LIKECREATURE ---------------- --
    LIKECREATURE = function(token)
        local creature_id
        local parts = utils.split_string(token, ":")
        if #parts == 1 then
            creature_id = parts[1]
        else
            creature_id = parts[2]
        end
        local index = utils.linear_index(df.global.world.raws.creatures.all, creature_id, "creature_id")
        if index then
            return {
                type = df.unit_preference.T_type.LikeCreature,
                item_type = index,
                creature_id = index,
                color_id = index,
                shape_id = index,
                plant_id = index,
                poetic_form_id = index,
                musical_form_id = index,
                dance_form_id = index,
                item_subtype = -1,
                mattype = -1,
                matindex = -1,
                mat_state = 0,
                active = true,
                prefstring_seed = rng:random()
            }
        else
            print_yellow("WARNING: '" .. token .. "' does not seem to be a valid creature token. Skipping...")
            return {}
        end
    end,
    -- ---------------- LIKEFOOD ---------------- --
    LIKEFOOD = function(token)
        local mat_info = dfhack.matinfo.find(token)
        if not mat_info then
            goto error
        end
        do
            local item_type
            local item_subtype = -1
            local food_mat_index = mat_info.material.food_mat_index
            -- FIXME: is fish missing? Apparently it's considered meat...
            if food_mat_index.Meat > -1 then
                item_type = df.item_type.MEAT
            elseif food_mat_index.EdibleCheese > -1 then
                item_type = df.item_type.CHEESE
            elseif food_mat_index.EdiblePlant > -1 then
                item_type = df.item_type.PLANT
            elseif food_mat_index.AnyDrink > -1 then
                item_type = df.item_type.DRINK
            elseif food_mat_index.CookableLiquid > -1 then
                item_type = df.item_type.LIQUID_MISC
            elseif food_mat_index.CookableSeed > -1 then
                item_type = df.item_type.SEEDS
            elseif food_mat_index.CookableLeaf > -1 then
                --[[
                In case of plant growths, "mat_info" stores the item type as a specific subtype ("FLOWER", or "FRUIT",
                etc.) instead of the generic "PLANT_GROWTH" item type. Also, the IDs of the different types of growths
                are sometimes stored in the plural form and sometimes in the singular form, so we need to know what to
                look for when we try to associate the item_type to the growth_id.
                --]]
                local growths = {
                    -- item_id = growth_id, as returned by dfhack.matinfo.find()
                    BULB = "BULBS",
                    FLOWER = "FLOWER",
                    LEAF = "LEAVES",
                    NUT = "NUT",
                    POD = "POD",
                    FRUIT = "FRUIT",
                }
                local item_type_str = mat_info.material.id
                if growths[item_type_str] then
                    local growth_id = growths[item_type_str]
                    for _, growth in ipairs(mat_info.plant.growths) do
                        if growth_id == growth.id then
                            item_type = growth.item_type
                            item_subtype = growth.item_subtype
                        end
                    end
                end
            end

            if item_type then
                return {
                    type = df.unit_preference.T_type.LikeFood,
                    item_type = item_type,
                    creature_id = item_type,
                    color_id = item_type,
                    shape_id = item_type,
                    plant_id = item_type,
                    poetic_form_id = item_type,
                    musical_form_id = item_type,
                    dance_form_id = item_type,
                    item_subtype = item_subtype,
                    mattype = mat_info.type,
                    matindex = mat_info.index,
                    mat_state = 1,
                    active = true,
                    prefstring_seed = rng:random()
                }
            end
        end

        :: error ::
        print_yellow("WARNING: '" .. token .. "' does not seem to be a valid food token. Skipping...")
        return {}
    end,
    -- ---------------- HATECREATURE ---------------- --
    HATECREATURE = function(token)
        local creature_id
        local parts = utils.split_string(token, ":")
        if #parts == 1 then
            creature_id = parts[1]
        else
            creature_id = parts[2]
        end
        local index = utils.linear_index(df.global.world.raws.creatures.all, creature_id, "creature_id")
        if index then
            return {
                type = df.unit_preference.T_type.HateCreature,
                item_type = index,
                creature_id = index,
                color_id = index,
                shape_id = index,
                plant_id = index,
                poetic_form_id = index,
                musical_form_id = index,
                dance_form_id = index,
                item_subtype = -1,
                mattype = -1,
                matindex = -1,
                mat_state = 0,
                active = true,
                prefstring_seed = rng:random()
            }
        else
            print_yellow("WARNING: '" .. token .. "' does not seem to be a valid creature token. Skipping...")
            return {}
        end
    end,
    -- ---------------- LIKEITEM ---------------- --
    LIKEITEM = function(token)
        local item_type
        local item_subtype = -1
        local parts = utils.split_string(token, ":")
        if #parts == 1 then
            item_type = df.item_type[parts[1]]
        else
            -- the token is someting like ITEM_WEAPON:ITEM_WEAPON_AXE_BATTLE
            item_type = df.item_type[string.gsub(parts[1], "^ITEM_", "")]
            local _, item = utils.linear_index(df.global.world.raws.itemdefs.all, parts[2], "id")
            if item then
                item_subtype = item.subtype
            else
                goto error
            end
        end
        do
            if item_type then
                return {
                    type = df.unit_preference.T_type.LikeItem,
                    item_type = item_type,
                    creature_id = item_type,
                    color_id = item_type,
                    shape_id = item_type,
                    plant_id = item_type,
                    poetic_form_id = item_type,
                    musical_form_id = item_type,
                    dance_form_id = item_type,
                    item_subtype = item_subtype,
                    mattype = -1,
                    matindex = -1,
                    mat_state = 0,
                    active = true,
                    prefstring_seed = rng:random()
                }
            end
        end

        :: error ::
        print_yellow("WARNING: '" .. token .. "' does not seem to be a valid item token. Skipping...")
        return {}
    end,
    -- ---------------- LIKEPLANT ---------------- --
    LIKEPLANT = function(token)
        local plant_id
        local parts = utils.split_string(token, ":")
        if #parts == 1 then
            plant_id = parts[1]
        else
            plant_id = parts[2]
        end
        local index = utils.linear_index(df.global.world.raws.plants.all, plant_id, "id")
        if index then
            return {
                type = df.unit_preference.T_type.LikePlant,
                item_type = index,
                creature_id = index,
                color_id = index,
                shape_id = index,
                plant_id = index,
                poetic_form_id = index,
                musical_form_id = index,
                dance_form_id = index,
                item_subtype = -1,
                mattype = -1,
                matindex = -1,
                mat_state = 0,
                active = true,
                prefstring_seed = rng:random()
            }
        else
            print_yellow("WARNING: '" .. token .. "' does not seem to be a valid plant token. Skipping...")
            return {}
        end
    end,
    -- ---------------- LIKETREE ---------------- --
    LIKETREE = function(token)
        local plant_id
        local parts = utils.split_string(token, ":")
        if #parts == 1 then
            plant_id = parts[1]
        else
            plant_id = parts[2]
        end
        local index = utils.linear_index(df.global.world.raws.plants.all, plant_id, "id")
        if index then
            return {
                type = df.unit_preference.T_type.LikeTree,
                item_type = index,
                creature_id = index,
                color_id = index,
                shape_id = index,
                plant_id = index,
                poetic_form_id = index,
                musical_form_id = index,
                dance_form_id = index,
                item_subtype = -1,
                mattype = -1,
                matindex = -1,
                mat_state = 0,
                active = true,
                prefstring_seed = rng:random()
            }
        else
            print_yellow("WARNING: '" .. token .. "' does not seem to be a valid plant token. Skipping...")
            return {}
        end
    end,
    -- ---------------- LIKECOLOR ---------------- --
    LIKECOLOR = function(token)
        local color_name
        local parts = utils.split_string(token, ":")
        if #parts == 1 then
            color_name = parts[1]
        else
            color_name = parts[2]
        end
        -- f.global.world.raws.descriptors.colors is ordered by id, we can use binary search
        local _, found, index = utils.binsearch(df.global.world.raws.descriptors.colors, color_name, "id")
        if found then
            return {
                type = df.unit_preference.T_type.LikeColor,
                item_type = index,
                creature_id = index,
                color_id = index,
                shape_id = index,
                plant_id = index,
                poetic_form_id = index,
                musical_form_id = index,
                dance_form_id = index,
                item_subtype = -1,
                mattype = -1,
                matindex = -1,
                mat_state = 0,
                active = true,
                prefstring_seed = rng:random()
            }
        else
            print_yellow("WARNING: '" .. token .. "' does not seem to be a valid color token. Skipping...")
            return {}
        end
    end,
    -- ---------------- LIKESHAPE ---------------- --
    LIKESHAPE = function(token)
        local shape_name
        local parts = utils.split_string(token, ":")
        if #parts == 1 then
            shape_name = parts[1]
        else
            shape_name = parts[2]
        end
        local index, _ = utils.linear_index(df.global.world.raws.descriptors.shapes, shape_name, "id")
        if index then
            return {
                type = df.unit_preference.T_type.LikeShape,
                item_type = index,
                creature_id = index,
                color_id = index,
                shape_id = index,
                plant_id = index,
                poetic_form_id = index,
                musical_form_id = index,
                dance_form_id = index,
                item_subtype = -1,
                mattype = -1,
                matindex = -1,
                mat_state = 0,
                active = true,
                prefstring_seed = rng:random()
            }
        else
            print_yellow("WARNING: '" .. token .. "' does not seem to be a valid shape token. Skipping...")
            return {}
        end
    end,
}

--- Assign the given preferences to a unit, clearing all the other preferences if requested.
---   :preferences: nil, or a table. The fields have the preference type as key and an array of reference tokens as value.
---   :unit: a valid unit id, a df.unit object, or nil. If nil, the currently selected unit will be targeted.
---   :reset: boolean, or nil.
function assign(preferences, unit, reset)
    assert(not preferences or type(preferences) == "table")
    assert(not unit or type(unit) == "number" or type(unit) == "userdata")
    assert(not reset or type(reset) == "boolean")

    preferences = preferences or {}
    reset = reset or false

    if type(unit) == "number" then
        unit = df.unit.find(tonumber(unit))
    end
    unit = unit or dfhack.gui.getSelectedUnit(true)
    if not unit then
        qerror("No unit found.")
    end

    -- clear preferences
    if reset then
        unit.status.current_soul.preferences = {}
    end

    -- assign preferences
    local unit_preferences = unit.status.current_soul.preferences -- store the userdata in a variable for convenience

    for preference_type, preference_tokens in pairs(preferences) do
        assert(type(preference_tokens) == "table")
        local funct = preference_functions[preference_type:upper()]
        for _, token in ipairs(preference_tokens) do
            assert(type(token) == "string")
            local new_preference = df.unit_preference:new()
            local values = funct(token:upper())
            for field, value in pairs(values) do
                if value then
                    new_preference[field] = value
                else
                    print_yellow("WARNING: unable to calculate a value for field '" .. field .. "'. Skipping...")
                    goto next_preference
                end
            end
            -- TODO: should we insert preferences following the order in which DF presents them?
            unit_preferences:insert(#unit_preferences, new_preference)
        end

        :: next_preference ::
    end
end

-- ------------------------------------------------------ MAIN ------------------------------------------------------ --
local function main(...)
    local args = { ... }

    if #args == 0 then
        print(help)
        return
    end

    local unit_id
    local preferences = {}
    local erase = false

    local i = 1
    while i <= #args do
        local arg = args[i]
        if arg == valid_args.HELP then
            print(help)
            return
        elseif arg == valid_args.UNIT then
            i = i + 1 -- consume next arg
            local unit_id_str = args[i]
            if not unit_id_str then
                -- we reached the end of the arguments list
                qerror("Missing unit id.")
            end
            unit_id = tonumber(unit_id_str)
            if not unit_id then
                qerror("'" .. unit_id_str .. "' is not a valid unit ID.")
            end
        elseif arg == valid_args.RESET then
            erase = true
            -- FIXME: we can surely use a function instead of rewriting the same "while" loop
        elseif arg == valid_args.LIKEMATERIAL then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                if not preferences.LIKEMATERIAL then
                    preferences["LIKEMATERIAL"] = {}
                end
                table.insert(preferences.LIKEMATERIAL, (args[i]:upper()))
            end
        elseif arg == valid_args.LIKECREATURE then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                if not preferences.LIKECREATURE then
                    preferences["LIKECREATURE"] = {}
                end
                table.insert(preferences.LIKECREATURE, (args[i]:upper()))
            end
        elseif arg == valid_args.LIKEFOOD then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                if not preferences.LIKEFOOD then
                    preferences["LIKEFOOD"] = {}
                end
                table.insert(preferences.LIKEFOOD, (args[i]:upper()))
            end
        elseif arg == valid_args.HATECREATURE then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                if not preferences.HATECREATURE then
                    preferences["HATECREATURE"] = {}
                end
                table.insert(preferences.HATECREATURE, (args[i]:upper()))
            end
        elseif arg == valid_args.LIKEITEM then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                if not preferences.LIKEITEM then
                    preferences["LIKEITEM"] = {}
                end
                table.insert(preferences.LIKEITEM, (args[i]:upper()))
            end
        elseif arg == valid_args.LIKEPLANT then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                if not preferences.LIKEPLANT then
                    preferences["LIKEPLANT"] = {}
                end
                table.insert(preferences.LIKEPLANT, (args[i]:upper()))
            end
        elseif arg == valid_args.LIKETREE then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                if not preferences.LIKETREE then
                    preferences["LIKETREE"] = {}
                end
                table.insert(preferences.LIKETREE, (args[i]:upper()))
            end
        elseif arg == valid_args.LIKECOLOR then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                if not preferences.LIKECOLOR then
                    preferences["LIKECOLOR"] = {}
                end
                table.insert(preferences.LIKECOLOR, (args[i]:upper()))
            end
        elseif arg == valid_args.LIKESHAPE then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                if not preferences.LIKESHAPE then
                    preferences["LIKESHAPE"] = {}
                end
                table.insert(preferences.LIKESHAPE, (args[i]:upper()))
            end
        else
            qerror("'" .. arg .. "' is not a valid argument.")
        end
        i = i + 1 -- go to the next argument
    end

    assign(preferences, unit_id, erase)
end

if not dfhack_flags.module then
    main(...)
end