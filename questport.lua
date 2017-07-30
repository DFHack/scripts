--Sends you to the location of your quest log cursor.
--Don't try to travel normally while in forbidden travel areas (mountains, lairs) and you can questport out.
--[====[

questport
=====
Use the quest log map and cursor to select a location you want to visit and go there.
Usable from travel mode or on foot.
Works unless you receive a travel restriction message, so don't do that.

]====]
local gui=require 'gui'
local qp=df.global.gview.view.child
local qmap=dfhack.gui.getCurViewscreen()
local qarm=df.global.world.armies.all
if df.viewscreen_adventure_logst:is_instance(qmap) then
    local qx=qmap.cursor_x*48
    local qy=qmap.cursor_y*48
    local rx=qmap.player_region_x*48
    local ry=qmap.player_region_y*48
    df.global.ui_advmode.unk_1=qx
    df.global.ui_advmode.unk_2=qy
        if df.global.ui_advmode.menu==0 then
            gui.simulateInput(qp.child,'LEAVESCREEN')
            df.global.ui_advmode.menu=26
            df.global.ui_advmode.travel_not_moved=true
            gui.simulateInput(qp,'CURSOR_DOWN')
            dfhack.timeout(15,'frames',function()
            gui.simulateInput(qp,'A_TRAVEL_LOG') end)
        elseif df.global.ui_advmode.menu==26 then
            for k,v in ipairs(qarm) do
                if v.flags[0] then
                    local my_arm=df.global.world.armies.all[k].pos
                    if (rx~=qx or ry~=qy) then do
                        my_arm.x=qx
                        my_arm.y=qy
                        qmap.player_region_x=qmap.cursor_x
                        qmap.player_region_y=qmap.cursor_y
                    end
                end
            end
        end
    end
end
