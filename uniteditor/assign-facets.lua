-- Change the facets of a unit.
--@ module = true

local help = [====[

assign-facets
=============
A script to change the facets (traits) of a unit.

Facets are defined with a token and a number from -3 to 3, which describes
the different levels of facets strength, as explained here:
`<https://dwarffortresswiki.org/index.php/DF2014:Personality_trait#Facets>`_

Strength | Effect
-------- | ------
   3     | Highest
   2     | Very High
   1     | High
   0     | Neutral
  -1     | Low
  -2     | Very Low
  -3     | Lowest

Resetting a facet means setting it to a level that does not
trigger a report in the "Thoughts and preferences" screen.

Usage:
* ``-help``:
                    print the help page.

* ``-unit <UNIT_ID>``:
                    set the target unit ID. If not present, the
                    currently selected unit will be the target.

* ``-beliefs <FACET LEVEL [FACET LEVEL] [...]>``:
                    the facets to modify and their levels. The
                    valid facet tokens can be found in the wiki page
                    linked above; level values range from -3 to 3.

* ``-reset``:
                    reset all facets to a neutral level. If the script is
                    called with both this option and a list of facets/levels,
                    first all the unit facets will be reset and then those
                    facets listed after ``-facets`` will be modified.

Example:
``-reset -facets HATE_PROPENSITY -2 CHEER_PROPENSITY -1``
Resets all the unit facets, then sets the listed facets to the following values:
* Hate propensity: a value between 10 and 24 (level -2);
* Cheer propensity: a value between 25 and 39 (level -1).
The final result (for a dwarf) will be:
``She very rarely develops negative feelings
toward things. She is rarely happy or enthusiastic,
and she is conflicted by this as she values
parties and merrymaking in the abstract.``

Note that the facets are compared to the beliefs,
and if conflicts arise they will be reported.
]====]

local valid_args = {
    HELP = "-help",
    UNIT = "-unit",
    FACETS = "-facets",
    RESET = "-reset",
}

-- ----------------------------------------------- UTILITY FUNCTIONS ------------------------------------------------ --
local function print_yellow(text)
    dfhack.color(COLOR_YELLOW)
    print(text)
    dfhack.color(-1)
end

-- ------------------------------------------------- ASSIGN FACETS -------------------------------------------------- --
-- -- NOTE: in the game data, facets are called traits.

--- Assign the given facets to a unit, resetting all the other facets if requested.
---   :facets: nil, or a table. The fields have the facet name as key and its level as value.
---   :unit: a valid unit id, a df.unit object, or nil. If nil, the currently selected unit will be targeted.
---   :reset: boolean, or nil.
function assign(facets, unit, reset)
    assert(not facets or type(facets) == "table")
    assert(not unit or type(unit) == "number" or type(unit) == "userdata")
    assert(not reset or type(reset) == "boolean")

    facets = facets or {}
    reset = reset or false

    if type(unit) == "number" then
        unit = df.unit.find(tonumber(unit))
    end
    unit = unit or dfhack.gui.getSelectedUnit(true)
    if not unit then
        qerror("No unit found.")
    end

    --- Calculate a random value within the desired facet strength level
    local function calculate_random_facet_strength(facet_level)
        local facets_levels = {
            -- {minimum level value, maximum level value}
            { 0, 9 }, -- -3: lowest
            { 10, 24 }, -- -2: very low
            { 25, 39 }, -- -1: low
            { 40, 60 }, -- 0: neutral
            { 61, 75 }, -- 1: high
            { 76, 90 }, -- 2: very high
            { 91, 100 } -- 3: highest
        }
        local lvl = facets_levels[facet_level + 4]
        return math.random(lvl[1], lvl[2])
    end

    -- reset facets
    if reset then
        for i, _ in pairs(unit.status.current_soul.personality.traits) do
            local value = calculate_random_facet_strength(0)
            unit.status.current_soul.personality.traits[i] = value
        end
    end

    --assign facets
    for facet, level in pairs(facets) do
        assert(type(level) == "number")
        facet = facet:upper()
        if df.personality_facet_type[facet] then
            if level >= -3 and level <= 3 then
                local facet_strength = calculate_random_facet_strength(level)
                unit.status.current_soul.personality.traits[facet] = facet_strength
            else
                print_yellow("WARNING: level out of range for facet '" .. level .. "'. Skipping...")
            end
        else
            print_yellow("WARNING: '" .. facet .. "' is not a valid facet token. Skipping...")
        end
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
    local facets
    local reset = false

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
        elseif arg == valid_args.FACETS then
            -- initialise facet/level table: it'll be useful later
            facets = {}
        elseif arg == valid_args.RESET then
            reset = true
        elseif facets then
            -- if the facets table is initialised, then we already encountered the "-facets" arg and this arg
            -- will probably be a facet name or a level value
            if not tonumber(arg) then
                local facet_name = tostring(arg):upper()
                -- assume it's a valid facet name, now check if the next arg is a valid level
                local level_str = args[i + 1]
                if not level_str then
                    -- we reached the end of the arguments list
                    qerror("Missing level value after '" .. arg .. "'.")
                end
                local level_int = tonumber(level_str)
                if not level_int then
                    qerror("'" .. level_str .. "' is not a valid number.")
                end
                if level_int >= -3 and level_int <= 3 then
                    facets[facet_name] = level_int
                    i = i + 1 -- skip next arg because we already consumed it
                else
                    qerror("Level " .. level_int .. " out of range.")
                end
            end
        else
            qerror("'" .. arg .. "' is not a valid argument.")
        end
        i = i + 1 -- go to the next argument
    end

    assign(facets, unit_id, reset)
end

if not dfhack_flags.module then
    main(...)
end