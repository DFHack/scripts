local gui = require('gui')
local overlay = require('plugins.overlay')
local spectate = require('plugins.spectate')
local textures = require('gui.textures')
local utils = require('utils')
local widgets = require('gui.widgets')

local OVERLAY_NAME = 'spectate.tooltip'

--------------------------------------------------------------------------------
--- ToggleLabel

-- pens are the same as gui/control-panel.lua
local function get_icon_pens()
    local enabled_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 1), ch=string.byte('[')}
    local enabled_pen_center = dfhack.pen.parse{fg=COLOR_LIGHTGREEN,
            tile=curry(textures.tp_control_panel, 2) or nil, ch=251} -- check
    local enabled_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 3) or nil, ch=string.byte(']')}
    local disabled_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 4) or nil, ch=string.byte('[')}
    local disabled_pen_center = dfhack.pen.parse{fg=COLOR_RED,
            tile=curry(textures.tp_control_panel, 5) or nil, ch=string.byte('x')}
    local disabled_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 6) or nil, ch=string.byte(']')}
    return enabled_pen_left, enabled_pen_center, enabled_pen_right,
            disabled_pen_left, disabled_pen_center, disabled_pen_right
end
local ENABLED_PEN_LEFT, ENABLED_PEN_CENTER, ENABLED_PEN_RIGHT,
      DISABLED_PEN_LEFT, DISABLED_PEN_CENTER, DISABLED_PEN_RIGHT = get_icon_pens()

ToggleLabel = defclass(ToggleLabel, widgets.ToggleHotkeyLabel)

function ToggleLabel:init()
    local text = self.text
    -- the very last token is the On/Off text -- we'll repurpose it as an indicator
    text[#text] =     { tile = function() return self:getOptionValue() and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT end }
    text[#text + 1] = { tile = function() return self:getOptionValue() and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER end }
    text[#text + 1] = { tile = function() return self:getOptionValue() and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT end }
    self:setText(text)
end

--------------------------------------------------------------------------------
--- Spectate config window
Spectate = defclass(Spectate, widgets.Window)
Spectate.ATTRS {
    frame_title='Spectate',
    frame={l=5, t=5, w=36, h=39},
}

local function create_toggle_button(frame, cfg_elem, hotkey, label, cfg_elem_key)
    return ToggleLabel{
        frame=frame,
        initial_option=spectate.get_config_elem(cfg_elem, cfg_elem_key),
        on_change=function(val) dfhack.run_command('spectate', 'set', cfg_elem, tostring(val)) end,
        key=hotkey,
        label=label,
    }
end

local function create_numeric_edit_field(frame, cfg_elem, hotkey, label)
    local editOnSubmit
    local ef = widgets.EditField{
        frame=frame,
        label_text = label,
        text = tostring(spectate.get_config_elem(cfg_elem)),
        modal = true,
        key = hotkey,
        on_char = function(ch) return ch:match('%d') end,
        on_submit = function(text) editOnSubmit(text) end,
    }
    editOnSubmit = function(text)
        if text == '' then
            ef:setText(tostring(spectate.get_config_elem(cfg_elem)))
        else
            dfhack.run_command('spectate', 'set', cfg_elem, text)
        end
    end

    return ef
end

local function create_row_toggle_buttons(keyFollow, keyHover, colFollow, colHover, cfg_elem_key)
    local tlFollow = create_toggle_button({l=colFollow+2}, keyFollow, nil, nil, cfg_elem_key)
    local tlHover = create_toggle_button({l=colHover+1}, keyHover, nil, nil, cfg_elem_key)
    return tlFollow, tlHover
end

local function create_row(frame, label, hotkey, suffix, colFollow, colHover)
    suffix = suffix or ''
    if suffix ~= '' then suffix = '-'..suffix end

    local keyFollow = 'tooltip-follow'..suffix
    local keyHover = 'tooltip-hover'..suffix

    local tlFollow, tlHover = create_row_toggle_buttons(keyFollow, keyHover, colFollow, colHover)

    return widgets.Panel{
        frame=utils.assign({h=1}, frame),
        subviews={
            widgets.HotkeyLabel{
                frame={l=0,w=1},
                key='CUSTOM_' .. hotkey,
                key_sep='',
                on_activate=function() tlFollow:cycle() end,
            },
            widgets.HotkeyLabel{
                frame={l=1,w=1},
                key='CUSTOM_SHIFT_' .. hotkey,
                key_sep='',
                on_activate=function() tlHover:cycle() end,
            },
            widgets.Label{
                frame={l=2},
                text = ': ' .. label,
            },
            tlFollow,
            tlHover,
        },
    }
end

local function make_choice(text, tlFollow, tlHover)
    return {
        text=text,
        data={tlFollow=tlFollow, tlHover=tlHover},
    }
end

-- individual stress levels
-- a list on the left to select one, individual buttons in two columns to be able to click on them
local function create_stress_list(frame, colFollow, colHover)
    local levelsKey = 'tooltip-stress-levels'
    local stressFollowKey = 'tooltip-follow-stress-levels'
    local stressHoverKey = 'tooltip-hover-stress-levels'

    local choices, subviews = {}, {}
    for idx=0,6 do
        local cfgElemKey = tostring(idx)
        local tlFollow, tlHover = create_row_toggle_buttons(stressFollowKey, stressHoverKey, colFollow, colHover, cfgElemKey)
        table.insert(subviews, widgets.Panel{
            frame={t=idx, h=1},
            subviews={
                tlFollow,
                tlHover,
            }
        })

        local elem = spectate.get_config_elem(levelsKey, cfgElemKey)
        table.insert(choices, make_choice({{text=elem.text, pen=elem.pen}, ' ', elem.name}, tlFollow, tlHover))
    end

    table.insert(subviews, widgets.List{
        frame={l=2},
        on_submit=function(_, choice) choice.data.tlFollow:cycle() end,
        on_submit2=function(_, choice) choice.data.tlHover:cycle() end,
        choices=choices,
    })

    return widgets.Panel{
        frame=frame,
        subviews=subviews,
    }
end

local function rpad(s, i)
    return string.format("%-"..i.."s", s)
end

function Spectate:init()
    local lWidth = 21
    local colFollow, colHover = 15, 25

    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text='See help for option details:',
        },
        widgets.HelpButton{
            frame={t=0, r=0},
            command = 'spectate',
        },
        ToggleLabel{
            frame={t=2},
            view_id='spectate_mode',
            initial_option=spectate.isEnabled(),
            on_change=function(val) dfhack.run_command(val and 'enable' or 'disable', 'spectate') end,
            key='CUSTOM_ALT_E',
            label='Spectate mode ',
        },
        create_numeric_edit_field({t=4}, 'follow-seconds', 'CUSTOM_ALT_F', 'Switch target (sec): '),
        create_toggle_button({t=6}, 'auto-unpause', 'CUSTOM_ALT_U', rpad('Auto unpause', lWidth)),
        create_toggle_button({t=7}, 'cinematic-action', 'CUSTOM_ALT_C', rpad('Cinematic action', lWidth)),
        create_toggle_button({t=8}, 'include-animals', 'CUSTOM_ALT_A', rpad('Include animals', lWidth)),
        create_toggle_button({t=9}, 'include-hostiles', 'CUSTOM_ALT_H', rpad('Include hostiles', lWidth)),
        create_toggle_button({t=10}, 'include-visitors', 'CUSTOM_ALT_V', rpad('Include visitors', lWidth)),
        create_toggle_button({t=11}, 'include-wildlife', 'CUSTOM_ALT_W', rpad('Include wildlife', lWidth)),
        create_toggle_button({t=12}, 'prefer-conflict', 'CUSTOM_ALT_B', rpad('Prefer conflict', lWidth)),
        create_toggle_button({t=13}, 'prefer-new-arrivals', 'CUSTOM_ALT_N', rpad('Prefer new arrivals', lWidth)),
        widgets.Divider{
            frame={t=15, h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
        },
        widgets.Label{
            frame={t=17, l=0},
            text="Tooltips:"
        },
        ToggleLabel{
            frame={t=17, l=12},
            initial_option=overlay.isOverlayEnabled(OVERLAY_NAME),
            on_change=function(val) dfhack.run_command('overlay', val and 'enable' or 'disable', OVERLAY_NAME) end,
            key='CUSTOM_ALT_O',
            label="Overlay ",
        },
        widgets.Label{
            frame={t=19, l=colFollow},
            text='Follow',
        },
        widgets.Label{
            frame={t=19, l=colHover},
            text='Hover',
        },
        create_row({t=21}, 'Enabled', 'E', '', colFollow, colHover),
        create_numeric_edit_field({t=23}, 'tooltip-follow-blink-milliseconds', 'CUSTOM_B', 'Blink period (ms): '),
        create_row({t=25}, 'Job', 'J', 'job', colFollow, colHover),
        create_row({t=26}, 'Name', 'N', 'name', colFollow, colHover),
        create_row({t=27}, 'Stress', 'S', 'stress', colFollow, colHover),
        create_stress_list({t=28}, colFollow, colHover),
    }
end

function Spectate:render(dc)
    self.subviews.spectate_mode:setOption(spectate.isEnabled())
    Spectate.super.render(self, dc)
end

SpectateScreen = defclass(SpectateScreen, gui.ZScreen)
SpectateScreen.ATTRS {
    focus_path='spectate',
}

function SpectateScreen:init()
    self:addviews{Spectate{}}
end

function SpectateScreen:onDismiss()
    view = nil
end

view = view and view:raise() or SpectateScreen{}:show()
