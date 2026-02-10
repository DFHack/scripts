-- configuration and status panel interface for logcleaner

local gui = require('gui')
local plugin = require('plugins.logcleaner')
local widgets = require('gui.widgets')

Logcleaner = defclass(Logcleaner, widgets.Window)
Logcleaner.ATTRS{
    frame_title='Logcleaner',
    frame={w=45, h=14},
    frame_inset=1,
}

function Logcleaner:init()
    self:addviews{
        widgets.ToggleHotkeyLabel{
            view_id='enable_toggle',
            frame={t=0, l=0},
            key='CUSTOM_SHIFT_E',
            label='logcleaner is',
            options={
                {value=true, label='Enabled', pen=COLOR_GREEN},
                {value=false, label='Disabled', pen=COLOR_RED},
            },
            on_change=function(val)
                dfhack.run_command({val and 'enable' or 'disable', 'logcleaner'})
            end,
        },
        widgets.Label{
            frame={t=2, l=0},
            text='Select log types to automatically clear.',
            text_pen=COLOR_GREY,
        },
        widgets.ToggleHotkeyLabel{
            view_id='combat_toggle',
            frame={t=4, l=0},
            key='CUSTOM_SHIFT_C',
            label='Combat:',
            options={
                {value=true, label='Enabled', pen=COLOR_GREEN},
                {value=false, label='Disabled', pen=COLOR_RED},
            },
            on_change=function(val)
                plugin.logcleaner_setCombat(val)
            end,
        },
        widgets.ToggleHotkeyLabel{
            view_id='sparring_toggle',
            frame={t=6, l=0},
            key='CUSTOM_SHIFT_S',
            label='Sparring:',
            options={
                {value=true, label='Enabled', pen=COLOR_GREEN},
                {value=false, label='Disabled', pen=COLOR_RED},
            },
            on_change=function(val)
                plugin.logcleaner_setSparring(val)
            end,
        },
        widgets.ToggleHotkeyLabel{
            view_id='hunting_toggle',
            frame={t=8, l=0},
            key='CUSTOM_SHIFT_H',
            label='Hunting:',
            options={
                {value=true, label='Enabled', pen=COLOR_GREEN},
                {value=false, label='Disabled', pen=COLOR_RED},
            },
            on_change=function(val)
                plugin.logcleaner_setHunting(val)
            end,
        },
    }
end

function Logcleaner:onRenderBody(dc)
    self.subviews.enable_toggle:setOption(plugin.isEnabled())
    self.subviews.combat_toggle:setOption(plugin.logcleaner_getCombat())
    self.subviews.sparring_toggle:setOption(plugin.logcleaner_getSparring())
    self.subviews.hunting_toggle:setOption(plugin.logcleaner_getHunting())
    Logcleaner.super.onRenderBody(self, dc)
end

--
-- LogcleanerScreen
--

LogcleanerScreen = defclass(LogcleanerScreen, gui.ZScreen)
LogcleanerScreen.ATTRS{
    focus_path='logcleaner',
}

function LogcleanerScreen:init()
    self:addviews{Logcleaner{}}
end

function LogcleanerScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
    qerror('logcleaner requires a fortress map to be loaded')
end

view = view and view:raise() or LogcleanerScreen{}:show()
