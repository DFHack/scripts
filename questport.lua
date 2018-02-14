--Sends your adventurer to the location of your quest log cursor.
--[====[

questport
=========
Sends your adventurer to the location of your quest log cursor.
Usable from travel mode or on foot.
Don't try to travel normally while in forbidden travel areas (mountains, lairs) and you can questport out.

]====]
local gui = require 'gui'
local qp = dfhack.gui.getViewscreenByType(df.viewscreen_dungeonmodest, 0)
    or qerror("Could not find main adventure mode screen")
local qmap = dfhack.gui.getViewscreenByType(df.viewscreen_adventure_logst, 0)
    or qerror("Could not find quest log screen")
local qarm = df.global.world.armies.all

local qx = qmap.cursor_x * 48
local qy = qmap.cursor_y * 48
local rx = qmap.player_region_x * 48
local ry = qmap.player_region_y * 48
df.global.ui_advmode.unk_1 = qx
df.global.ui_advmode.unk_2 = qy
if df.global.ui_advmode.menu == df.ui_advmode_menu.Default then
    gui.simulateInput(qp.child, 'LEAVESCREEN')
    df.global.ui_advmode.menu = df.ui_advmode_menu.Travel
    df.global.ui_advmode.travel_not_moved = true
    gui.simulateInput(qp, 'CURSOR_DOWN')
    dfhack.timeout(15, 'frames', function()
        gui.simulateInput(qp, 'A_TRAVEL_LOG')
    end)
elseif df.global.ui_advmode.menu == df.ui_advmode_menu.Travel then
    for k,v in ipairs(qarm) do
        if v.flags.player then
            local my_arm = v.pos
            if rx ~= qx or ry ~= qy then
                my_arm.x = qx
                my_arm.y = qy
                qmap.player_region_x = qmap.cursor_x
                qmap.player_region_y = qmap.cursor_y
            end
        end
    end
end
