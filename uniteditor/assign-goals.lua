-- Change the goals of a unit.
--@ module = true

local help = [====[

assign-goals
============
A script to change the goals (dreams) of a unit.

Goals are defined with the goal token and a true/false value
that describes whether or not the goal has been accomplished. Be
advised that this last feature has not been properly tested and
might be potentially destructive: I suggest leaving it at false.

For a list of possible goals:
`<https://dwarffortresswiki.org/index.php/DF2014:Personality_trait#Goals>`_.

Bear in mind that nothing will stop you from assigning zero or
more than one goal, but it's not clear how it will affect the game.

Usage:
* ``-help``:
                    print the help page.

* ``-unit <UNIT_ID>``:
                    set the target unit ID. If not present, the
                    currently selected unit will be the target.

* ``-goals <GOAL REALIZED_FLAG [GOAL REALIZED_FLAG] [...]>``:
                    the goals to modify/add and whether they have
                    been realized or not. The valid goal tokens
                    can be found in the wiki page linked above.

* ``-reset``:
                    clear all goals. If the script is called with
                    both this option and a list of goals, first all
                    the unit goals will be erased and then those
                    goals listed after ``-goals`` will be added.

Example:
``-reset -goals MASTER_A_SKILL false``
Clears all the unit goals, then sets the "master
a skill" goal. The final result will be:
``dreams of mastering a skill.``
]====]

local utils = require("utils")

local valid_args = {
    HELP = "-help",
    UNIT = "-unit",
    GOALS = "-goals",
    RESET = "-reset",
}

-- ----------------------------------------------- UTILITY FUNCTIONS ------------------------------------------------ --
local function print_yellow(text)
    dfhack.color(COLOR_YELLOW)
    print(text)
    dfhack.color(-1)
end

-- ------------------------------------------------- ASSIGN GOALS ------------------------------------------------- --
-- NOTE: in the game data, goals are called both dreams and goals.

--- Assign the given goals to a unit, clearing all the other goals if requested.
---   :goals: nil, or a table. The fields have the goal name as key and true/false as value.
---   :unit: a valid unit id, a df.unit object, or nil. If nil, the currently selected unit will be targeted.
---   :reset: boolean, or nil.
function assign(goals, unit, reset)
    assert(not goals or type(goals) == "table")
    assert(not unit or type(unit) == "number" or type(unit) == "userdata")
    assert(not reset or type(reset) == "boolean")

    goals = goals or {}
    reset = reset or false

    if type(unit) == "number" then
        unit = df.unit.find(tonumber(unit))
    end
    unit = unit or dfhack.gui.getSelectedUnit(true)
    if not unit then
        qerror("No unit found.")
    end

    -- erase goals
    if reset then
        unit.status.current_soul.personality.dreams = {}
    end

    --assign goals
    for goal, realized in pairs(goals) do
        assert(type(realized) == "boolean")
        goal = goal:upper()
        if df.goal_type[goal] then
            utils.insert_or_update(unit.status.current_soul.personality.dreams,
                                   { new = true, type = df.goal_type[goal], unk8 = realized and 1 or 0 },
                                   "type")
        else
            print_yellow("WARNING: '" .. goal .. "' is not a valid goal token. Skipping...")
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
    local goals
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
        elseif arg == valid_args.GOALS then
            -- initialise goal/flag table: it'll be useful later
            goals = {}
        elseif arg == valid_args.RESET then
            erase = true
        elseif goals then
            -- if the goals table is initialised, then we already encountered the "-goals" arg and this arg
            -- will probably be a goal name
            local goal_name = tostring(arg):upper()
            -- assume it's a valid goal name, now check if the next arg is a true/false value
            local realized_str = args[i + 1]:upper()
            if not realized_str then
                -- we reached the end of the arguments list
                qerror("Missing realized flag after '" .. arg .. "'.")
            end
            local realized_bool
            if realized_str == "TRUE" then
                realized_bool = true
            elseif realized_str == "FALSE" then
                realized_bool = false
            end
            if realized_bool == nil then
                qerror("'" .. realized_str .. "' is not a true or false value.")
            end
            goals[goal_name] = realized_bool
            i = i + 1 -- skip next arg because we already consumed it
        else
            qerror("'" .. arg .. "' is not a valid argument.")
        end
        i = i + 1 -- go to the next argument
    end

    assign(goals, unit_id, erase)
end

if not dfhack_flags.module then
    main(...)
end