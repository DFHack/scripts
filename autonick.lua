-- gives dwarves unique nicknames
--[====[

autonick
========
Gives dwarves unique nicknames chosen randomly from ``dfhack-config/autonick.txt``.

One nickname per line.
Empty lines, lines beginning with ``#`` and repeat entries are discarded.

Dwarves with manually set nicknames are ignored.

If there are fewer available nicknames than dwarves, the remaining
dwarves will go un-nicknamed.

You may wish to use this script with the "repeat" command, e.g:
``repeat -name autonick -time 3 -timeUnits months -command [ autonick -f ]``

Usage:

    autonick [<options>]

Options:

:``-f``, ``--force``:
    skip confirmation. useful for scripting.
:``-h``, ``--help``:
    Show this text.
:``-q``, ``--quiet``:
    Do not report how many dwarves were given nicknames.
]====]

local options = {}

local argparse = require('argparse')
local commands = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() options.help = true end},
    {'f', 'force', handler=function() options.force = true end},
    {'q', 'quiet', handler=function() options.quiet = true end},
})

-- autonick does not use commands, so if there are any, the script is being used wrong.
if #commands ~= 0 then options.help = true end

if options.help == true then
    print(dfhack.script_help())
    return
end

result = options.force;
if options.force ~= true then
    local utils = require("utils")
    result = utils.prompt_yes_no("nickname unnicked dwarves? (use -f to disable this check)", true)
end

if result == true then
    local seen = {}
    --check current nicknames
    for _,unit in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(unit) and
        unit.name.nickname ~= "" then
            seen[unit.name.nickname] = true
        end
    end

    local names = {}
    -- grab list, put in array
    local path = dfhack.getDFPath () .. "/dfhack-config/autonick.txt";
    for line in io.lines(path) do
        line = line:trim()
        if (line ~= "")
        and (not line:startswith('#'))
        and (not seen[line]) then
            table.insert(names, line)
            seen[line] = true
        end
    end

    --assign names
    count = 0
    for _,unit in ipairs(df.global.world.units.active) do
        if (#names == 0) then
                if options.quiet ~= true then
                    print("no free names left in autonick.txt.")
                end
            break
        end
        --if there are any names left
        if dfhack.units.isCitizen(unit) and
        unit.name.nickname == "" then
            newnameIndex = math.random (#names)
            dfhack.units.setNickname(unit, names[newnameIndex])
            table.remove(names, newnameIndex)
            count = count + 1
        end
    end

    if options.quiet ~= true then
        print(("gave nicknames to %s dwarves."):format(count))
    end
end
