-- Required libraries
local gui = require('gui') -- Importing the 'gui' library
local widgets = require('gui.widgets') -- Importing the 'widgets' library

-- Define SearchEngine class
SearchEngine = defclass(SearchEngine, widgets.Window) -- Defining a new class 'SearchEngine' that inherits from 'widgets.Window'
SearchEngine.ATTRS = {
    frame_title='Search Engine for Citizens', -- Title of the frame
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
            choices=self:getCitizens(), -- Choices in the List view are obtained from getCitizens function
            on_select=self:callback('onSelect'), -- Callback function when a citizen is selected from the list
        }
    }
end

function SearchEngine:getCitizens() -- Function to get all citizens
    local citizens = {}
    for _, unit in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(unit) then -- Check if a unit is a citizen
            table.insert(citizens, {text=dfhack.TranslateName(dfhack.units.getVisibleName(unit)), search_normalized=dfhack.toSearchNormalized(dfhack.TranslateName(dfhack.units.getVisibleName(unit))), id=unit.id})
            -- If unit is a citizen, insert it into the citizens table with its name, normalized search name and id.
        end
    end
    table.sort(citizens, function(a, b) return a.text < b.text end)     -- Sort the citizens table alphabetically by name
    return citizens -- Return the table of citizens
end

function SearchEngine:updateList()
    local input = dfhack.toSearchNormalized(self.subviews.edit.text)
    local citizens = self:getCitizens()
    local filtered_citizens = {}

    for _, citizen in ipairs(citizens) do
        if string.find(citizen.search_normalized, input) then
            table.insert(filtered_citizens, citizen)
        end
    end

    self.subviews.list:setChoices(filtered_citizens)
end

function SearchEngine:onSelect(index, citizen)
    local gui = require 'gui'
    local scr = dfhack.gui.getDFViewscreen()
    local sw, sh = dfhack.screen.getWindowSize()

    df.global.plotinfo.follow_unit = citizen.id
    -- Simulate input when a dwarf is selected. This input is to click on the character sheet or an item that was accidently selected. it also helps refresh the view
    df.global.gps.mouse_x = 130
    df.global.gps.precise_mouse_x = df.global.gps.mouse_x * df.global.gps.tile_pixel_x
    df.global.gps.mouse_y = 20
    df.global.gps.precise_mouse_y = df.global.gps.mouse_y * df.global.gps.tile_pixel_y
    df.global.enabler.mouse_lbut = 0
    df.global.enabler.mouse_lbut_down = 0

    --left click simulation
    df.global.enabler.tracking_on = 1
    df.global.enabler.mouse_lbut = 1
    df.global.enabler.mouse_lbut_down = 1
    gui.simulateInput(scr, '_MOUSE_L')
    --Right click simulation
    df.global.enabler.tracking_on = 1
    df.global.enabler.mouse_rbut = 1
    df.global.enabler.mouse_rbut_down = 1
    gui.simulateInput(scr, '_MOUSE_R')
    df.global.enabler.mouse_rbut = 0
    df.global.enabler.mouse_rbut_down = 0

        -- Simulate input when a dwarf is selected #2
    df.global.gps.mouse_x = 55
    df.global.gps.precise_mouse_x = df.global.gps.mouse_x * df.global.gps.tile_pixel_x
    df.global.gps.mouse_y = 35
    df.global.gps.precise_mouse_y = df.global.gps.mouse_y * df.global.gps.tile_pixel_y

    --left click simulation
    df.global.enabler.tracking_on = 1
    df.global.enabler.mouse_lbut = 1
    df.global.enabler.mouse_lbut_down = 1
    gui.simulateInput(scr, '_MOUSE_L')
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
