-- Set a dwarf's characteristics according to a predefined profile
--@ module = true

local help = [====[

assign-profile
==============
A script to change the characteristics of a unit
according to a profile loaded from a json file.

A profile can describe which attributes, skills, preferences, beliefs,
goals and facets a unit must have. The script relies on the presence
of the other ``assign-...`` modules in this collection: please refer
to the other modules documentation for more specific information.

For information about the json schema, please see the
the "/hack/scripts/dwarf_profiles.json" file.

Usage:

``-help``:
                    print the help page.

``-unit <UNIT_ID>``:
                    the target unit ID. If not present, the
                    target will be the currently selected unit.

``-file <filename>``:
                    the json file containing the profile to apply.
                    It's a relative path, starting from the DF
                    root directory and ending at the json file.
                    It must begin with a slash. Default value:
                    "/hack/scripts/dwarf_profiles.json".

``-profile <profile>``:
                    the profile to apply. It's the name of
                    the profile as stated in the json file.

``-reset <list of characteristics>``:
                    the characteristics to be reset/cleared. If not present,
                    it will not clear or reset any characteristic. If it's a
                    valid list of characteristic, those characteristics will
                    be reset, and then, if present in the profile, the new
                    values will be applied. If set to ``PROFILE``, it will
                    reset only the characteristics changed in the profile
                    (and then the new values will be applied). If set to
                    ``ALL``, it will reset EVERY characteristic. Possible
                    values: ``ALL``, ``PROFILE``, ``ATTRIBUTES``, ``SKILLS``,
                    ``PREFERENCES``, ``BELIEFS``, ``GOALS``, ``FACETS``.

Examples:

``assign-profile -reset ALL``
    Resets/clears all the characteristics of the
    unit, leaving behind a very bland character.

``assign-profile -profile CARPENTER -reset PROFILE``
    Loads and applies the profile called "CARPENTER"
    in the default json file, resetting/clearing
    all the characteristics listed in the
    profile, and then applying the new values.

``assign-profile -file /hack/scripts/military_profiles.json -profile ARCHER -reset ATTRIBUTES``
    Loads and applies the profile called "ARCHER"
    in the provided json file, keeping all the old
    characteristics but the attributes, which will
    be reset (and then, if the profile provides some
    attributes values, those value will be applied).
]====]

local json = require "json"

local valid_args = {
    HELP = "-help",
    UNIT = "-unit",
    FILE = "-file",
    PROFILE = "-profile",
    RESET = "-reset",
}

-- add a script here to include it in the profile. The key must be the same as written in the json.
local scripts = {
    ATTRIBUTES = reqscript("assign-attributes"),
    SKILLS = reqscript("assign-skills"),
    PREFERENCES = reqscript("assign-preferences"),
    BELIEFS = reqscript("assign-beliefs"),
    GOALS = reqscript("assign-goals"),
    FACETS = reqscript("assign-facets"),
}

local default_filename = "/hack/scripts/dwarf_profiles.json"

-- ----------------------------------------------- UTILITY FUNCTIONS ------------------------------------------------ --
local function contains(table, value)
    for _, v in pairs(table) do
        if v == value then
            return true
        end
    end
    return false
end

-- ------------------------------------------------- APPLY PROFILE -------------------------------------------------- --
--- Apply the given profile to a unit, erasing or resetting the unit characteristics if requested.
---   :profile: nil, or a table. Each field has a characteristic name as key, and a table suitable to be passed as
---             an argument to the ``assign`` function of the module related to the characteristic.
---             See the modules documentation for more details.
---   :unit: a valid unit id, a df.unit object, or nil. If nil, the currently selected unit will be targeted.
---   :reset: nil, or a table value/boolean. See this script documentation for valid values.
--luacheck: in=string[],df.unit,bool[]
function apply_profile(profile, unit, reset_table)
    assert(not profile or type(profile) == "table")
    assert(not unit or type(unit) == "number" or type(unit) == "userdata")
    assert( not reset_table or type(reset_table) == "table")

    profile = profile or {}
    reset_table = reset_table or {}

    local function apply(characteristic_name, script)
        local reset_flag = reset_table.ALL or
                reset_table[characteristic_name] ~= nil or
                (reset_table.PROFILE and profile[characteristic_name] ~= nil)
        script.assign(profile[characteristic_name], unit, reset_flag)
    end

    for characteristic_name, script in pairs(scripts) do
        apply(characteristic_name, script)
    end
end

-- --------------------------------------------------- LOAD PROFILE ------------------------------------------------- --
--- Load the given profile, searching it inside the given JSON file (if not nil) or inside the default JSON file.
--- The filename must begin with a slash and must be a relative path starting from the root DF
--- directory and ending at the desired file.
--- Return the parsed profile as a table.
--luacheck: in=string,string
function load_profile(profile_name, filename)
    assert(profile_name ~= nil)

    local json_file = string.format("%s%s", dfhack.getDFPath(), filename or default_filename)
    local profiles = {} --as:string[][]
    if dfhack.filesystem.isfile(json_file) then
        profiles = json.decode_file(json_file)
    else
        qerror(string.format("File '%s' not found.", json_file))
    end
    if profiles[profile_name] then
        return profiles[profile_name]
    else
        qerror(string.format("Profile '%s' not found", profile_name))
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
    local filename
    local profile_name
    local reset_table = {}


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
        elseif arg == valid_args.FILE then
            i = i + 1 -- consume next arg
            filename = args[i]
            if not filename then
                -- we reached the end of the arguments list
                qerror("Missing profile name.")
            end
        elseif arg == valid_args.PROFILE then
            i = i + 1 -- consume next arg
            profile_name = args[i]
            if not profile_name then
                -- we reached the end of the arguments list
                qerror("Missing profile name.")
            end
        elseif arg == valid_args.RESET then
            while args[i + 1] and not contains(valid_args, args[i + 1]) do
                i = i + 1
                reset_table[args[i]:upper()] = true
            end
        else
            qerror("'" .. arg .. "' is not a valid argument.")
        end
        i = i + 1 -- go to the next argument
    end

    local profile = load_profile(profile_name, filename)
    apply_profile(profile, unit_id, reset_table)
end

if not dfhack_flags.module then
    main(...)
end
