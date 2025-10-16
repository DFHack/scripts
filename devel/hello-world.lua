-- A basic example to start your own gui script from.
--@ module = true

local gui = require('gui')
local widgets = require('gui.widgets')

local HIGHLIGHT_PEN = dfhack.pen.parse{
    ch=string.byte(' '),
    fg=COLOR_LIGHTGREEN,
    bg=COLOR_LIGHTGREEN,
}

HelloWorldWindow = defclass(HelloWorldWindow, widgets.Window)
HelloWorldWindow.ATTRS{
    frame={w=25, h=25},
    frame_title='Hello World',
    autoarrange_subviews=true,
    autoarrange_gap=2,
    resizable=true,
    resize_min={w=25, h=25},
}

function HelloWorldWindow:init()
    local LEVEL_OPTIONS = {
        {label='Low', value=1},
        {label='Medium', value=2},
        {label='High', value=3},
        {label='Pro', value=4},
        {label='Insane', value=5},
    }

    self:addviews{
        widgets.Label{text={{text='Hello, world!', pen=COLOR_LIGHTGREEN}}},
        widgets.HotkeyLabel{
            frame={l=0},
            label='Click me',
            key='CUSTOM_CTRL_A',
            on_activate=self:callback('toggleHighlight'),
        },
        widgets.Panel{
            view_id='highlight',
            frame={w=10, h=5},
            frame_style=gui.INTERIOR_FRAME,
        },
        widgets.Divider{
            frame={h=1},
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.CycleHotkeyLabel{
            view_id='level',
            frame={l=0, w=20},
            label='Level:',
            key_back='CUSTOM_SHIFT_C',
            key='CUSTOM_SHIFT_V',
            options=LEVEL_OPTIONS,
            initial_option=LEVEL_OPTIONS[1].value,
        },
        widgets.Slider{
            frame={l=1},
            num_stops=#LEVEL_OPTIONS,
            get_idx_fn=function()
                return self.subviews.level:getOptionValue()
            end,
            on_change=function(idx) self.subviews.level:setOption(idx) end,
        },
    }
end

function HelloWorldWindow:toggleHighlight()
    local panel = self.subviews.highlight
    panel.frame_background = not panel.frame_background and HIGHLIGHT_PEN or nil
end

HelloWorldScreen = defclass(HelloWorldScreen, gui.ZScreen)
HelloWorldScreen.ATTRS{
    focus_path='hello-world',
}

function HelloWorldScreen:init()
    self:addviews{HelloWorldWindow{}}
end

function HelloWorldScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

view = view and view:raise() or HelloWorldScreen{}:show()
