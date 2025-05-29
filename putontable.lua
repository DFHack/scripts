-- Makes item appear on the table (just like in shops)
--[====[

putontable
==========
Makes item appear on the table, like in adventure mode shops.
Arguments:

* ``-a`` or ``--all``: apply to all items at the cursor

]====]

local guidm = require('gui.dwarfmode')

local args={...}
local doall
if args[1]=="-a" or args[1]=="--all" then
    doall=true
end
local items={} --as:df.item[]
local pos = guidm.getCursorPos()
local build = pos and dfhack.buildings.findAtTile(pos.x,pos.y,pos.z) or nil
if not df.building_tablest:is_instance(build) then
    error("No table found at cursor")
end
for k,v in pairs(df.global.world.items.other.IN_PLAY) do
    if v.flags.on_ground and same_xyz(v.pos, pos) then
        table.insert(items,v)
        if not doall then
            break
        end
    end
end
if #items==0 then
    error("No items found!")
end
for k,v in pairs(items) do
    dfhack.items.moveToBuilding(v,build,0)
end
