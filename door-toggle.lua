-- door-toggle.lua
-- DFHack tool: bulk lock/unlock doors and hatches in a selected rectangle
-- Usage:
--   door-toggle            -> opens GUI
--   door-toggle lock       -> preselect lock, start selection
--   door-toggle open       -> preselect unlock, start selection

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

-- =============================
-- Core logic
-- =============================

local function bounds_from(pos1, pos2)
    return {
        x1=math.min(pos1.x, pos2.x),
        x2=math.max(pos1.x, pos2.x),
        y1=math.min(pos1.y, pos2.y),
        y2=math.max(pos1.y, pos2.y),
        z1=math.min(pos1.z, pos2.z),
        z2=math.max(pos1.z, pos2.z),
    }
end

local function is_pos_in_bounds(pos, b)
    return pos.x >= b.x1 and pos.x <= b.x2
       and pos.y >= b.y1 and pos.y <= b.y2
       and pos.z >= b.z1 and pos.z <= b.z2
end

local function is_toggle_target(bld)
    local t = bld:getType()
    return t == df.building_type.Door or t == df.building_type.Hatch
end

local function apply_to_doors_in_rect(pos1, pos2, mode)
    local b = bounds_from(pos1, pos2)
    local changed = 0
    local skipped = 0

    for _, bld in ipairs(df.global.world.buildings.all) do
        if is_toggle_target(bld) then
            local pos = {x=bld.centerx, y=bld.centery, z=bld.z}
            if is_pos_in_bounds(pos, b) then
                if bld.door_flags then
                    if mode == 'lock' then
                        bld.door_flags.forbidden = true
                    else -- mode == 'open'
                        bld.door_flags.forbidden = false
                    end
                end
                changed = changed + 1
            else
                skipped = skipped + 1
            end
        end
    end

    return changed, skipped
end

local function get_action_text(mark)
    local str = mark and 'opposite' or 'first'
    return ('Select the %s corner with the mouse.'):format(str)
end

-- =============================
-- Preview overlay
-- =============================

local to_pen = dfhack.pen.parse
local SELECTION_PEN = to_pen{
    tile=dfhack.screen.findGraphicsTile('CURSORS', 1, 2),
}

-- =============================
-- Window
-- =============================

DoorToggleWindow = defclass(DoorToggleWindow, widgets.Window)
DoorToggleWindow.ATTRS{
    frame_title='Door Toggle',
    frame={w=44, h=13, r=2, t=18},
    resizable=true,
    autoarrange_subviews=true,
    autoarrange_gap=1,
    mode='lock',
    status_text='',
    selecting=true,
    mark=nil,
    on_cancel=DEFAULT_NIL,
}

function DoorToggleWindow:init()
    if self.status_text == '' then
        self.status_text = 'Select the first corner with the mouse.'
    end
    self:addviews{
        widgets.WrappedLabel{
            view_id='status',
            text_to_wrap=function() return self.status_text end,
        },
        widgets.CycleHotkeyLabel{
            view_id='mode',
            label='Mode:',
            key='CUSTOM_S',
            options={
                {label='Lock', value='lock', pen=COLOR_RED},
                {label='Unlock', value='open', pen=COLOR_GREEN},
            },
            initial_option=(self.mode == 'open') and 2 or 1,
        },
        widgets.HotkeyLabel{
            label='Cancel',
            key='LEAVESCREEN',
            on_activate=function()
                if self.on_cancel then self.on_cancel() end
            end,
        },
        widgets.WrappedLabel{
            text_to_wrap=function()
                if not self.selecting then return '' end
                return get_action_text(self.mark)
            end,
            pen=COLOR_LIGHTCYAN,
        },
    }
end

function DoorToggleWindow:onInput(keys)
    if DoorToggleWindow.super.onInput(self, keys) then return true end

    if keys.LEAVESCREEN then
        if self.on_cancel then self.on_cancel() end
        return true
    end

    if keys._MOUSE_R then
        if self.mark then
            self.mark = nil
            self.status_text = 'Select the first corner with the mouse.'
            self:updateLayout()
            return true
        end
        if self.on_cancel then self.on_cancel() end
        return true
    end
    self.selecting = true

    local pos = nil
    if keys._MOUSE_L and not self:getMouseFramePos() then
        pos = dfhack.gui.getMousePos()
    end
    if not pos then return false end

    if self.mark then
        local mode = self.subviews.mode:getOptionValue()
        local changed, skipped = apply_to_doors_in_rect(self.mark, pos, mode)
        self.status_text = string.format(
            '%s %d doors/hatches.',
            (mode == 'lock') and 'Locked' or 'Unlocked',
            changed
        )
        self.mark = nil
        self:updateLayout()
    else
        self.mark = pos
        self.status_text = get_action_text(self.mark)
        self:updateLayout()
    end

    return true
end

-- =============================
-- Screen
-- =============================

DoorToggleScreen = defclass(DoorToggleScreen, gui.ZScreen)
DoorToggleScreen.ATTRS{
    focus_path='door-toggle',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
    mode='lock',
    start_selection=false,
}

function DoorToggleScreen:init()
    local screen = self
    self.window = DoorToggleWindow{
        mode=self.mode,
        on_cancel=function() screen:dismiss() end,
    }
    self:addviews{self.window}
    if self.start_selection then
        self.window.selecting = true
        self.window.status_text = 'Select the first corner with the mouse.'
        self.window:updateLayout()
    end
end

function DoorToggleScreen:onRenderFrame(dc, rect)
    DoorToggleScreen.super.onRenderFrame(self, dc, rect)

    if not dfhack.screen.inGraphicsMode() and not gui.blink_visible(500) then
        return
    end

    if not self.window then return end
    if not self.window.selecting or not self.window.mark then return end
    if self.window:getMouseFramePos() then return end

    local mouse_pos = dfhack.gui.getMousePos()
    if not mouse_pos then return end

    local start_pos = self.window.mark
    local preview_pos = {x=mouse_pos.x, y=mouse_pos.y, z=start_pos.z}
    local bounds = bounds_from(start_pos, preview_pos)
    bounds.z1 = start_pos.z
    bounds.z2 = start_pos.z

    local function get_overlay_pen(pos)
        if is_pos_in_bounds(pos, bounds) then
            return SELECTION_PEN
        end
    end

    guidm.renderMapOverlay(get_overlay_pen, bounds)
end

-- =============================
-- Entrypoint
-- =============================

local args = {...}

local function start_gui_with_mode(mode, start_selection)
    local screen = DoorToggleScreen{mode=mode or 'lock', start_selection=start_selection}
    dfhack.screen.show(screen)
end

if #args == 0 then
    start_gui_with_mode('lock', false)
elseif args[1] == 'lock' or args[1] == 'open' then
    start_gui_with_mode(args[1], true)
else
    qerror('Usage: door-toggle [lock|open]')
end
