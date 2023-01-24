-- A basic example to start your own gui script from.
--@ module = true

local gui = require('gui')
local widgets = require('gui.widgets')

local HIGHLIGHT_PEN = dfhack.pen.parse{
    ch=string.byte(' '),
    fg=COLOR_LIGHTGREEN,
    bg=COLOR_LIGHTGREEN}

HelloWorld = defclass(HelloWorld, gui.Screen)

function HelloWorld:init()
    local window = widgets.Window{
        frame={w=20, h=14},
        frame_title='Hello World',
        autoarrange_subviews=true,
        autoarrange_gap=1,
    }
    window:addviews{
        widgets.Label{text={{text='Hello, world!', pen=COLOR_LIGHTGREEN}}},
        widgets.HotkeyLabel{
            frame={l=0, t=0},
            label='Click me',
            key='CUSTOM_CTRL_A',
            on_activate=self:callback('toggleHighlight'),
        },
        widgets.Panel{
            view_id='highlight',
            frame={w=10, h=5},
            frame_style=gui.THIN_FRAME,
        },
    }
    self:addviews{window}
end

function HelloWorld:toggleHighlight()
    local panel = self.subviews.highlight
    panel.frame_background = not panel.frame_background and HIGHLIGHT_PEN or nil
end

function HelloWorld:onDismiss()
    view = nil
end

function HelloWorld:onInput(keys)
    if self:inputToSubviews(keys) then
        return true
    elseif keys.LEAVESCREEN or keys.SELECT then
        self:dismiss()
        return true
    end
end

function HelloWorld:onRenderFrame(dc, rect)
    -- since we're not taking up the entire screen
    self:renderParent()
end

if dfhack_flags.module then
    return
end

view = view or HelloWorld{}:show()
