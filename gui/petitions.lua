-- Show fort's petitions, pending and fulfilled.

local gui = require 'gui'
local list_agreements = reqscript('list-agreements')
local widgets = require 'gui.widgets'

Petitions = defclass(Petitions, widgets.Window)
Petitions.ATTRS {
    frame_title='Petitions',
    frame={w=110, h=30},
    resizable=true,
    resize_min={w=70, h=15},
}

function Petitions:init()
    self:addviews{
        widgets.List{
            view_id='list',
            frame={t=0, l=0, r=0, b=2},
            row_height=3,
        },
        widgets.ToggleHotkeyLabel{
            view_id='show_fulfilled',
            frame={b=0, l=0},
            key='CUSTOM_CTRL_A',
            label='Show fulfilled agreements:',
            initial_option=false,
            on_change=function() self:refresh() end,
        },
    }

    self:refresh()
    local list = self.subviews.list
    self.frame.w = math.max(list:getContentWidth() + 6, self.resize_min.w)
    self.frame.h = math.max(list:getContentHeight() + 6, self.resize_min.h)
end

local function get_choice_text(agr)
    local loctype = list_agreements.get_location_type(agr)
    local loc_name = list_agreements.get_location_name(agr.details[0].data.Location.tier, loctype)
    local agr_age = list_agreements.get_petition_age(agr)
    local resolved, resolution_string = list_agreements.is_resolved(agr)

    local details_pre, details_target, details_post
    if loctype == df.abstract_building_type.TEMPLE then
        details_pre = 'worshiping '
        details_target = list_agreements.get_deity_name(agr)
        details_post = ''
    else
        details_pre = 'a '
        details_target = list_agreements.get_guildhall_profession(agr)
        details_post = ' guild'
    end

    return {
        'Establish a ',
        {text=loc_name, pen=COLOR_WHITE},
        ' for ',
        {text=list_agreements.get_agr_party_name(agr), pen=COLOR_BROWN},
        ', ',
        details_pre,
        {text=details_target, pen=COLOR_MAGENTA},
        details_post,
        ',',
        NEWLINE,
        {gap=4, text='as agreed on '},
        list_agreements.get_petition_date(agr),
        ', ',
        ('%dy, %dm, %dd ago '):format(agr_age[1], agr_age[2], agr_age[3]),
        {text=('(%s)'):format(resolution_string), pen=resolved and COLOR_GREEN or COLOR_YELLOW},
    }
end

function Petitions:refresh()
    local cull_resolved = not self.subviews.show_fulfilled:getOptionValue()
    local t_agr, g_agr = list_agreements.get_fort_agreements(cull_resolved)
    local choices = {}
    for _, agr in ipairs(t_agr) do
        table.insert(choices, {text=get_choice_text(agr)})
    end
    for _, agr in ipairs(g_agr) do
        table.insert(choices, {text=get_choice_text(agr)})
    end
    if #choices == 0 then
        table.insert(choices, {text='No outstanding agreements'})
    end
    self.subviews.list:setChoices(choices)
end

PetitionsScreen = defclass(PetitionsScreen, gui.ZScreen)
PetitionsScreen.ATTRS {
    focus_path='petitions',
}

function PetitionsScreen:init()
    self:addviews{Petitions{}}
end

function PetitionsScreen:onDismiss()
    view = nil
end

if not dfhack.world.isFortressMode() or not dfhack.isMapLoaded() then
    qerror('gui/petitions requires a fortress map to be loaded')
end

view = view and view:raise() or PetitionsScreen{}:show()
