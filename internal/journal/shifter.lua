-- >> / << toggle button
--@ module = true

local widgets = require 'gui.widgets'

local TO_THE_RIGHT = string.char(16)
local TO_THE_LEFT = string.char(17)

function get_shifter_text(state)
    local ch = state and TO_THE_RIGHT or TO_THE_LEFT
    return {
        ' ', NEWLINE,
        ch, NEWLINE,
        ch, NEWLINE,
        ' ', NEWLINE,
    }
end

Shifter = defclass(Shifter, widgets.Widget)
Shifter.ATTRS {
    frame={l=0, w=1, t=0, b=0},
    collapsed=false,
    on_changed=DEFAULT_NIL,
}

function Shifter:init()
    self:addviews{
        widgets.Label{
            view_id='shifter_label',
            frame={l=0, r=0, t=0, b=0},
            text=get_shifter_text(self.collapsed),
            on_click=function ()
                self:toggle(not self.collapsed)
            end
        }
    }
end

function Shifter:toggle(state)
    if state == nil then
        self.collapsed = not self.collapsed
    else
        self.collapsed = state
    end

    self.subviews.shifter_label:setText(
        get_shifter_text(self.collapsed)
    )

    self:updateLayout()

    if self.on_changed then
        self.on_changed(self.collapsed)
    end
end
