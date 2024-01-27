--@ module = true

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local gui = require('gui')

local YES = 'Yes'
local NO = 'No'

-- Make sure an animal unit of your civ is selected as well as not a pet
local function check_valid_unit()
    local unit = dfhack.gui.getSelectedUnit(true)
    return unit
        and dfhack.units.isFortControlled(unit)
        and dfhack.units.isAlive(unit)
        and not dfhack.units.isPet(unit)
        and dfhack.units.isAnimal(unit)
end

local function is_geldable()
    local unit = dfhack.gui.getSelectedUnit(true)

    -- If the unit is not male or already gelded do nothing
    if unit.sex ~= 1 or unit.flags3.gelded == true then
        return false
    else
        return true
    end
end

creature_screen=defclass(creature_screen, overlay.OverlayWidget)
creature_screen.ATTRS {
    desc = "Add options to tamed animals view sheet",
    default_pos={x=-42,y=37},
    default_enabled=false,
    viewscreens='dwarfmode/ViewSheets/UNIT/Overview',
    frame={w=23, h=6},
}

-- The above function already handles checking if valid unit
-- so just set slaughter flag
function creature_screen:set_slaughter_flag(option)
    local unit = dfhack.gui.getSelectedUnit(true)

    if not unit then return end

    if option == YES then
        unit.flags2.slaughter = true
    else
        unit.flags2.slaughter = false
    end
end

-- set units marked for gelding flag
function creature_screen:set_geld_flag(option)
    local unit = dfhack.gui.getSelectedUnit(true)

    if not unit then return end

    if option == YES then
        unit.flags3.marked_for_gelding = true
    else
        unit.flags3.marked_for_gelding = false
    end
end

-- set available for adoption flag
function creature_screen:set_adoption_flag(option)
    local unit = dfhack.gui.getSelectedUnit(true)

    if not unit then return end

    if option == YES then
        unit.flags3.available_for_adoption = true
    else
        unit.flags3.available_for_adoption = false
    end
end

-- Check current flag status of animal to dynamically set on/off
function creature_screen:get_butcher(unit)
    if not unit then return end

    if unit.flags2.slaughter == true then
        return YES
    else
        return NO
    end
end

function creature_screen:get_geld(unit)
    if not unit then return end

    if unit.flags3.marked_for_gelding == true then
        return YES
    else
        return NO
    end
end

function creature_screen:get_adopt(unit)
    if not unit then return end

    if unit.flags3.available_for_adoption == true then
        return YES
    else
        return NO
    end
end

-- Use render to set On/Off dynamically for each unit
function creature_screen:render(dc)
    local unit = dfhack.gui.getSelectedUnit(true)

    self.subviews.butcher_animal:setOption(self:get_butcher(unit))
    self.subviews.geld_animal:setOption(self:get_geld(unit))
    self.subviews.adopt_animal:setOption(self:get_adopt(unit))

    creature_screen.super.render(self, dc)
end

function creature_screen:init()
self:addviews{
    widgets.Panel{
        frame_background=gui.CLEAR_PEN,
        frame_style=gui.FRAME_MEDIUM,
        visible=check_valid_unit,
        subviews={
            widgets.CycleHotkeyLabel{
                frame={t=0,l=0},
                label='Butcher',
                key='CUSTOM_CTRL_B',
                options={
                    {label=NO, value=NO, pen=COLOR_WHITE},
                    {label=YES, value=YES, pen=COLOR_GREEN},
                },
                view_id='butcher_animal',
                on_change=function(val) self:set_slaughter_flag(val) end,
            },
            widgets.ToggleHotkeyLabel{
                frame={t=1,l=0},
                label='Geld',
                key='CUSTOM_CTRL_G',
                options={
                    {label=NO, value=NO, pen=COLOR_WHITE},
                    {label=YES, value=YES, pen=COLOR_GREEN},
                },
                view_id='geld_animal',
                enabled=is_geldable,
                on_change = function(val) self:set_geld_flag(val) end
            },
            widgets.ToggleHotkeyLabel{
                frame={t=2,l=0},
                label='Adopt',
                key='CUSTOM_CTRL_A',
                options={
                    {label=NO, value=NO, pen=COLOR_WHITE},
                    {label=YES, value=YES, pen=COLOR_GREEN},
                },
                view_id='adopt_animal',
                on_change = function(val) self:set_adoption_flag(val) end
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
