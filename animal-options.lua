--@ module = true

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local gui = require('gui')

-- Make sure an animal unit of your civ is selected as well as not a pet
local function check_valid_unit()
    local unit = dfhack.gui.getSelectedUnit(true)
    if unit ~= nil
        and dfhack.units.isFortControlled(unit)
        and dfhack.units.isAlive(unit)
        and not dfhack.units.isPet(unit)
        and dfhack.units.isAnimal(unit) then

            return true
    else
        return false
    end
end

-- The above function already handles checking if valid unit
-- so just set slaughter flag
local function set_slaughter_flag()
    local unit = dfhack.gui.getSelectedUnit(true)
    unit.flags2.slaughter = 1
end

-- set units marked for gelding flag
local function set_gel_flag()
    local unit = dfhack.gui.getSelectedUnit(true)

    -- If the unit is not male or already gelded do nothing
    if unit.sex ~= 1 or unit.flags3.gelded == 1 then
        return
    end

    unit.flags3.marked_for_gelding = 1
end

-- set available for adoption flag
local function set_adoption_flag()
    local unit = dfhack.gui.getSelectedUnit(true)
    unit.flags3.available_for_adoption = 1
end

creature_screen=defclass(creature_screen, overlay.OverlayWidget)
creature_screen.ATTRS {
    desc = "Add options to tamed animals view sheet",
    default_pos={x=127,y=9},
    default_enabled=false,
    viewscreens='dwarfmode/ViewSheets/UNIT/Overview',
    frame={w=18, h=3},
}
function creature_screen:init()
    self:addviews{
        widgets.Panel{
            frame_background=gui.CLEAR_PEN,
            frame_style=gui.FRAME_MEDIUM,
            visible=check_valid_unit,
            subviews={
                widgets.HotkeyLabel{
                    frame={t=0,l=0},
                    label='Butcher',
                    key='CUSTOM_CTRL_D',
                    on_activate = set_slaughter_flag
                },
            },
        },
    }
end

OVERLAY_WIDGETS = {
    creaturescreen=creature_screen,
}

-- check module flags
if dfhack_flags.module then
    return
end