--Teleports unit to cursor
--[====[

flashstep
=========
A hotkey-friendly teleport that places you where your cursor is.

]====]
function flashstep(flash,step)
    local flash = df.global.world.units.active[0]
    local step
        if df.global.ui_advmode.menu == df.ui_advmode_menu.Look then
            step = df.global.cursor
        else
            qerror("No [l] cursor located! You kinda need it for this script.")
        end
    local unitoccupancy = dfhack.maps.getTileBlock(flash.pos).occupancy[flash.pos.x%16][flash.pos.y%16]
        flash.pos.x = step.x
        flash.pos.y = step.y
        flash.pos.z = step.z
            if flash.pos.x==step.x then
            local stepvisibility = dfhack.maps.getTileBlock(flash.pos).designation[flash.pos.x%16][flash.pos.y%16]
                stepvisibility.hidden=false
            end
    if not flash.flags1.on_ground then unitoccupancy.unit = false else unitoccupancy.unit_grounded = false end
end
flashstep(flash,step)
