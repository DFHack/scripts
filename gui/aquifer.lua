local dig = require('plugins.dig')
local gui = require('gui')
local widgets = require('gui.widgets')

local selection_rect = df.global.selection_rect

local function reset_selection_rect()
    selection_rect.start_x = -30000
    selection_rect.start_y = -30000
    selection_rect.start_z = -30000
end

--
-- Aquifer
--

Aquifer = defclass(Aquifer, widgets.Window)
Aquifer.ATTRS {
    frame_title='Aquifer',
    frame={w=38, h=15, r=2, t=18},
    autoarrange_subviews=true,
    autoarrange_gap=1,
    resizable=true,
}

function Aquifer:init()
    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text='Select map area to modify',
        },
        widgets.CycleHotkeyLabel{
            view_id='action',
            key='CUSTOM_CTRL_E',
            label='Action:',
            options={
                {label='Drain', value='drain', pen=COLOR_LIGHTRED},
                {label='Convert', value='convert', pen=COLOR_YELLOW},
                {label='Add', value='add', pen=COLOR_BLUE},
            },
            on_change=function(val)
                if val ~= 'drain' and self.subviews.aq_type:getOptionValue() == 'all' then
                    self.subviews.aq_type:cycle()
                end
            end,
        },
        widgets.CycleHotkeyLabel{
            view_id='aq_type',
            key='CUSTOM_CTRL_T',
            label=function()
                if self.subviews.action:getOptionValue() == 'convert' then
                    return 'To aquifer type:'
                end
                return 'Aquifer type:'
            end,
            options={
                {label='All', value='all', pen=COLOR_LIGHTRED},
                {label='Light', value='light', pen=COLOR_LIGHTBLUE},
                {label='Heavy', value='heavy', pen=COLOR_BLUE},
            },
            initial_option='all',
            on_change=function(val)
                if val == 'all' and self.subviews.action:getOptionValue() ~= 'drain' then
                    self.subviews.aq_type:cycle()
                end
            end,
        },
        widgets.ToggleHotkeyLabel{
            view_id='leaky',
            key='CUSTOM_CTRL_K',
            label=function()
                if self.subviews.action:getOptionValue() == 'add' then
                    return 'Allow immediate leaks:'
                end
                return 'Affect only leaks:'
            end,
            initial_option=false,
        },
        widgets.Divider{
            frame={h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.HotkeyLabel{
            key='CUSTOM_CTRL_A',
            label='Apply to entire level now',
            on_activate=self:callback('action_level'),
        },
    }
end

function Aquifer:onRenderFrame(dc, rect)
    dig.paintScreenWarmDamp(true, false)
    Aquifer.super.onRenderFrame(self, dc, rect)
end

function Aquifer:onInput(keys)
    if Aquifer.super.onInput(self, keys) then return true end

    if keys.LEAVESCREEN or keys._MOUSE_R then
        if selection_rect.start_x >= 0 then
            reset_selection_rect()
            return true
        end
        return false
    end

    local pos = nil
    if keys._MOUSE_L and not self:getMouseFramePos() then
        pos = dfhack.gui.getMousePos()
    end

    if pos then
        if selection_rect.start_x >= 0 then
            self:action_box(pos)
            reset_selection_rect()
        else
            -- set this again just in case it got unset somehow
            df.global.game.main_interface.main_designation_selected = df.main_designation_type.TOGGLE_ENGRAVING
            -- use selection_rect so gui/design can display the dimensions overlay
            selection_rect.start_x = pos.x
            selection_rect.start_y = pos.y
            selection_rect.start_z = pos.z
        end
        return true
    end
end

function Aquifer:get_base_command()
    local command = {'aquifer', '-q'}
    table.insert(command, self.subviews.action:getOptionValue())
    local aq_type = self.subviews.aq_type:getOptionValue()
    if aq_type ~= 'all' then
        table.insert(command, aq_type)
    end
    if self.subviews.leaky:getOptionValue() then
        table.insert(command, '--leaky')
    end
    return command
end

function Aquifer:action_level()
    local command = self:get_base_command()
    table.insert(command, '-z')
    dfhack.run_command(command)
end

function Aquifer:action_box(pos)
    local command = self:get_base_command()
    table.insert(command, ('%d,%d,%d'):
        format(selection_rect.start_x, selection_rect.start_y, selection_rect.start_z))
    table.insert(command, ('%d,%d,%d'):format(pos.x, pos.y, pos.z))
    dfhack.run_command(command)
end

--
-- AquiferScreen
--

AquiferScreen = defclass(AquiferScreen, gui.ZScreen)
AquiferScreen.ATTRS {
    focus_path='aquifer',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
}

function AquiferScreen:init()
    self.saved_designation_type = df.global.game.main_interface.main_designation_selected
    df.global.game.main_interface.main_designation_selected = df.main_designation_type.TOGGLE_ENGRAVING

    self:addviews{Aquifer{}}
end

function AquiferScreen:onDismiss()
    reset_selection_rect()
    df.global.game.main_interface.main_designation_selected = self.saved_designation_type
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a map to be loaded')
end

view = view and view:raise() or AquiferScreen{}:show()
