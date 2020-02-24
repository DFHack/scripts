-- runs dfhack commands unless ran already in this save

local HELP = [====[

once-per-save
=============
Runs commands like ``multicmd``, but only unless
not already ran once in current save.

Use this in ``onMapLoad.init`` with f.e. ``ban-cooking``::

  once-per-save ban-cooking tallow; ban-cooking honey; ban-cooking oil; ban-cooking seeds; ban-cooking brew; ban-cooking fruit; ban-cooking mill; ban-cooking thread; ban-cooking milk;

Only successfully ran commands are saved.

Parameters:

--help            display this help
--rerun commands  ignore saved commands
--reset           deleted saved commands

]====]

local STORAGEKEY_PREFIX = 'once-per-save'
local storagekey = STORAGEKEY_PREFIX .. ':' .. tostring(df.global.ui.site_id)

local args = {...}
local rerun = false

local utils = require 'utils'
local arg_help = utils.invert({"?", "-?", "-help", "--help"})
local arg_rerun = utils.invert({"-rerun", "--rerun"})
local arg_reset = utils.invert({"-reset", "--reset"})
if arg_help[args[1]] then
    print(HELP)
    return
elseif arg_rerun[args[1]] then
    rerun = true
    table.remove(args, 1)
elseif arg_reset[args[1]] then
    while dfhack.persistent.delete(storagekey) do end
    table.remove(args, 1)
end
if #args == 0 then return end

local age = df.global.ui.fortress_age

local once_run = {}
if not rerun then
    local entries = dfhack.persistent.get_all(storagekey) or {}
    for i, entry in ipairs(entries) do
        if entry.ints[1] > age then
            -- probably unretiered fortress
            entry:delete()
        else
            once_run[entry.value]=entry
        end
    end
end

local save = dfhack.persistent.save
for cmd in table.concat(args, ' '):gmatch("%s*([^;]+);?%s*") do
    if not once_run[cmd] then
        local ok = dfhack.run_command(cmd) == 0
        if ok then
            once_run[cmd] = save({key = storagekey,
                                  value = cmd,
                                  ints = { age }},
                                 true)
        elseif rerun and once_run[cmd] then
            once_run[cmd]:delete()
        end
    end
end
