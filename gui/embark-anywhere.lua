local gui = require('gui')
local widgets = require('gui.widgets')

EmbarkAnywhere = defclass(EmbarkAnywhere, widgets.Window)
EmbarkAnywhere.ATTRS {
    frame_title='Embark Anywhere',
    frame={w=32, h=15, l=0, b=0},
    autoarrange_subviews=true,
    autoarrange_gap=1,
}

function EmbarkAnywhere:init()
    self:addviews{
        widgets.WrappedLabel{
            text_to_wrap='Click anywhere on the map to ignore warnings and embark wherever you want.',
        },
        widgets.WrappedLabel{
            text_to_wrap='There may be unforeseen consequences when embarking where the game doesn\'t expect.',
            text_pen=COLOR_YELLOW,
        },
        widgets.WrappedLabel{
            text_to_wrap='Right click on this window to cancel.',
        },
    }
end

EmbarkAnywhereScreen = defclass(EmbarkAnywhereScreen, gui.ZScreen)
EmbarkAnywhereScreen.ATTRS {
    focus_path='embark-anywhere',
    pass_movement_keys=true,
}

local function is_confirm_panel_visible()
    local scr = dfhack.gui.getDFViewscreen(true)
    if df.viewscreen_choose_start_sitest:is_instance(scr) then
        return scr.zoomed_in and scr.choosing_embark and scr.warn_flags.GENERIC
    end
end

function EmbarkAnywhereScreen:init()
    self:addviews{
        EmbarkAnywhere{view_id='main'},
        widgets.Panel{
            frame={l=20, t=1, w=22, h=6},
            frame_style=gui.FRAME_MEDIUM,
            frame_background=gui.CLEAR_PEN,
            subviews={
                widgets.Label{
                    text={
                        'Any embark warnings', NEWLINE,
                        'have been bypassed.', NEWLINE,
                        NEWLINE,
                        {text='Good luck!', pen=COLOR_GREEN},
                    },
                },
            },
            visible=is_confirm_panel_visible,
        },
        widgets.Panel{
            view_id='masks',
            frame={t=0, b=0, l=0, r=0},
            subviews={
                widgets.Panel{ -- size selection panel
                    frame={l=0, t=0, w=61, h=11},
                },
                widgets.Panel{ -- abort button
                    frame={r=41, b=1, w=10, h=3},
                },
                widgets.Panel{ -- show elevation button
                    frame={r=22, b=1, w=18, h=3},
                },
                widgets.Panel{ -- show cliffs button
                    frame={r=0, b=1, w=21, h=3},
                },
            },
        },
    }
end

function EmbarkAnywhereScreen:isMouseOver()
    return self.subviews.main:getMouseFramePos()
end

local function force_embark(scr)
    -- causes selected embark area to be highlighted on the map
    scr.warn_mm_startx = scr.neighbor_hover_mm_sx
    scr.warn_mm_endx = scr.neighbor_hover_mm_ex
    scr.warn_mm_starty = scr.neighbor_hover_mm_sy
    scr.warn_mm_endy = scr.neighbor_hover_mm_ey

    -- setting any warn_flag will cause the accept embark panel to be shown
    -- clicking accept on that panel will accept the embark, regardless of
    -- how inappropriate it is
    scr.warn_flags.GENERIC = true
end

function EmbarkAnywhereScreen:clicked_on_panel_mask()
    for _, sv in ipairs(self.subviews.masks.subviews) do
        if sv:getMousePos() then return true end
    end
end

function EmbarkAnywhereScreen:onInput(keys)
    local scr = dfhack.gui.getDFViewscreen(true)
    if keys.LEAVESCREEN and not scr.zoomed_in then
        -- we have to make sure we're off the stack when returning to the title screen
        -- since the top viewscreen will get unceremoniously destroyed by DF
        self.defocused = false
    elseif keys._MOUSE_L and scr.choosing_embark and
        not self.subviews.main:getMouseFramePos() and
        not self:clicked_on_panel_mask()
    then
        -- clicked on the map -- time to do our thing
        force_embark(scr)
    end

    return EmbarkAnywhereScreen.super.onInput(self, keys)
end

function EmbarkAnywhereScreen:onDismiss()
    view = nil
end

function EmbarkAnywhereScreen:onRenderFrame(dc, rect)
    local scr = dfhack.gui.getDFViewscreen(true)
    if not dfhack.gui.matchFocusString('choose_start_site', scr) then
        self:dismiss()
    end
    EmbarkAnywhereScreen.super.onRenderFrame(self, dc, rect)
end

if not dfhack.gui.matchFocusString('choose_start_site') then
    qerror('This script can only be run when choosing an embark site')
end

view = view and view:raise() or EmbarkAnywhereScreen{}:show()
