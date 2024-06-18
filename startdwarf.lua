--@ module=true

local argparse = require('argparse')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

StartDwarfOverlay = defclass(StartDwarfOverlay, overlay.OverlayWidget)
StartDwarfOverlay.ATTRS{
    desc='Adds a scrollbar (if necessary) to the list of starting dwarves.',
    default_pos={x=5, y=9},
    default_enabled=true,
    viewscreens='setupdwarfgame/Dwarves',
    frame={w=5, h=10},
}

function StartDwarfOverlay:init()
    self:addviews{
        widgets.Scrollbar{
            view_id='scrollbar',
            frame={r=0, t=0, w=2, b=0},
            on_scroll=self:callback('on_scrollbar'),
        },
    }
end

function StartDwarfOverlay:on_scrollbar(scroll_spec)
    local scr = dfhack.gui.getDFViewscreen(true)
    local _, sh = dfhack.screen.getWindowSize()
    local list_height = sh - 17
    local num_units = #scr.s_unit
    local units_per_page = list_height // 3

    local v = 0
    if tonumber(scroll_spec) then
        v = tonumber(scroll_spec) - 1
    elseif scroll_spec == 'down_large' then
        v = scr.selected_u + units_per_page // 2
    elseif scroll_spec == 'up_large' then
        v = scr.selected_u - units_per_page // 2
    elseif scroll_spec == 'down_small' then
        v = scr.selected_u + 1
    elseif scroll_spec == 'up_small' then
        v = scr.selected_u - 1
    end

    scr.selected_u = math.max(0, math.min(num_units-1, v))
end

function StartDwarfOverlay:render(dc)
    local sw, sh = dfhack.screen.getWindowSize()
    local list_height = sh - 17
    local scr = dfhack.gui.getDFViewscreen(true)
    local num_units = #scr.s_unit
    local units_per_page = list_height // 3
    local scrollbar = self.subviews.scrollbar
    self.frame.w = sw // 2 - 4
    self.frame.h = list_height
    self:updateLayout()

    local top = math.min(scr.selected_u + 1, num_units - units_per_page + 1)
    scrollbar:update(top, units_per_page, num_units)

    StartDwarfOverlay.super.render(self, dc)
end

OVERLAY_WIDGETS = {
    overlay=StartDwarfOverlay,
}

if dfhack_flags.module then
    return
end

local num = argparse.positiveInt(({...})[1])
if num > 32767 then
    qerror(('value must be no more than 32,767: %d'):format(num))
end
df.global.start_dwarf_count = num

print(('starting dwarf count set to %d. good luck!'):format(num))
