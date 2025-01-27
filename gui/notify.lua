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
    default_enabled=true,
    frame={w=30, h=LIST_MAX_HEIGHT+2},
    right_offset=DEFAULT_NIL,
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
                        if not choice.data.on_click then return end
                        local prev_state = self.state[choice.data.name]
                        self.state[choice.data.name] = choice.data.on_click(prev_state, false)
                    end,
                    on_submit2=function(_, choice)
                        if not choice.data.on_click then return end
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

function NotifyOverlay:onInput(keys)
    if keys.SELECT then return false end

    return NotifyOverlay.super.onInput(self, keys)
end

local function get_fn(notification, is_adv)
    if not notification then return end
    if is_adv then
        return notification.adv_fn or notification.fn
    end
    return notification.dwarf_fn or notification.fn
end

function NotifyOverlay:overlay_onupdate()
    local choices = {}
    local is_adv = dfhack.world.isAdventureMode()
    self.critical = false
    for _, notification in ipairs(notifications.NOTIFICATIONS_BY_IDX) do
        if not notifications.config.data[notification.name].enabled then goto continue end
        local fn = get_fn(notification, is_adv)
        if not fn then goto continue end
        local str = fn()
        if str then
            table.insert(choices, {
                text=str,
                data=notification,
            })
            self.critical = self.critical or notification.critical
        end
        ::continue::
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
    if self.frame_parent_rect then
        self:preUpdateLayout(self.frame_parent_rect)
    end
end

function NotifyOverlay:preUpdateLayout(parent_rect)
    local frame_rect = self.frame_rect
    if not frame_rect then return end
    local list = self.subviews.list
    local list_width, num_choices = list:getContentWidth(), #list:getChoices()
    -- +2 for the frame
    self.frame.w = math.min(list_width + 2, parent_rect.width - (frame_rect.x1 + self.right_offset))
    if num_choices <= LIST_MAX_HEIGHT then
        self.frame.h = num_choices + 2
    else
        self.frame.w = self.frame.w + 3 -- for the scrollbar
        self.frame.h = LIST_MAX_HEIGHT + 2
    end
end

--
-- DwarfNotifyOverlay, AdvNotifyOverlay
--

DwarfNotifyOverlay = defclass(DwarfNotifyOverlay, NotifyOverlay)
DwarfNotifyOverlay.ATTRS{
    desc='Shows list of active notifications in fort mode.',
    default_pos={x=1,y=-8},
    viewscreens='dwarfmode/Default',
    right_offset=3,
}

local DWARFMODE_CONFLICTING_TOOLTIPS = utils.invert{
    df.main_hover_instruction.MAIN_OPEN_CREATURES,
    df.main_hover_instruction.MAIN_OPEN_TASKS,
    df.main_hover_instruction.MAIN_OPEN_PLACES,
    df.main_hover_instruction.MAIN_OPEN_LABOR,
    df.main_hover_instruction.MAIN_OPEN_WORK_ORDERS,
    df.main_hover_instruction.MAIN_OPEN_NOBLES,
    df.main_hover_instruction.MAIN_OPEN_OBJECTS,
    df.main_hover_instruction.MAIN_OPEN_JUSTICE,
}

local mi = df.global.game.main_interface

function DwarfNotifyOverlay:render(dc)
    if not DWARFMODE_CONFLICTING_TOOLTIPS[mi.current_hover] then
        NotifyOverlay.super.render(self, dc)
    end
end

AdvNotifyOverlay = defclass(AdvNotifyOverlay, NotifyOverlay)
AdvNotifyOverlay.ATTRS{
    desc='Shows list of active notifications in adventure mode.',
    default_pos={x=18,y=-5},
    viewscreens='dungeonmode/Default',
    overlay_onupdate_max_freq_seconds=1,
    right_offset=13,
}

function AdvNotifyOverlay:set_width()
    local desired_width = 13
    if df.global.adventure.player_control_state ~= df.adventurest.T_player_control_state.TAKING_INPUT then
        local offset = self.frame_parent_rect.width > 137 and 26 or
            (self.frame_parent_rect.width+1) // 2 - 43
        desired_width = self.frame_parent_rect.width // 2 + offset
    end
    if self.right_offset ~= desired_width then
        self.right_offset = desired_width
        self:updateLayout()
    end
end

function AdvNotifyOverlay:render(dc)
    if mi.current_hover > -1 then return end
    self:set_width()
    if self.critical and self.prev_tick_counter ~= df.global.adventure.tick_counter then
        self.prev_tick_counter = df.global.adventure.tick_counter
        self:overlay_onupdate()
    end
    AdvNotifyOverlay.super.render(self, dc)
end

OVERLAY_WIDGETS = {
    panel=DwarfNotifyOverlay,
    advpanel=AdvNotifyOverlay,
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
                        self.subviews.desc.text_to_wrap = choice and choice.desc or ''
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
    local is_adv = dfhack.world.isAdventureMode()
    for name, conf in pairs(notifications.config.data) do
        local notification = notifications.NOTIFICATIONS_BY_NAME[name]
        if not get_fn(notification, is_adv) then goto continue end
        table.insert(choices, {
            name=name,
            desc=notification.desc,
            enabled=conf.enabled,
            text={
                ('%20s: '):format(name),
                {
                    text=conf.enabled and 'Enabled' or 'Disabled',
                    pen=conf.enabled and COLOR_GREEN or COLOR_RED,
                }
            }
        })
        ::continue::
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
