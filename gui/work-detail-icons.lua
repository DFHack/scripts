--@ module = true

local gui = require('gui')
local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')
local utils = require('utils')

local wdi = reqscript('work-detail-icons')
local icondefs = reqscript('internal/work-detail-icons/icon-definitions')
local vanilla = icondefs.vanilla
local builtin = icondefs.builtin

local labor = df.global.game.main_interface.info.labor
local work_details = df.global.plotinfo.labor_info.work_details

--
-- GUI window
--

-- detail currently selected on the labor screen
local function get_current_wd()
    local idx = dfhack.gui.getWidget(labor, 'Tabs', 'Work Details', 'Details').selected_idx
    return work_details[idx]
end

local function make_window_name(wd)
    if wd.name == '' then return 'Work detail' .. ': Customize icon'
    else return wd.name .. ': Customize icon' end
end

local WINDOW_WIDTH = 60
local WINDOW_HEIGHT = 40

local CUR_ICON_TOTAL_W = 13

local TopPanel = widgets.Panel{
    view_id='top',
    frame={h=5, t=0},
    frame_style=gui.FRAME_INTERIOR,
    subviews={
        widgets.Label{
            frame={l=0, t=0},
            text={'Current', NEWLINE, 'icon:'}
        },
        widgets.Label{
            id='current_icon',
            frame={l=CUR_ICON_TOTAL_W-5, t=0},
            text=wdi.make_icon_text(vanilla.MINERS),
        },
        widgets.Divider{
            frame={w=1, l=CUR_ICON_TOTAL_W},
            frame_style_t=false,
            frame_style_b=false,
        },
    }
}

local VanillaIcons = widgets.Panel{
    view_id='vanilla',
    frame_title='Dwarf Fortress:',
    frame={h=10},
    frame_style=gui.FRAME_INTERIOR,
}

local guiWindow = widgets.ResizingPanel{
    view_id='main_window',
    frame_title=make_window_name(get_current_wd()),
    frame={w=WINDOW_WIDTH, h=WINDOW_HEIGHT},
    frame_style=gui.FRAME_WINDOW,
    frame_background=gui.CLEAR_PEN,
    draggable=true,
    autoarrange_subviews=true,
    subviews={
        TopPanel,
        VanillaIcons,
    }
}

local guiwdi = defclass(guiwdi, gui.ZScreen)
guiwdi.ATTRS{
    focus_string='work-detail-icons',
}

function guiwdi:init()
    self:addviews{guiWindow}
end

function guiwdi:onDismiss()
    view = nil
end

local function show_gui(wd)
    if wd then
        view = view and view:raise() or guiwdi{}:show()
    end
end

--
-- WD screen button
--

SummonButton = defclass(SummonButton, overlay.OverlayWidget)
SummonButton.ATTRS{
    desc='Adds a button for icon customization to the work details screen',
    default_enabled=true,
    viewscreens='dwarfmode/Info/LABOR/WORK_DETAILS/Default',
    default_pos={x=90, y=11},
    frame={w=21, h=3},
    frame_style=gui.FRAME_MEDIUM,
}

function SummonButton:init()
    self:addviews{
        widgets.HotkeyLabel{
            view_id='button',
            key='CUSTOM_CTRL_C',
            label='Change icon',
        }
    }
end

-- this causes the script to run whenever the overlay is displayed,
-- regardless of input. is it supposed to work like that?
-- function SummonButton:onRenderFrame(dc, rect)
    -- self.subviews.button:setOnActivate(show_gui(get_current_wd()))
    -- SummonButton.super.onRenderFrame(self, dc, rect)
-- end

OVERLAY_WIDGETS = {
    shortcut=SummonButton,
}

--
-- CLI
--

if not dfhack.isMapLoaded() then
    qerror('this script requires a fortress map to be loaded')
end

show_gui(get_current_wd())
