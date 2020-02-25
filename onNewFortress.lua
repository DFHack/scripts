-- runs dfhack commands only in a newborn fortress

local HELP = [====[

onNewFortress
=============
Runs commands like ``multicmd``, but only in a newborn fortress.

Use this in ``onMapLoad.init`` with f.e. ``ban-cooking``::

  onNewFortress ban-cooking tallow; ban-cooking honey; ban-cooking oil; ban-cooking seeds; ban-cooking brew; ban-cooking fruit; ban-cooking mill; ban-cooking thread; ban-cooking milk;

]====]


if not (...) then
    print(HELP)
    return
end

if df.global.ui.fortress_age ~= 0 then return end

for cmd in table.concat({...}, ' '):gmatch("%s*([^;]+);?%s*") do
    dfhack.run_command(cmd)
end
