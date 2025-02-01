--@ module=true

local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local job_details = df.global.game.main_interface.job_details
local races = df.global.world.raws.creatures.alphabetic

MakeForAnyRaceOverlay = defclass(MakeForAnyRaceOverlay, overlay.OverlayWidget)
MakeForAnyRaceOverlay.ATTRS{
    desc='Allows you to make armor and clothing for any race.',
    default_pos={x=-41,y=4},
    default_enabled=true,
    viewscreens='dwarfmode/ViewSheets/BUILDING/Workshop',
    frame={w=26, h=3},
    frame_style=gui.FRAME_MEDIUM,
    frame_background=gui.CLEAR_PEN,
}

function MakeForAnyRaceOverlay:render(dc)
    if not job_details.open or job_details.current_option ~= df.job_details_option_type.CLOTHING_SIZE then
        return
    end
    MakeForAnyRaceOverlay.super.render(self, dc)
end

function MakeForAnyRaceOverlay:show_other_races()
    for i = #job_details.clothing_size_race_index-1, 1, -1 do
        job_details.clothing_size_race_index:erase(i)
    end
    for i = #job_details.clothing_size_race_index_master-1, 1, -1 do
        job_details.clothing_size_race_index_master:erase(i)
    end
    for i, race in ipairs(races) do
        if not race.flags.VERMIN_GROUNDER and not race.flags.VERMIN_SOIL
            and not race.flags.DOES_NOT_EXIST and not race.flags.EQUIPMENT_WAGON
        then
            job_details.clothing_size_race_index:insert("#", i)
            job_details.clothing_size_race_index_master:insert("#", i)
        end
    end
end

function MakeForAnyRaceOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='show other races',
            key='CUSTOM_CTRL_D',
            on_activate=self:callback('show_other_races'),
        },
    }
end

OVERLAY_WIDGETS = {
    make_for_any_race=MakeForAnyRaceOverlay,
}
