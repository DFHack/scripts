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

local STORAGEKEY = 'once-per-save'

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

local once_run = {}
if not rerun then
    local entries = dfhack.persistent.get_all(STORAGEKEY) or {}
    for i, entry in ipairs(entries) do
        once_run[entry.value]=entry
    end
end

for cmd in table.concat(args, ' '):gmatch("%s*([^;]+);?%s*") do
    if not once_run[cmd] then
        local ok = dfhack.run_command(cmd) == 0
        if ok then
            once_run[cmd] = dfhack.persistent.save({key = STORAGEKEY, value = cmd}, true)
        elseif rerun and once_run[cmd] then
            once_run[cmd]:delete()
        end
    end
end
