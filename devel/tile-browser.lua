local gui = require('gui')
local widgets = require('gui.widgets')

local raws = df.global.enabler.textures.raws

TileBrowser = defclass(TileBrowser, gui.ZScreen)
TileBrowser.ATTRS{
    focus_string='tile-browser',
}

function TileBrowser:init()
    self.dirty = true

    local main_panel = widgets.Window{
        frame_title='Tile Browser',
        frame={w=35, h=30},
        resizable=true,
        resize_min={h=20},
    }

    main_panel:addviews{
        widgets.EditField{
            view_id='start_index',
            frame={t=0, l=0},
            key='CUSTOM_ALT_S',
            label_text='Start index: ',
            text='0',
            on_submit=self:callback('set_start_index'),
            on_char=function(ch) return ch:match('%d') end,
        },
        widgets.Label{
            view_id='header',
            frame={t=2, l=8},
            text='0123456789 0123456789',
        },
        widgets.Label{
            view_id='report',
            frame={t=3, b=3, l=0},
            auto_height=false,
        },
        widgets.Label{
            view_id='footer',
            frame={b=2, l=8},
            text='0123456789 0123456789',
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            label='Prev',
            key='KEYBOARD_CURSOR_UP_FAST',
            auto_width=true,
            on_activate=self:callback('shift_start_index', -1000),
        },
        widgets.Label{
            frame={b=0, l=6, w=1},
            text={{text=string.char(24), pen=COLOR_LIGHTGREEN}},
        },
        widgets.HotkeyLabel{
            frame={b=0, l=18},
            label='Next',
            key='KEYBOARD_CURSOR_DOWN_FAST',
            auto_width=true,
            on_activate=self:callback('shift_start_index', 1000),
        },
        widgets.Label{
            frame={b=0, l=24, w=1},
            text={{text=string.char(25), pen=COLOR_LIGHTGREEN}},
        },
    }
    self:addviews{main_panel}
end

function TileBrowser:shift_start_index(amt)
    self:set_start_index(tonumber(self.subviews.start_index.text) + amt)
end

function TileBrowser:set_start_index(idx)
    idx = tonumber(idx)
    if not idx then return end

    idx = math.max(0, math.min(#raws - 980, idx))

    idx = idx - (idx % 20) -- floor to nearest multiple of 20
    self.subviews.start_index:setText(tostring(idx))
    self.dirty = true
end

function TileBrowser:update_report()
    local idx = tonumber(self.subviews.start_index.text)
    local end_idx = math.min(#raws-1, idx+999)

    local report = {}
    for texpos=idx,end_idx do
        if texpos % 20 == 0 then
            table.insert(report, {text=texpos, width=7, rjustify=true})
            table.insert(report, ' ')
        elseif texpos % 10 == 0 then
            table.insert(report, ' ')
        end
        table.insert(report, {tile=texpos, pen=gui.KEEP_LOWER_PEN, width=1})
        if (texpos+1) % 20 == 0 then
            table.insert(report, NEWLINE)
        end
    end

    self.subviews.report:setText(report)
end

function TileBrowser:onRenderFrame()
    if self.dirty then
        self:update_report()
        self.dirty = false
    end
end

function TileBrowser:onDismiss()
    view = nil
end

view = view and view:raise() or TileBrowser{}:show()
