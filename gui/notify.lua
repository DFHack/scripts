--@module = true

local gui = require('gui')
local notifications = reqscript('internal/notify/notifications')
local overlay = require('plugins.overlay')
local utils = require('utils')
local widgets = require('gui.widgets')

--
-- NotifyOverlay
--

local LIST_MAX_HEIGHT = 5

NotifyOverlay = defclass(NotifyOverlay, overlay.OverlayWidget)
NotifyOverlay.ATTRS{
    desc='Shows list of active notifications.',
    default_pos={x=1,y=-8},
    default_enabled=true,
    viewscreens='dwarfmode/Default',
    frame={w=30, h=LIST_MAX_HEIGHT+2},
}

function NotifyOverlay:init()
    self.state = {}

    self:addviews{
        widgets.Panel{
            view_id='panel',
            frame_style=gui.MEDIUM_FRAME,
            frame_background=gui.CLEAR_PEN,
            subviews={
                widgets.List{
                    view_id='list',
                    frame={t=0, b=0, l=0, r=0},
                    -- disable scrolling with the keyboard since some people
                    -- have wasd mapped to the arrow keys
                    scroll_keys={},
                    on_submit=function(_, choice)
                        local prev_state = self.state[choice.data.name]
                        self.state[choice.data.name] = choice.data.on_click(prev_state, false)
                    end,
                    on_submit2=function(_, choice)
                        local prev_state = self.state[choice.data.name]
                        self.state[choice.data.name] = choice.data.on_click(prev_state, true)
                    end,
                },
            },
        },
        widgets.ConfigureButton{
            frame={t=0, r=1},
            on_click=function() dfhack.run_script('gui/notify') end,
        }
    }
end

function NotifyOverlay:overlay_onupdate()
    local choices = {}
    local max_width = 20
    for _, notification in ipairs(notifications.NOTIFICATIONS_BY_IDX) do
        if notifications.config.data[notification.name].enabled then
            local str = notification.fn()
            if str then
                max_width = math.max(max_width, #str)
                table.insert(choices, {
                    text=str,
                    data=notification,
                })
            end
        end
    end
    -- +2 for the frame
    self.frame.w = max_width + 2
    if #choices <= LIST_MAX_HEIGHT then
        self.frame.h = #choices + 2
    else
        self.frame.w = self.frame.w + 3 -- for the scrollbar
        self.frame.h = LIST_MAX_HEIGHT + 2
    end
    local list = self.subviews.list
    local idx = 1
    local _, selected = list:getSelected()
    if selected then
        for i, v in ipairs(choices) do
            if v.data.name == selected.data.name then
                idx = i
                break
            end
        end
    end
    list:setChoices(choices, idx)
    self.visible = #choices > 0
end

local CONFLICTING_TOOLTIPS = utils.invert{
    df.main_hover_instruction.InfoUnits,
    df.main_hover_instruction.InfoJobs,
    df.main_hover_instruction.InfoPlaces,
    df.main_hover_instruction.InfoLabors,
    df.main_hover_instruction.InfoWorkOrders,
    df.main_hover_instruction.InfoNobles,
    df.main_hover_instruction.InfoObjects,
    df.main_hover_instruction.InfoJustice,
}

local mi = df.global.game.main_interface

function NotifyOverlay:render(dc)
    if not CONFLICTING_TOOLTIPS[mi.current_hover] then
        NotifyOverlay.super.render(self, dc)
    end
end

OVERLAY_WIDGETS = {
    panel=NotifyOverlay,
}

--
-- Notify
--

Notify = defclass(Notify, widgets.Window)
Notify.ATTRS{
    frame_title='Notification settings',
    frame={w=40, h=22},
}

function Notify:init()
    self:addviews{
        widgets.Panel{
            frame={t=0, l=0, b=7},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                widgets.List{
                    view_id='list',
                    on_submit=self:callback('toggle'),
                    on_select=function(_, choice)
                        self.subviews.desc.text_to_wrap = choice.desc
                        if self.frame_parent_rect then
                            self:updateLayout()
                        end
                    end,
                },
            },
        },
        widgets.Panel{
            frame={b=2, l=0, h=5},
            frame_style=gui.FRAME_INTERIOR,
            subviews={
                widgets.WrappedLabel{
                    view_id='desc',
                    auto_height=false,
                },
            },
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            label='Toggle',
            key='SELECT',
            auto_width=true,
            on_activate=function() self:toggle(self.subviews.list:getSelected()) end,
        },
        widgets.HotkeyLabel{
            frame={b=0, l=15},
            label='Toggle all',
            key='CUSTOM_CTRL_A',
            auto_width=true,
            on_activate=self:callback('toggle_all'),
        },
    }

    self:refresh()
end

function Notify:refresh()
    local choices = {}
    for name, conf in pairs(notifications.config.data) do
        table.insert(choices, {
            name=name,
            desc=notifications.NOTIFICATIONS_BY_NAME[name].desc,
            enabled=conf.enabled,
            text={
                ('%20s: '):format(name),
                {
                    text=conf.enabled and 'Enabled' or 'Disabled',
                    pen=conf.enabled and COLOR_GREEN or COLOR_RED,
                }
            }
        })
    end
    table.sort(choices, function(a, b) return a.name < b.name end)
    local list = self.subviews.list
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setSelected(selected)
end

function Notify:toggle(_, choice)
    if not choice then return end
    notifications.config.data[choice.name].enabled = not choice.enabled
    notifications.config:write()
    self:refresh()
end

function Notify:toggle_all()
    local choice = self.subviews.list:getChoices()[1]
    if not choice then return end
    local target_state = not choice.enabled
    for name in pairs(notifications.NOTIFICATIONS_BY_NAME) do
        notifications.config.data[name].enabled = target_state
    end
    notifications.config:write()
    self:refresh()
end

--
-- NotifyScreen
--

NotifyScreen = defclass(NotifyScreen, gui.ZScreen)
NotifyScreen.ATTRS {
    focus_path='notify',
}

function NotifyScreen:init()
    self:addviews{Notify{}}
end

function NotifyScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

view = view and view:raise() or NotifyScreen{}:show()
