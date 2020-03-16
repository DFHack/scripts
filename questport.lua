--Teleports your adventurer to the location of your quest log map cursor.
--[====[

questport
=========
Sends your adventurer to the location of your quest log map cursor.
Usable from travel mode or on foot.
Can be used in situations where fast travel is normally prohibited.

]====]

local gui = require 'gui'

local function processTravelNoArmy(advmode, advScreen, target_x, target_y)
    advmode.travel_origin_x = target_x
    advmode.travel_origin_y = target_y
    advmode.travel_origin_z = 0 -- ensure that the adventurer is teleported to the surface
    gui.simulateInput(advScreen.child, 'LEAVESCREEN') -- close map
    gui.simulateInput(advScreen.child, 'LEAVESCREEN') -- close log
    advmode.site_level_zoom = 1 -- zoom in to shrink the following travel movement, reducing the risk of failure
    gui.simulateInput(advScreen, 'CURSOR_DOWN') -- the player army is only created once the player moves in travel mode; ensure that this movement occurs as the player will otherwise find themselves at their original location if they end travel mode immediately
--  note: the above movement may be blocked by an impassable tile (especially if trying to teleport into a mountain range); it would be more ideal to create and move the player army directly instead
end

if not dfhack.world.isAdventureMode() then
    qerror('This script can only be used in adventure mode!')
end

local advScreen = dfhack.gui.getViewscreenByType(df.viewscreen_dungeonmodest, 0)
    or qerror("Could not find main adventure mode screen!") -- should not happen
local questMap = dfhack.gui.getViewscreenByType(df.viewscreen_adventure_logst, 0)
    or qerror("You must first select your destination on the quest log map!")

local target_x = questMap.cursor_x
local target_y = questMap.cursor_y
if questMap.player_region_x == target_x and questMap.player_region_y == target_y then
    qerror("You already seem to be at the target location!")
end

target_x = target_x * 48 -- converting to the army coordinates scale
target_y = target_y * 48

local advmode = df.global.ui_advmode
advmode.message = '' -- clear messages like "You cannot travel until you leave this site" to permit travel

if advmode.menu == df.ui_advmode_menu.Default then
    advmode.menu = df.ui_advmode_menu.Travel
    advmode.travel_not_moved = true
    processTravelNoArmy(advmode, advScreen, target_x, target_y)

elseif advmode.menu == df.ui_advmode_menu.Travel then
    if not advmode.travel_not_moved then -- player is already moving in fast travel mode; just relocate the player army
        local armies = df.global.world.armies.all
        for i = #armies-1, 0, -1 do
            local army = armies[i]
            if army.flags.player then
                army.pos.x = target_x
                army.pos.y = target_y
                gui.simulateInput(advScreen.child, 'LEAVESCREEN') -- close map
                gui.simulateInput(advScreen.child, 'LEAVESCREEN') -- close log
                break -- there's never more than 1 player army
            end
        end
    else -- player has opened travel mode but hasn't moved yet, so the player army hasn't been created
        processTravelNoArmy(advmode, advScreen, target_x, target_y)
    end
end
