--@module = true

local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

progress_item = nil
num_done = nil
num_total = nil

function reset_state()
    progress_item = ''
    num_done = -1
    num_total = -1
end
reset_state()

-- -------------------
-- LegendsOverlay
--

LegendsOverlay = defclass(LegendsOverlay, overlay.OverlayWidget)
LegendsOverlay.ATTRS{
    desc='Adds extended export progress bar to the legends main screen.',
    default_pos={x=2, y=2},
    default_enabled=true,
    viewscreens='legends',
    frame={w=55, h=5},
}

function LegendsOverlay:init()
    self:addviews{
        widgets.Panel{
            view_id='button_mask',
            frame={t=0, l=0, w=15, h=3},
        },
        widgets.BannerPanel{
            frame={b=0, l=0, r=0, h=1},
            visible=function() return dfhack.gui.matchFocusString('legends/Default', dfhack.gui.getDFViewscreen(true)) end,
            subviews={
                widgets.ToggleHotkeyLabel{
                    view_id='do_export',
                    frame={t=0, l=1, r=1},
                    label='Also export DFHack extended legends data:',
                    key='CUSTOM_CTRL_D',
                    visible=function() return num_total < 0 end,
                },
                widgets.Label{
                    frame={t=0, l=1},
                    text={
                        'Exporting ',
                        {width=27, text=function() return progress_item end},
                        ' ',
                        {text=function() return ('%.2f'):format((num_done * 100) / num_total) end, pen=COLOR_YELLOW},
                        '% complete'
                    },
                    visible=function() return num_total >= 0 end,
                },
            },
        },
    }
end

function LegendsOverlay:onInput(keys)
    if keys._MOUSE_L and self.subviews.button_mask:getMousePos() and self.subviews.do_export:getOptionValue() then
        if num_total < 0 then
            dfhack.run_script('exportlegends')
        else
            return true
        end
    end
    return LegendsOverlay.super.onInput(self, keys)
end

-- -------------------
-- DoneMaskOverlay
--

DoneMaskOverlay = defclass(DoneMaskOverlay, overlay.OverlayWidget)
DoneMaskOverlay.ATTRS{
    desc='Prevents legends mode from being exited while an export is in progress.',
    default_pos={x=-2, y=2},
    default_enabled=true,
    viewscreens='legends',
    frame={w=9, h=3},
}

function DoneMaskOverlay:init()
    self:addviews{
        widgets.Panel{
            frame_background=gui.CLEAR_PEN,
            visible=function() return num_total >= 0 end,
        }
    }
end

function DoneMaskOverlay:onInput(keys)
    if num_total >= 0 then
        if keys.LEAVESCREEN or (keys._MOUSE_L and self:getMousePos()) then
            return true
        end
    end
    return DoneMaskOverlay.super.onInput(self, keys)
end
