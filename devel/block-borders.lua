-- overlay that displays map block borders

local gui = require('gui')
local guidm = require "gui.dwarfmode"
local widgets = require('gui.widgets')

local DRAW_CHARS = {
    ns = string.char(179),
    ew = string.char(196),
    ne = string.char(192),
    nw = string.char(217),
    se = string.char(218),
    sw = string.char(191),
}

BlockBorders = defclass(BlockBorders, widgets.Window)
BlockBorders.ATTRS {
    frame_title='Block Borders',
    frame={t=20, r=3, w=29, h=7},
    autoarrange_subviews=true,
    autoarrange_gap=1,
}

function BlockBorders:init()
    self:addviews{
        widgets.ToggleHotkeyLabel{
            view_id='draw',
            key='CUSTOM_CTRL_D',
            label='Draw borders:',
            initial_option=true,
        },
        widgets.CycleHotkeyLabel{
            view_id='size',
            key='CUSTOM_CTRL_B',
            label='  Block size:',
            options={16, 48},
        },
    }
end

function BlockBorders:render_overlay()
    local block_size = self.subviews.size:getOptionValue()
    local block_end = block_size - 1
    guidm.renderMapOverlay(function(pos, is_cursor)
        if is_cursor then return end
        local block_x = pos.x % block_size
        local block_y = pos.y % block_size
        local key
        if block_x == 0 and block_y == 0 then
            key = 'se'
        elseif block_x == 0 and block_y == block_end then
            key = 'ne'
        elseif block_x == block_end and block_y == 0 then
            key = 'sw'
        elseif block_x == block_end and block_y == block_end then
            key = 'nw'
        elseif block_x == 0 or block_x == block_end then
            key = 'ns'
        elseif block_y == 0 or block_y == block_end then
            key = 'ew'
        end
        if not key then return nil end
        return COLOR_LIGHTCYAN, DRAW_CHARS[key]
    end)
end

function BlockBorders:onRenderFrame(dc, rect)
    if self.subviews.draw:getOptionValue() then
        self:render_overlay()
    end
    BlockBorders.super.onRenderFrame(self, dc, rect)
end

BlockBordersScreen = defclass(BlockBordersScreen, gui.ZScreen)
BlockBordersScreen.ATTRS {
    focus_path='block-borders',
    pass_movement_keys=true,
}

function BlockBordersScreen:init()
    self:addviews{BlockBorders{}}
end

function BlockBordersScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

view = view and view:raise() or BlockBordersScreen{}:show()
