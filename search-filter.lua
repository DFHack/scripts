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
        if dfhack.units.isVisible(unit) and dfhack.units.isActive(unit) then
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
-- Assign the unit to a specific id
local unit = df.unit.find(unit.id)

-- Get the position of the unit and center the camera on the unit
local x, y, z = dfhack.units.getPosition(unit)
dfhack.gui.revealInDwarfmodeMap(xyz2pos(x, y, z), true)

-- Get the dimensions of the Dwarf Fortress map
local dims = dfhack.gui.getDwarfmodeViewDims()
-- Calculate zoom factor based on current viewport zoom level
local gpsZoom = df.global.gps.viewport_zoom_factor
-- Set the mouse x and y positions to click on the unit
df.global.gps.precise_mouse_x = (x - df.global.window_x) * gpsZoom // 4 + gpsZoom // 8
df.global.gps.precise_mouse_y = (y - df.global.window_y) * gpsZoom // 4 + gpsZoom // 8

-- Enable mouse tracking and set the left mouse button as pressed
df.global.enabler.tracking_on = 1
df.global.enabler.mouse_lbut = 1
df.global.enabler.mouse_lbut_down = 1

-- Simulate a left mouse click at the current mouse position
gui.simulateInput(dfhack.gui.getDFViewscreen(), '_MOUSE_R')

gui.simulateInput(dfhack.gui.getDFViewscreen(), '_MOUSE_L')

-- Disable mouse tracking and set the left mouse button as not pressed
df.global.enabler.tracking_on = 0
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
