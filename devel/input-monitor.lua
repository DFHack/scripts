local gui = require('gui')
local widgets = require('gui.widgets')

-----------------------
-- InputMonitorWindow
--

InputMonitorWindow = defclass(InputMonitorWindow, widgets.Window)
InputMonitorWindow.ATTRS{
    frame={w=51, h=50},
    frame_title='Input Monitor',
    resizable=true,
    resize_min={h=20},
}

local function getModifierPen(which)
    return dfhack.internal.getModifiers()[which] and
        COLOR_WHITE or COLOR_GRAY
end

local function getButtonPen(which)
    which = ('mouse_%s_down'):format(which)
    return df.global.enabler[which] == 1 and
        COLOR_WHITE or COLOR_GRAY
end

function InputMonitorWindow:init()
    self:addviews{
        widgets.Label{
            frame={l=0, t=0},
            text={
                'Modifier keys:',
                {gap=1, text='Shift', pen=function() return getModifierPen('shift') end},
                {gap=1, text='Ctrl', pen=function() return getModifierPen('ctrl') end},
                {gap=1, text='Alt', pen=function() return getModifierPen('alt') end},
            },
        },
        widgets.Label{
            frame={l=0, t=2},
            text={
                'Mouse buttons:',
                {gap=1, text='Lbut', pen=function() return getButtonPen('lbut') end},
                {gap=1, text='Mbut', pen=function() return getButtonPen('mbut') end},
                {gap=1, text='Rbut', pen=function() return getButtonPen('rbut') end},
            },
        },
        widgets.Panel{
            view_id='streampanel',
            frame={t=4, b=2, l=0, r=0},
            frame_style=gui.INTERIOR_FRAME,
            subviews={
                widgets.Label{
                    frame={t=0, l=0},
                    text='Input stream (newest at bottom):',
                },
                widgets.Label{
                    view_id='streamlog',
                    frame={t=1, l=2, b=0},
                    auto_height=false,
                    text={},
                },
            },
        },
        widgets.HotkeyLabel{
            frame={b=0},
            key='LEAVESCREEN',
            label='Hit ESC twice or click here twice to close',
            text_pen=function()
                return self.escape_armed and COLOR_LIGHTRED or COLOR_WHITE
            end,
            auto_width=true,
            on_activate=function()
                if self.escape_armed then
                    self.parent_view:dismiss()
                end
                self.escape_armed = true
            end,
        },
    }
end

function InputMonitorWindow:onInput(keys)
    local streamlog = self.subviews.streamlog
    local stream = streamlog.text
    if #stream > 0 then
        table.insert(stream, NEWLINE)
        table.insert(stream, NEWLINE)
    end
    for key in pairs(keys) do
        if key == '_STRING' then
            table.insert(stream,
                ('_STRING="%s" (%d)'):format(keys._STRING == 0 and '' or string.char(keys._STRING), keys._STRING))
        else
            table.insert(stream, key)
        end
        print(stream[#stream])
        table.insert(stream, NEWLINE)
    end
    print()
    local newstream = {}
    local num_lines = self.subviews.streampanel.frame_rect.height - 2
    for idx=#stream,1,-1 do
        local elem = stream[idx]
        if elem == NEWLINE then
            num_lines = num_lines - 1
            if num_lines <= 0 then
                break
            end
        end
        table.insert(newstream, elem)
    end
    for idx=1,#newstream//2 do
        local mirror_idx = #newstream-idx+1
        newstream[idx], newstream[mirror_idx] = newstream[mirror_idx], newstream[idx]
    end
    streamlog:setText(newstream)

    InputMonitorWindow.super.onInput(self, keys)
    if not keys._MOUSE_L and not keys._MOUSE_L_DOWN and not keys.LEAVESCREEN then
        self.escape_armed = false
    end
    return true
end

-----------------------
-- InputMonitorScreen
--

InputMonitorScreen = defclass(InputMonitorScreen, gui.ZScreen)
InputMonitorScreen.ATTRS{
    focus_path='input-monitor',
}

function InputMonitorScreen:init()
    self:addviews{InputMonitorWindow{}}
end

function InputMonitorScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

view = view and view:raise() or InputMonitorScreen{}:show()
