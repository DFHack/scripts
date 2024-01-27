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

    if unit.flags2.slaughter == 1 then
        unit.flags2.slaughter = 0
    else
        unit.flags2.slaughter = 1
    end
end

-- set units marked for gelding flag
local function set_gel_flag()
    local unit = dfhack.gui.getSelectedUnit(true)

    -- If the unit is not male or already gelded do nothing
    if unit.sex ~= 1 or unit.flags3.gelded == 1 then
        return
    end

    if unit.flags3.marked_for_gelding == 1 then
        unit.flags3.marked_for_gelding = 0
    else
        unit.flags3.marked_for_gelding = 1
    end
end

-- set available for adoption flag
local function set_adoption_flag()
    local unit = dfhack.gui.getSelectedUnit(true)

    if unit.flags3.available_for_adoption == 1 then
        unit.flags3.available_for_adoption = 0
    else
        unit.flags3.available_for_adoption = 1
    end
end

-- Check current flag status of animal to dynamically set on/off for each unit?
local function initial_butcher()
    local unit = dfhack.gui.getSelectedUnit(true)

    if unit.flags2.slaughter == 1 then
        return true
    else
        return false
    end
end

local function initial_geld()
    local unit = dfhack.gui.getSelectedUnit(true)

    if unit.flags3.marked_for_gelding == 1 then
        return true
    else
        return false
    end
end

local function initial_adopt()
    local unit = dfhack.gui.getSelectedUnit(true)

    if unit.flags3.available_for_adoption == 1 then
        return true
    else
        return false
    end
end

creature_screen=defclass(creature_screen, overlay.OverlayWidget)
creature_screen.ATTRS {
    desc = "Add options to tamed animals view sheet",
    default_pos={x=-44,y=37},
    default_enabled=false,
    viewscreens='dwarfmode/ViewSheets/UNIT/Overview',
    frame={w=21, h=6},
}
function creature_screen:init()
    self:addviews{
        widgets.Panel{
            frame_background=gui.CLEAR_PEN,
            frame_style=gui.FRAME_MEDIUM,
            visible=check_valid_unit,
            subviews={
                widgets.ToggleHotkeyLabel{
                    frame={t=0,l=0},
                    label='Butcher',
                    key='CUSTOM_CTRL_B',
                    initial_option=false,
                    on_change = set_slaughter_flag
                },
                widgets.ToggleHotkeyLabel{
                    frame={t=1,l=0},
                    label='Geld',
                    key='CUSTOM_CTRL_G',
                    initial_option=false,
                    on_change = set_gel_flag
                },
                widgets.ToggleHotkeyLabel{
                    frame={t=2,l=0},
                    label='Adopt',
                    key='CUSTOM_CTRL_A',
                    initial_option=false,
                    on_change = set_adoption_flag
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
