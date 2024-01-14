--@ module = true

local dialogs = require('gui.dialogs')
local gui = require('gui')
local widgets = require('gui.widgets')

--
-- Reveal
--

Reveal = defclass(Reveal, widgets.Window)
Reveal.ATTRS {
    frame_title='Reveal',
    frame={w=32, h=14, r=2, t=18},
    autoarrange_subviews=true,
    autoarrange_gap=1,
    hell=DEFAULT_NIL,
}

function Reveal:init()
    if self.hell then
        self.frame.h = 15
    end

    self:addviews{
        widgets.WrappedLabel{
            text_to_wrap='The map is revealed. The game will be force paused until you close this window.',
        },
        widgets.WrappedLabel{
            text_to_wrap='Areas with event triggers are kept hidden to avoid spoilers.',
            text_pen=COLOR_YELLOW,
            visible=not self.hell,
        },
        widgets.WrappedLabel{
            text_to_wrap='Areas with event triggers have been revealed. The map must be hidden again before unpausing.',
            text_pen=COLOR_RED,
            visible=self.hell,
        },
        widgets.ToggleHotkeyLabel{
            view_id='unreveal',
            key='CUSTOM_SHIFT_R',
            label='Restore map on close:',
            options={
                {label='Yes', value=true, pen=COLOR_GREEN},
                {label='No', value=false, pen=COLOR_RED},
            },
            enabled=not self.hell,
       },
    }
end

--
-- RevealScreen
--

RevealScreen = defclass(RevealScreen, gui.ZScreen)
RevealScreen.ATTRS {
    focus_path='reveal',
    pass_movement_keys=true,
    force_pause=true,
    hell=false,
}

function RevealScreen:init()
    local command = {'reveal'}
    if self.hell then
        table.insert(command, 'hell')
    end
    dfhack.run_command(command)

    self:addviews{Reveal{hell=self.hell}}
end

function RevealScreen:onDismiss()
    view = nil
    if self.subviews.unreveal:getOptionValue() then
        dfhack.run_command('unreveal')
    end
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

local args = {...}

view = view and view:raise() or RevealScreen{hell=args[1] == 'hell'}:show()
