-- Required libraries
local gui = require('gui') -- Importing the 'gui' library
local widgets = require('gui.widgets') -- Importing the 'widgets' library

-- Define SearchEngine class
SearchEngine = defclass(SearchEngine, widgets.Window) -- Defining a new class 'SearchEngine' that inherits from 'widgets.Window'
SearchEngine.ATTRS = {
    frame_title='Search Engine for Fort-Controlled Units', -- Title of the frame
    frame={w=50, h=45}, -- Dimensions of the frame
    resizable=true, -- Frame can be resized
    resize_min={w=43, h=20}, -- Minimum dimensions when resizing
}

function SearchEngine:init() -- Initialization function for the SearchEngine class
    self:addviews{
        widgets.EditField{
            view_id='edit',
            frame={t=1, l=1}, -- Position of the EditField view
            text='', -- Initial text in the EditField view
            on_change=self:callback('updateList'), -- Callback function when text in EditField changes
        },
        widgets.List{
            view_id='list',
            frame={t=3, b=0},
            choices=self:getFortControlledUnits(), -- Choices in the List view are obtained from getFortControlledUnits function
            on_select=self:callback('onSelect'), -- Callback function when a unit is selected from the list
        }
    }
end

function SearchEngine:getFortControlledUnits()
    local fortControlledUnits = {}
    for _, unit in ipairs(df.global.world.units.active) do
        local unitName = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
        if unitName == "" then
            -- Use the race name if the unit's name field is empty
            unitName = dfhack.units.getRaceName(unit)
        end
        if dfhack.units.isFortControlled(unit) then
            table.insert(fortControlledUnits, {text=unitName, search_normalized=dfhack.toSearchNormalized(unitName), id=unit.id})
        end
    end
    table.sort(fortControlledUnits, function(a, b) return a.text < b.text end)
    return fortControlledUnits
end

function SearchEngine:updateList()
    local input = dfhack.toSearchNormalized(self.subviews.edit.text)
    local fortControlledUnits = self:getFortControlledUnits()
    local filtered_fortControlledUnits = {}

    for _, unit in ipairs(fortControlledUnits) do
        if string.find(unit.search_normalized, input) then
            table.insert(filtered_fortControlledUnits, unit)
        end
    end

    self.subviews.list:setChoices(filtered_fortControlledUnits)
end

function SearchEngine:onSelect(index, unit)
    local gui = require 'gui'
    local scr = dfhack.gui.getDFViewscreen()

    df.global.plotinfo.follow_unit = unit.id
    df.global.game.main_interface.view_sheets.open = true  -- Changes the character sheet to true
    df.global.game.main_interface.view_sheets.active_id = unit.id -- changes the id of the character 
    df.global.game.main_interface.view_sheets.active_sheet = 0 -- changes the active sheet to be a unit

    df.global.gps.mouse_x = 130
    df.global.gps.precise_mouse_x = df.global.gps.mouse_x * df.global.gps.tile_pixel_x

    df.global.gps.mouse_y = 20
    df.global.gps.precise_mouse_y = df.global.gps.mouse_y * df.global.gps.tile_pixel_y

    df.global.enabler.mouse_lbut = 0
    df.global.enabler.mouse_lbut_down = 0

    -- Left click simulation
    simulateClick(scr, '_MOUSE_L')

    -- Right click simulation
    simulateClick(scr, '_MOUSE_R')
end

function simulateClick(scr, button)
    local gui = require 'gui'

    df.global.enabler.tracking_on = 1
    df.global.enabler.mouse_lbut = 1
    df.global.enabler.mouse_lbut_down = 1

    gui.simulateInput(scr, button)

    df.global.enabler.mouse_lbut = 0
    df.global.enabler.mouse_lbut_down = 0
end

-- Screen creation
SearchEngineScreen = defclass(SearchEngineScreen, gui.ZScreen)
SearchEngineScreen.ATTRS = {
    focus_path='SearchEngine',
}

function SearchEngineScreen:init()
    self:addviews{SearchEngine{}}
end

function SearchEngineScreen:onDismiss()
    view = nil
end

view = view and view:raise() or SearchEngineScreen{}:show()
