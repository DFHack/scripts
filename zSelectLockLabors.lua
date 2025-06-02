--@module=true
local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

local SelectLockOverlay = defclass(nil, overlay.OverlayWidget)
SelectLockOverlay.ATTRS {
    desc = 'Simulate selection and locking of multiple units.',
    viewscreens = {'dwarfmode/Info/LABOR/WORK_DETAILS/Default'},
    default_enabled = true,
    default_pos = {x = -70, y = 10},
    frame = {w = 25, h = 6, r = 1, t = 1, transparent = false},
}

local function simulate_actions(self, count)
        gui.simulateInput(dfhack.gui.getCurViewscreen(), 'STANDARDSCROLL_RIGHT')

    local function step(i)
        if i > count then
            for _ = 1, count do
                gui.simulateInput(dfhack.gui.getCurViewscreen(), 'STANDARDSCROLL_UP')
                gui.simulateInput(dfhack.gui.getCurViewscreen(), 'CONTEXT_SCROLL_UP')
            end
            self.is_running = false
            return
        end

        if self.action_mode ~= 'lock' then
            gui.simulateInput(dfhack.gui.getCurViewscreen(), 'SELECT')
        end
        if self.action_mode ~= 'select' then
            gui.simulateInput(dfhack.gui.getCurViewscreen(), 'UNITLIST_SPECIALIZE')
        end
        --This line is keyboard arrow down
        gui.simulateInput(dfhack.gui.getCurViewscreen(), 'STANDARDSCROLL_DOWN')
        --CONTEXT_SCROLL_DOWN helps with consistency. Otherwise the program will miss some units. Line below is scroll wheel down
        gui.simulateInput(dfhack.gui.getCurViewscreen(), 'CONTEXT_SCROLL_DOWN')

        dfhack.timeout(2, 'frames', function() step(i + 1) end)
    end

    step(1)
end

function SelectLockOverlay:init()
    self.action_mode = 'both'
    self.entry_count = 100
    self.is_running = false
    self:addviews{
        widgets.Panel{
            frame_style = gui.MEDIUM_FRAME,
            frame_background = gui.CLEAR_PEN,
            subviews = {
                widgets.CycleHotkeyLabel{
                    view_id = 'action_mode',
                    frame = {l = 1, t = 1},
                    label = 'Mode',
                    option_gap = 2,
                    options = {
                        {label = 'Select only', value = 'select'},
                        {label = 'Lock only', value = 'lock'},
                        {label = 'Select + Lock', value = 'both'},
                    },
                    initial_option = 'both',
                    on_change = function(val) self.action_mode = val end,
                },
                widgets.EditField{
                    numeric = true,
                    frame = {l = 1, t = 2},
                    key = 'CUSTOM_CTRL_N',
                    auto_focus = false,
                    text = '100',
                    on_change = function(val)
                        local num = tonumber(val)
                        self.entry_count = (num and num > 0 and math.floor(num)) or 100
                    end,
                },
                widgets.HotkeyLabel{
                    view_id = 'run_button',
                    frame = {l = 1, t = 3},
                    label = 'RUN',
                    on_activate = function()
                        if self.is_running then return end
                        self.is_running = true
                        simulate_actions(self, self.entry_count)
                    end,
                    enabled = function() return not self.is_running end,
                },
            },
        },
    }
end

OVERLAY_WIDGETS = {
    select_lock_overlay = SelectLockOverlay,
}

return {}
