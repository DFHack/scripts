-- confirm plugin options
--[====[

gui/confirm-opts
================
A basic configuration interface for the `confirm` plugin.

]====]


confirm = require 'plugins.confirm'
gui = require 'gui'
widgets = require 'gui.widgets'

Opts = defclass(Opts, gui.FramedScreen)
Opts.ATTRS = {
    frame_style = gui.GREY_LINE_FRAME,
    frame_title = 'Confirmation dialogs',
    frame_width = 32,
    frame_height = 12,
    frame_inset = 1,
    focus_path = 'confirm/opts',
}

function Opts:init()
    self:addviews{
        widgets.List{
            view_id = 'list',
            frame = {t = 0, l = 0},
            text_pen = COLOR_GREY,
            cursor_pen = COLOR_WHITE,
            choices = {},
            on_submit = self:callback('toggle'),
            on_submit2 = self:callback('toggle_all'),
        },
        widgets.HotkeyLabel{
            frame = {b=2, l=0},
            label='Resume paused confirmations',
            key='CUSTOM_P',
            on_activate=function() confirm.unpause() self:refresh() end,
            enabled=function() return self.paused end},
        widgets.Label{
            view_id = 'controls',
            frame = {b = 0, l = 0},
            text = {
                {key = 'SELECT', text = ': Toggle, '},
                {key = 'LEAVESCREEN', text = ': Back', on_activate = self:callback('dismiss')},
                NEWLINE,
                {key = 'SEC_SELECT', text = ': Toggle all'},
            },
        },
        widgets.Label{
            view_id = 'scroll_up',
            frame = {t = 0, l = self.frame_width - 1},
            text = {{pen = COLOR_LIGHTCYAN, text=function()
                return self.subviews.list.page_top ~= 1 and string.char(24) or ''
            end}},
        },
        widgets.Label{
            view_id = 'scroll_down',
            frame = {t = 1, l = self.frame_width - 1},
            text = {{pen = COLOR_LIGHTCYAN, text=function()
                local list = self.subviews.list
                return list.page_top + list.page_size < #list:getChoices() and string.char(25) or ''
            end}},
        }
    }
    self:refresh()

    -- restrict the list to above the controls
    self.subviews.list.frame.h = self.frame_height - self.subviews.controls.frame.h - 2
    -- move the down arrow next to the bottom of the list
    self.subviews.scroll_down.frame.t = self.subviews.list.frame.h - 1

    local active_id = confirm.get_active_id()
    for i, choice in ipairs(self.subviews.list:getChoices()) do
        if choice.id == active_id then
            self.subviews.list:setSelected(i)
            break
        end
    end
end

function Opts:refresh()
    self.data = confirm.get_conf_data()
    self.paused = confirm.get_paused()
    local choices = {}
    for i, c in ipairs(self.data) do
        table.insert(choices, {
            id = c.id,
            enabled = c.enabled,
            text = {
                c.id .. ': ',
                {
                    text = c.enabled and 'Enabled' or 'Disabled',
                    pen = self:callback('choice_pen', i, c.enabled)
                }
            }
        })
    end
    self.subviews.list:setChoices(choices)
end

function Opts:choice_pen(index, enabled)
    return (enabled and COLOR_GREEN or COLOR_RED) + (index == self.subviews.list:getSelected() and 8 or 0)
end

function Opts:toggle(_, choice)
    confirm.set_conf_state(choice.id, not choice.enabled)
    self:refresh()
end

function Opts:toggle_all(_, choice)
    for _, c in pairs(self.data) do
        confirm.set_conf_state(c.id, not choice.enabled)
    end
    self:refresh()
end

Opts():show()
