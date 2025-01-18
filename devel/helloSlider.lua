local gui = require('gui')
local widgets = require('gui.widgets')

--
-- RangerWindow
--

RangerWindow = defclass(RangerWindow, widgets.Window)
RangerWindow.ATTRS {
    frame_title='Hello, Slider!',
    frame={w=25, h=8},
    resizable=true,
    resize_min={w=25, h=8},
}

function RangerWindow:init()
    local LEVEL_OPTIONS = {
        {label='Low', value=1},
        {label='Medium', value=2},
        {label='High', value=3},
        {label='Pro', value=4},
        {label='Insane', value=5},
    }

    self:addviews{
        widgets.CycleHotkeyLabel{
            view_id='level',
            frame={l=1, t=0, w=16},
            label='Level:',
            label_below=true,
            key_back='CUSTOM_SHIFT_C',
            key='CUSTOM_SHIFT_V',
            options=LEVEL_OPTIONS,
            initial_option=LEVEL_OPTIONS[1].value,
            on_change=function(val)
                self.subviews.level:setOption(val)
            end,
        },
        widgets.Slider{
            frame={l=1, t=3},
            num_stops=#LEVEL_OPTIONS,
            get_idx_fn=function()
                return self.subviews.level:getOptionValue()
            end,
            on_change=function(idx) self.subviews.level:setOption(idx) end,
        },
    }
end

--
-- RangerScreen
--

RangerScreen = defclass(RangerScreen, gui.ZScreen)
RangerScreen.ATTRS {
    focus_path='ranger',
}

function RangerScreen:init()
    self:addviews{RangerWindow{}}
end

function RangerScreen:onDismiss()
    view = nil
end

--
-- main logic
--

view = view and view:raise() or RangerScreen{}:show()
