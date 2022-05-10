-- Unforbid all items
--[====[

unforbid
========

Unforbids all items.

Usage::

    unforbid all [<options>]
    unforbid help

**<options>** can be zero or more of:

``-q``, ``--quiet``
    Suppress non-error console output.
]====]

local argparse = require('argparse')

local function unforbid_all(quiet)
    if not quiet then print('Unforbidding all items...') end
    local count = 0
    for _,item in ipairs(df.global.world.items.all) do
        if item.flags.forbid then
            if not quiet then print(('  unforbid: %s'):format(item)) end
            item.flags.forbid = false
            count = count + 1
        end
    end
    if not quiet then print(('%d items unforbidden'):format(count)) end
end

-- let the common --help parameter work, even though it's undocumented
local help, quiet = false, false
local commands = argparse.processArgsGetopt({...},
        {{'h', 'help', handler=function() help = true end},
         {'q', 'quiet', handler=function() quiet = true end}})

if not help and commands[1] == 'all' then
    unforbid_all(quiet)
else
    print(dfhack.script_help())
end
