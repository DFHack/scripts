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

local cursor_pen = dfhack.pen.parse {
    ch = "+",
    fg = COLOR_YELLOW,
    keep_lower = true,
    tile = dfhack.screen.findGraphicsTile(
        "CURSORS",
        0,
        22
    ),
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
        widgets.WrappedLabel{
            view_id='report',
            frame={t=2, l=0},
        },
    }
end

function Probe:onRenderBody()
    if dfhack.screen.inGraphicsMode() then
        guidm.renderMapOverlay(function() return cursor_pen end, {x1 = pos.x, x2= pos.x, y1 = pos.y, y2= pos.y, z1 = pos.z, z2= pos.z})
    elseif gui.blink_visible(500) then
        guidm.renderMapOverlay(function() return cursor_pen end, {x1 = pos.x, x2= pos.x, y1 = pos.y, y2= pos.y, z1 = pos.z, z2= pos.z})
    end
    if self.subviews.lock:getOptionValue() or self:getMouseFramePos() then return end
    pos = dfhack.gui.getMousePos()
    local report = dfhack.run_command_silent('probe', '--cursor', string.format("%d,%d,%d", pos.x, pos.y, pos.z))
    self.subviews.report.text_to_wrap = report
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

ProbeScreen = defclass(ProbeScreen, gui.ZScreen)
ProbeScreen.ATTRS{
    focus_string = 'probe',
    pass_pause = true,
    pass_movement_keys = true,
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
