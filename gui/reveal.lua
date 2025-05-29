local argparse = require('argparse')
local dig = require('plugins.dig')
local gui = require('gui')
local widgets = require('gui.widgets')

--
-- Reveal
--

Reveal = defclass(Reveal, widgets.ResizingPanel)
Reveal.ATTRS {
    frame_title='Reveal',
    frame={w=37, r=2, t=18},
    frame_style=gui.WINDOW_FRAME,
    frame_background=gui.CLEAR_PEN,
    frame_inset=1,
    draggable=true,
    resizable=false,
    autoarrange_subviews=true,
    autoarrange_gap=1,
    opts=DEFAULT_NIL,
}

function Reveal:init()
    self.graphics = dfhack.screen.inGraphicsMode()

    local is_adv = dfhack.world.isAdventureMode()

    if is_adv then
        self.frame.t = 0
    end

    self:addviews{
        widgets.ResizingPanel{
            autoarrange_subviews=true,
            autoarrange_gap=1,
            visible=not self.opts.aquifers_only,
            subviews={
                widgets.WrappedLabel{
                    text_to_wrap='The map is revealed.' .. (is_adv and '' or ' The game will be force paused until you close this window.'),
                },
                widgets.WrappedLabel{
                    text_to_wrap='Areas with event triggers are kept hidden to avoid spoilers.',
                    visible=not self.opts.hell,
                },
                widgets.WrappedLabel{
                    text_to_wrap='Areas with hidden secrets have been revealed.' .. (is_adv and '' or ' The map must be hidden again before unpausing.'),
                    text_pen=COLOR_RED,
                    visible=self.opts.hell,
                },
                widgets.WrappedLabel{
                    text_to_wrap='In graphics mode, solid tiles that are not adjacent to open space are not rendered. Switch to ASCII mode to see them.',
                    text_pen=COLOR_BROWN,
                    visible=dfhack.screen.inGraphicsMode and not is_adv,
                },
            },
        },
        widgets.WrappedLabel{
            text_to_wrap='Aquifers and damp tiles are revealed.',
            visible=self.opts.aquifers_only,
        },
        widgets.Divider{
            frame={h=1},
            frame_style=gui.FRAME_THIN,
            frame_style_l=false,
            frame_style_r=false,
            visible=not self.opts.aquifers_only and not is_adv,
        },
        widgets.ToggleHotkeyLabel{
            view_id='unreveal',
            key='CUSTOM_SHIFT_R',
            label='Restore map on close:',
            options={
                {label='Yes', value=true, pen=COLOR_GREEN},
                {label='No', value=false, pen=COLOR_RED},
            },
            enabled=not self.opts.hell,
            visible=not self.opts.aquifers_only and not is_adv,
        },
    }
end

function Reveal:onRenderFrame(dc, rect)
    local graphics = dfhack.screen.inGraphicsMode()
    if graphics ~= self.graphics then
        self.graphics = graphics
        self:updateLayout()
    end
    dig.paintScreenWarmDamp(true, true)
    Reveal.super.onRenderFrame(self, dc, rect)
end

--
-- RevealScreen
--

RevealScreen = defclass(RevealScreen, gui.ZScreen)
RevealScreen.ATTRS {
    focus_path='reveal',
    pass_movement_keys=true,
    opts=DEFAULT_NIL,
}

function RevealScreen:init()
    if not self.opts.aquifers_only then
        self.force_pause=true
        local command = {'reveal'}
        if self.opts.hell then
            table.insert(command, 'hell')
        end
        dfhack.run_command(command)
    end

    self:addviews{Reveal{opts=self.opts}}
end

function RevealScreen:onDismiss()
    view = nil
    if not self.opts.aquifers_only and self.subviews.unreveal:getOptionValue() then
        dfhack.run_command('unreveal')
    end
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a map to be loaded')
end

local opts = {aquifers_only=false}
local positionals = argparse.processArgsGetopt({...}, {
    { 'h', 'help', handler = function() opts.help = true end },
    { 'o', 'aquifers-only', handler = function() opts.aquifers_only = true end },
})

if opts.help or positionals[1] == 'help' then
    print(dfhack.script_help())
    return
end

opts.hell = positionals[1] == 'hell'

view = view and view:raise() or RevealScreen{opts=opts}:show()
