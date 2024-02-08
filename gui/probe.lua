-- Shows the info given by `probe` in a friendly display

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

Probe = defclass(Probe, widgets.Window)
Probe.ATTRS{
    frame = {
        w = 40,
        h = 45,
        r = 2,
        t = 18,
    },
    resizable=true,
    frame_title='Probe',
}

function Probe:init()
    self:addviews{
        widgets.ToggleHotkeyLabel{
            view_id='lock',
            frame={t=0, l=0},
            key='CUSTOM_CTRL_F',
            label='Lock on tile:',
            initial_option=false,
        },
        widgets.Label{
            view_id='report',
            frame={t=2, l=0},
        },
    }
end

function Probe:onRenderBody()
    if self.subviews.lock:getOptionValue() or self:getMouseFramePos() then return end
    guidm.setCursorPos(dfhack.gui.getMousePos())
    local report = dfhack.run_command_silent('probe')
    self.subviews.report:setText(report)
    self:updateLayout()
end

function Probe:onInput(keys)
    if Probe.super.onInput(self, keys) then
        return true
    end
    if keys._MOUSE_L and not self:getMouseFramePos() then
        self.subviews.lock:cycle()
        return true
    end
end

ProbeScreen = defclass(ProbeScreen, gui.ZScreenModal)
ProbeScreen.ATTRS{
    focus_string='probe-screen',
}

function ProbeScreen:init()
    self:addviews{Probe{}}
end

function ProbeScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror("This script requires a fortress map to be loaded")
end

view = view and view:raise() or ProbeScreen {}:show()
