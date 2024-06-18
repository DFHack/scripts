-- open legends screen when in fortress mode

local dialogs = require('gui.dialogs')
local gui = require('gui')
local utils = require('utils')
local widgets = require('gui.widgets')

tainted = tainted or false

-- --------------------------------
-- LegendsManager
--

LegendsManager = defclass(LegendsManager, gui.ZScreen)
LegendsManager.ATTRS {
    focus_path='open-legends',
    no_autoquit=false,
}

function LegendsManager:init()
    tainted = true

    -- back up what we can to make a return to the previous mode possible.
    -- note that even with these precautions, data **is lost** when switching
    -- to legends mode and back. testing shows that a savegame made directly
    -- after returning from legends mode will be **smaller** than a savegame
    -- made just before entering legends mode. We don't know exactly what is
    -- missing, but it shows that jumping back and forth between modes is not
    -- safe.
    self.region_details_backup = {} --as:df.world_region_details[]
    local vec = df.global.world.world_data.midmap_data.region_details
    utils.assign(self.region_details_backup, vec)
    vec:resize(0)

    self.gametype_backup = df.global.gametype
    df.global.gametype = df.game_type.VIEW_LEGENDS

    local legends = df.viewscreen_legendsst:new()
    legends.page:insert("#", {new=true, header="Legends", mode=0, index=-1})
    dfhack.screen.show(legends)

    self:addviews{
        widgets.Panel{
            view_id='done_mask',
            frame={t=1, r=1, w=9, h=3},
        },
    }
end

function LegendsManager:onInput(keys)
    if keys.LEAVESCREEN or (keys._MOUSE_L and self.subviews.done_mask:getMousePos()) then
        if self.no_autoquit then
            self:dismiss()
        else
            dialogs.showYesNoPrompt('Exiting to avoid save corruption',
                'Dwarf Fortress is in a non-playable state\nand will now exit to protect your savegame.',
                COLOR_YELLOW,
                self:callback('dismiss'))
        end
        return true
    end
    return LegendsManager.super.onInput(self, keys)
end

function LegendsManager:onDestroy()
    if not self.no_autoquit then
        dfhack.run_command('die')
    else
        df.global.gametype = self.gametype_backup

        local vec = df.global.world.world_data.midmap_data.region_details
        vec:resize(0)
        utils.assign(vec, self.region_details_backup)

        dfhack.run_script('devel/pop-screen')

        -- disable autosaves for the remainder of this session
        df.global.d_init.feature.autosave = df.d_init_autosave.NONE
    end
end

-- --------------------------------
-- LegendsWarning
--

LegendsWarning = defclass(LegendsWarning, widgets.Window)
LegendsWarning.ATTRS {
    frame_title='Open Legends Mode',
    frame={w=50, h=14},
    autoarrange_subviews=true,
    autoarrange_gap=1,
    no_autoquit=false,
}

function LegendsWarning:init()
    if not self.no_autoquit then
        self.frame.h = self.frame.h + 5
    end
    if dfhack.world.isFortressMode() then
        self.frame.h = self.frame.h + (self.no_autoquit and 7 or 2)
    end

    self:addviews{
        widgets.Label{
            text={
                'This script allows you to jump into legends', NEWLINE,
                'mode from a active game, but beware that this', NEWLINE,
                'is a', {gap=1, text='ONE WAY TRIP', pen=COLOR_RED}, '.', NEWLINE,
                NEWLINE,
                'Returning to play from legends mode', NEWLINE,
                'would make the game unstable, so to protect', NEWLINE,
                'your savegame, Dwarf Fortress will exit when', NEWLINE,
                'you are done browsing.',
            },
            visible=not self.no_autoquit,
        },
        widgets.Label{
            text={
                'You have opted for a ', {text='two-way ticket', pen=COLOR_RED} ,' to legends', NEWLINE,
                'mode. Remember to ', {text='quit to desktop and restart', pen=COLOR_RED}, NEWLINE,
                'DF when you\'re done to avoid save corruption.'
            },
            visible=self.no_autoquit,
        },
        widgets.Label{
            text={
                'When you return to fort mode, automatic', NEWLINE,
                'autosaves will be disabled until you restart', NEWLINE,
                'DF to avoid accidentally overwriting good', NEWLINE,
                'savegames.',
            },
            visible=self.no_autoquit and dfhack.world.isFortressMode(),
        },
        widgets.Label{
            text='This is your last chance to save your game.',
            text_pen=COLOR_LIGHTRED,
        },
        widgets.HotkeyLabel{
            frame={l=0},
            key='CUSTOM_SHIFT_S',
            label='Please click here to create an Autosave',
            text_pen=COLOR_YELLOW,
            on_activate=function() dfhack.run_command('quicksave') end,
            visible=dfhack.world.isFortressMode(),
        },
        widgets.Label{
            text={
                (dfhack.world.isFortressMode() and 'Alternately,' or 'You can') .. ' exit out of this dialog and', NEWLINE,
                'create a named save of your choice.',
            },
        },
        widgets.HotkeyLabel{
            key='CUSTOM_ALT_L',
            label='Click here to continue to legends mode',
            text_pen=self.no_autoquit and COLOR_RED or nil,
            auto_width=true,
            on_activate=function()
                self.parent_view:dismiss()
                LegendsManager{no_autoquit=self.no_autoquit}:show()
            end,
        },
    }
end

LegendsWarningScreen = defclass(LegendsWarningScreen, gui.ZScreenModal)
LegendsWarningScreen.ATTRS {
    focus_path='open-legends/warning',
    no_autoquit=false,
}

function LegendsWarningScreen:init()
    self:addviews{LegendsWarning{no_autoquit=self.no_autoquit}}
end

function LegendsWarningScreen:onDismiss()
    view = nil
end

if not dfhack.isWorldLoaded() then
    qerror('no world loaded')
end

local function main(args)
    local no_autoquit = args[1] == '--no-autoquit'

    if tainted then
        LegendsManager{no_autoquit=no_autoquit}:show()
    else
        view = view and view:raise() or LegendsWarningScreen{no_autoquit=no_autoquit}:show()
    end
end

main{...}
