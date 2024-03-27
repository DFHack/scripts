-- open legends screen when in fortress mode

local dialogs = require('gui.dialogs')
local gui = require('gui')
local widgets = require('gui.widgets')

-- --------------------------------
-- LegendsManager
--

LegendsManager = defclass(LegendsManager, gui.Screen)
LegendsManager.ATTRS {
    focus_path='open-legends',
}

function LegendsManager:init()
    df.global.gametype = df.game_type.VIEW_LEGENDS

    local legends = df.viewscreen_legendsst:new()
    legends.page:insert("#",{new=true, header="Legends", mode=0, index=-1})
    dfhack.screen.show(legends)

    self:addviews{
        widgets.Panel{
            view_id='done_mask',
            frame={t=1, r=1, w=9, h=3},
        },
    }
end

function LegendsManager:render()
    self:renderParent()
end

function LegendsManager:onInput(keys)
    if keys.LEAVESCREEN or (keys._MOUSE_L and self.subviews.done_mask:getMousePos()) then
        dialogs.showMessage('Exiting to avoid save corruption',
            'Dwarf Fortress may be in a non-playable state\nand will now exit to protect your savegame.',
            COLOR_YELLOW,
            self:callback('dismiss'))
        return true
    end
    self:sendInputToParent(keys)
    return true
end

function LegendsManager:onDismiss()
    dfhack.run_command('die')
end

-- --------------------------------
-- LegendsWarning
--

LegendsWarning = defclass(LegendsWarning, widgets.Window)
LegendsWarning.ATTRS {
    frame_title='Open Legends Mode',
    frame={w=50, h=21},
    autoarrange_subviews=true,
}

function LegendsWarning:init()
    self:addviews{
        widgets.Label{
            text={
                'This script allows you to jump into legends', NEWLINE,
                'mode from a loaded fort, but beware that this', NEWLINE,
                'is a', {gap=1, text='ONE WAY TRIP', pen=COLOR_RED}, '.', NEWLINE,
                NEWLINE,
                'Returning to fort mode from legends mode', NEWLINE,
                'would make the game unstable, so to protect', NEWLINE,
                'your savegame, Dwarf Fortress will exit when', NEWLINE,
                'you are done browsing.', NEWLINE,
                NEWLINE,
                {text='This is your last chance to save your game.', pen=COLOR_LIGHTRED}, NEWLINE,
                NEWLINE,
            },
        },
        widgets.HotkeyLabel{
            frame={l=0},
            key='CUSTOM_SHIFT_S',
            label='Please click here to create an Autosave',
            text_pen=COLOR_YELLOW,
            on_activate=function() dfhack.run_command('quicksave') end,
        },
        widgets.Label{
            text={
                NEWLINE,
                'or exit out of this dialog and create a named', NEWLINE,
                'save of your choice.', NEWLINE,
                NEWLINE,
            },
        },
        widgets.HotkeyLabel{
            key='CUSTOM_ALT_L',
            label='Click here to continue to legends mode',
            auto_width=true,
            on_activate=function()
                self.parent_view:dismiss()
                LegendsManager{}:show()
            end,
        },
    }
end

LegendsWarningScreen = defclass(LegendsWarningScreen, gui.ZScreenModal)
LegendsWarningScreen.ATTRS {
    focus_path='open-legends/warning',
}

function LegendsWarningScreen:init()
    self:addviews{LegendsWarning{}}
end

function LegendsWarningScreen:onDismiss()
    view = nil
end

if not dfhack.isWorldLoaded() then
    qerror('no world loaded')
end

view = view and view:raise() or LegendsWarningScreen{}:show()
