-- runs dfhack commands unless ran already in this save

local HELP = [====[

once-per-save
=============
Runs commands like ``multicmd``, but only unless
not already ran once in current save.

Use this in ``onMapLoad.ini`` with f.e. ``ban-cooking``::

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
if args[1] == "--help" or args[1] == "-?" or args[1] == "?" then
    print(HELP)
    return
elseif args[1] == "--rerun" then
    rerun = true
    table.remove(args, 1)
elseif args[1] == "--reset" then
    while dfhack.persistent.delete(STORAGEKEY) do end
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
