-- Change the skills of a unit.
--@ module = true

local help = [====[

assign-skills
=============
A script to change the skills of a unit.

Skills are defined by their token and their rank. Skills tokens can be
found here: `<https://dwarffortresswiki.org/index.php/DF2014:Skill_token>`_.

Below you can find a list of the first 16 ranks.:

Rank | Skill name
---- | ----------
  0  | Dabbling
  1  | Novice
  2  | Adequate
  3  | Competent
  4  | Skilled
  5  | Proficient
  6  | Talented
  7  | Adept
  8  | Expert
  9  | Professional
 10  | Accomplished
 11  | Great
 12  | Master
 13  | High Master
 14  | Grand Master
 15+ | Legendary

For more information:
`<https://dwarffortresswiki.org/index.php/DF2014:Skill#Skill_level_names>`_.

Usage:
* ``-help``: print the help page.

* ``-unit <UNIT_ID>``:
                    the target unit ID. If not present, the
                    currently selected unit will be the target.

* ``-skills <SKILL RANK [SKILL RANK] [...]>``:
                    the list of the skills to modify and their ranks.
                    Rank values range from -1 (the skill is not learned)
                    to normally 20 (legendary + 5). It is actually
                    possible to go beyond 20, no check is performed.

* ``-reset``:
                    clear all skills. If the script is called with
                    both this option and a list of skills/ranks,
                    first all the unit skills will be cleared
                    and then the listed skills will be added.

Example:
``-reset -skills WOODCUTTING 3 AXE 2``
Clears all the unit skills, then adds the Wood cutter skill
(competent evel) and the Axeman skill (adequate level).
]====]

local utils = require("utils")

local valid_args = {
    HELP = "-help",
    UNIT = "-unit",
    SKILLS = "-skills",
    RESET = "-reset",
}

-- ----------------------------------------------- UTILITY FUNCTIONS ------------------------------------------------ --
local function print_yellow(text)
    dfhack.color(COLOR_YELLOW)
    print(text)
    dfhack.color(-1)
end

-- ------------------------------------------------- ASSIGN SKILLS -------------------------------------------------- --
--- Assign the given skills to a unit, clearing all the other skills if requested.
---   :skills: nil, or a table. The fields have the skill token as key and its rank as value.
---   :unit: a valid unit id, a df.unit object, or nil. If nil, the currently selected unit will be targeted.
---   :reset: boolean, or nil.
function assign(skills, unit, reset)
    assert(not skills or type(skills) == "table")
    assert(not unit or type(unit) == "number" or type(unit) == "userdata")
    assert(not reset or type(reset) == "boolean")

    skills = skills or {}
    reset = reset or false

    if type(unit) == "number" then
        unit = df.unit.find(tonumber(unit))
    end
    unit = unit or dfhack.gui.getSelectedUnit(true)
    if not unit then
        qerror("No unit found.")
    end

    -- clear skills
    if reset then
        unit.status.current_soul.skills = {}
    end

    -- assign skills
    for skill, rank in pairs(skills) do
        assert(type(rank) == "number")
        skill = skill:upper()
        if df.job_skill[skill] then
            utils.insert_or_update(unit.status.current_soul.skills,
                                   { new = true, id = df.job_skill[skill], rating = rank },
                                   "id")
        else
            print_yellow("WARNING: '" .. skill .. "' is not a valid skill. Skipping...")
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
    local skills
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
        elseif arg == valid_args.SKILLS then
            -- initialise skill/rank table: it'll be useful later
            skills = {}
        elseif arg == valid_args.RESET then
            erase = true
        elseif skills then
            -- if the skills table is initialised, then we already encountered
            -- the "-skills" arg and this arg will probably be a skill name,
            -- but it can also be a rank value, so we check if it's a number
            if not tonumber(arg) then
                local skill_name = tostring(arg):upper()
                -- assume it's a valid skill name, now check if the next arg is a valid rank
                local rank_str = args[i + 1]
                if not rank_str then
                    -- we reached the end of the arguments list
                    qerror("Missing rank value after '" .. arg .. "'.")
                end
                local rank_int = tonumber(rank_str)
                if not rank_int then
                    qerror("'" .. rank_str .. "' is not a valid number.")
                end
                if rank_int >= -1 then
                    -- it can actually be less than -1, but I don't know what would happen
                    skills[skill_name] = rank_int
                    i = i + 1 -- skip next arg because we already consumed it
                else
                    qerror("Rank " .. rank_int .. " out of range.")
                end
            end
        else
            qerror("'" .. arg .. "' is not a valid argument.")
        end
        i = i + 1 -- go to the next argument
    end

    assign(skills, unit_id, erase)
end

if not dfhack_flags.module then
    main(...)
end