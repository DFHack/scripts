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

local function sanitize_entry_count(count, fallback)
    local num = tonumber(count)
    if num then
        return math.max(1, math.floor(num))
    end
    return fallback
end

local function simulate_actions(self, count)
    count = sanitize_entry_count(count, 1)

    gui.simulateInput(dfhack.gui.getCurViewscreen(), 'STANDARDSCROLL_RIGHT')

    local function step(i)
        if i > count then
            for _ = 1, count do
                local viewscreen = dfhack.gui.getCurViewscreen()
                gui.simulateInput(viewscreen, 'STANDARDSCROLL_UP')
                gui.simulateInput(viewscreen, 'CONTEXT_SCROLL_UP')
            end
            self.is_running = false
            return
        end

        local viewscreen = dfhack.gui.getCurViewscreen()

        if self.action_mode ~= 'lock' then
            gui.simulateInput(viewscreen, 'SELECT')
        end
        if self.action_mode ~= 'select' then
            gui.simulateInput(viewscreen, 'UNITLIST_SPECIALIZE')
        end

        gui.simulateInput(viewscreen, 'STANDARDSCROLL_DOWN')
        gui.simulateInput(viewscreen, 'CONTEXT_SCROLL_DOWN')

        dfhack.timeout(3, 'frames', function() step(i + 1) end)
    end

    step(1)
end

function SelectLockOverlay:init()
    self.action_mode = 'both'
    self.entry_count = 7
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
                    key = 'CUSTOM_S', -- press 's' to cycle modes
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
                    text = tostring(self.entry_count),
                    on_change = function(val)
                        self.entry_count = sanitize_entry_count(val, self.entry_count)
                    end,
                },
                widgets.HotkeyLabel{
                    view_id = 'run_button',
                    frame = {l = 1, t = 3},
                    label = 'RUN',
                    key = 'CUSTOM_R', -- press 'r' to run
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
