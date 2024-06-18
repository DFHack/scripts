-- config ui for confirm

local confirm = reqscript('confirm')
local gui = require('gui')
local widgets = require('gui.widgets')

Confirm = defclass(Confirm, widgets.Window)
Confirm.ATTRS{
    frame_title='Confirmation dialogs',
    frame={w=42, h=17},
    initial_id=DEFAULT_NIL,
}

function Confirm:init()
    self:addviews{
        widgets.List{
            view_id='list',
            frame={t=0, l=0, b=2},
            on_submit=self:callback('toggle'),
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

    if self.initial_id then
        for i, choice in ipairs(self.subviews.list:getChoices()) do
            if choice.id == self.initial_id then
                self.subviews.list:setSelected(i)
                break
            end
        end
    end
end

function Confirm:refresh()
    local choices = {}
    for id, conf in pairs(confirm.get_state()) do
        table.insert(choices, {
            id=id,
            enabled=conf.enabled,
            text={
                id,
                ': ',
                {
                    text=conf.enabled and 'Enabled' or 'Disabled',
                    pen=conf.enabled and COLOR_GREEN or COLOR_RED,
                }
            }
        })
    end
    table.sort(choices, function(a, b) return a.id < b.id end)
    local list = self.subviews.list
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setSelected(selected)
end

function Confirm:toggle(_, choice)
    if not choice then return end
    confirm.set_enabled(choice.id, not choice.enabled)
    self:refresh()
end

function Confirm:toggle_all()
    local choice = self.subviews.list:getChoices()[1]
    if not choice then return end
    local target_state = not choice.enabled
    for id in pairs(confirm.get_state()) do
        confirm.set_enabled(id, target_state)
    end
    self:refresh()
end

ConfirmScreen = defclass(ConfirmScreen, gui.ZScreen)
ConfirmScreen.ATTRS {
    focus_path='confirm/config',
    initial_id=DEFAULT_NIL,
}

function ConfirmScreen:init()
    self:addviews{Confirm{initial_id=self.initial_id}}
end

function ConfirmScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

local initial_id = ({...})[1] -- set when called from confirm dialogs
view = view and view:raise() or ConfirmScreen{initial_id=initial_id}:show()
