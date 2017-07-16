-- Point the cursor to punt item under you, do this on a minecart to accelerate/turn/jump/stop.
-- A new and dangerous member of the propel/launch/telekinesis/punt/etc family!
-- By Roses, Rumrusher, and that Max™ guy.
function punt(itemSource,itemTarget)
local curpos
    if df.global.ui_advmode.menu==1 then
        curpos=df.global.cursor
    elseif df.global.gamemode == 1 then
        qerror("No [l] cursor located!You would have slammed into the ground and exploded.")
    else
        qerror("Must be used in adventurer mode or the arena!")
end

local count=0
local l = df.global.world.proj_list
local lastlist=l
    l=l.next
    while l do
        count=count+1
    if l.next==nil then
        lastlist=l
    end
    l = l.next
end

resultx = curpos.x - itemSource.pos.x
resulty = curpos.y - itemSource.pos.y
resultz = curpos.z - itemSource.pos.z

newlist = df.proj_list_link:new()
lastlist.next=newlist
newlist.prev=lastlist
proj = df.proj_itemst:new()
newlist.item=proj
proj.link=newlist
proj.id=df.global.proj_next_id
df.global.proj_next_id=df.global.proj_next_id+1
proj.item=itemSource
proj.origin_pos.x=itemSource.pos.x
proj.origin_pos.y=itemSource.pos.y
proj.origin_pos.z=itemSource.pos.z
proj.target_pos.x=curpos.x
proj.target_pos.y=curpos.y
proj.target_pos.z=curpos.z
proj.prev_pos.x=itemSource.pos.x
proj.prev_pos.y=itemSource.pos.y
proj.prev_pos.z=itemSource.pos.z
proj.cur_pos.x=itemSource.pos.x
proj.cur_pos.y=itemSource.pos.y
proj.cur_pos.z=itemSource.pos.z
proj.flags.no_impact_destroy=true
proj.flags.piercing=true
proj.flags.high_flying=true
proj.flags.parabolic=true
proj.flags.no_collide=false
proj.flags.unk9=true
proj.speed_x=resultx*10000
proj.speed_y=resulty*10000
proj.speed_z=resultz*17500
if (not itemSource.general_refs==nil and itemSource.vehicle_id) then
local veh = itemSource.vehicle_id
local icle = df.vehicle.find(veh)
    icle.speed_x=proj.speed_x
    icle.speed_y=proj.speed_y
    icle.speed_z=proj.speed_z
if itemSource.general_refs[0].unit_id==unitSource.id then
    if unitSource.flags1.projectile==true then
        if proj.link.next.item.unit==unitSource then
        local ollie = proj.link.next.item
            ollie.speed_x=proj.speed_x
            ollie.speed_y=proj.speed_y
            ollie.speed_z=proj.speed_z
            ollie.flags.safe_landing=true
            unitSource.flags1.on_ground=false
    elseif (not unitSource.flags1.on_ground and not unitSource.flags1.projectile) then
        if ollie.speed_x==0 and proj.speed_x==0 and ollie.speed_y==0 and proj.speed_y==0 and ollie.speed_z==0 and proj.speed_z==0 then
            icle.pos_x=unitSource.pos_x
            icle.pos_y=unitSource.pos_y
            icle.pos_z=unitSource.pos_z
            icle.speed_x=0
            icle.speed_y=0
            icle.speed_z=0
            icle.offset_x=0
            icle.offset_y=0
            icle.offset_z=0
    else unitoccupancy.unit = false
        unitoccupancy.unit_grounded = false
        unitoccupancy.item = false
                    end
                end
            end
        end
    end
end
function getItemAtKPos(cx,cy,cz) -- gets the item index @ x,y,z coord
    local vector=df.global.world.items.all -- load all items
    local kickpos=unitSource.pos
    for i = 0, #vector-1 do -- look into all items offsets
        local cpos=vector[i].pos --get its coordinates
        local cx=cpos.x
        local cy=cpos.y
        local cz=cpos.z
        if cx==kickpos.x and cy==kickpos.y and cz==kickpos.z then --compare them
            unitoccupancy.item = false
            return vector[i] --return index
        end
    end
    return nil
end
unitSource = df.global.world.units.active[0]
unitoccupancy = dfhack.maps.ensureTileBlock(unitSource.pos).occupancy[unitSource.pos.x%16][unitSource.pos.y%16]
itemSource=getItemAtKPos()
itemTarget = curpos

punt(itemSource,itemTarget)
