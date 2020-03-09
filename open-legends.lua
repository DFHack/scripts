-- open legends screen when in fortress mode
--@ module = true
--[====[

open-legends
============
Open a legends screen when in fortress mode. Requires a world loaded in fortress
or adventure mode. Compatible with `exportlegends`.

Note that this script carries a significant risk of save corruption if the game
is saved after exiting legends mode. To avoid this:

1. Pause DF
2. Run `quicksave` to save the game
3. Run `open-legends` (this script) and browse legends mode as usual
4. Immediately after exiting legends mode, run `die` to quit DF without saving
   (saving at this point instead may corrupt your save)

Note that it should be safe to run "open-legends" itself multiple times in the
same DF session, as long as DF is killed immediately after the last run.
Unpausing DF or running other commands risks accidentally autosaving the game,
which can lead to save corruption.

The optional ``force`` argument will bypass all safety checks, as well as the
save corruption warning.

]====]

local dialogs = require 'gui.dialogs'
local gui = require 'gui'
local utils = require 'utils'

Wrapper = defclass(Wrapper, gui.Screen)
Wrapper.focus_path = 'legends'

local region_details_backup = {} --as:df.world_region_details[]

function Wrapper:onRender()
    self._native.parent:render()
end

function Wrapper:onIdle()
    self._native.parent:logic()
end

function Wrapper:onHelp()
    self._native.parent:help()
end

function Wrapper:onInput(keys)
    if self._native.parent.cur_page == 0 and keys.LEAVESCREEN then --hint:df.viewscreen_legendsst
        local v = df.global.world.world_data.region_details
        while (#v > 0) do v:erase(0) end
        for _,item in pairs(region_details_backup) do
            v:insert(0, item)
        end
        self:dismiss()
        dfhack.screen.dismiss(self._native.parent)
        return
    end
    gui.simulateInput(self._native.parent, keys)
end

function show_screen()
    local old_view = dfhack.gui.getCurViewscreen(true)
    local ok, err = pcall(function()
        dfhack.screen.show(df.viewscreen_legendsst:new())
        Wrapper():show()
    end)
    if ok then
        local v = df.global.world.world_data.region_details
        while (#v > 0) do
            table.insert(region_details_backup, 1, v[0])
            v:erase(0)
        end
    else
        while dfhack.gui.getCurViewscreen(true) ~= old_view do
            dfhack.screen.dismiss(dfhack.gui.getCurViewscreen(true))
        end
        qerror('Failed to set up legends screen: ' .. tostring(err))
    end
end

function main(force)
    if not dfhack.isWorldLoaded() then
        qerror('no world loaded')
    end

    local view = df.global.gview.view
    while view do
        if df.viewscreen_legendsst:is_instance(view) then
            qerror('legends screen already displayed')
        end
        view = view.child
    end
    local old_view = dfhack.gui.getCurViewscreen()

    if not dfhack.world.isFortressMode(df.global.gametype) and not dfhack.world.isAdventureMode(df.global.gametype) and not force then
        qerror('mode not tested: ' .. df.game_type[df.global.gametype] .. ' (use "force" to force)')
    end

    if force then
        show_screen()
    else
        dialogs.showYesNoPrompt('Save corruption possible',
            'This script can CORRUPT YOUR SAVE. If you care about this world,\n' ..
            'DO NOT SAVE AFTER RUNNING THIS SCRIPT - run "die" to quit DF\n' ..
            'without saving.\n\n' ..
            'To use this script safely,\n' ..
            '1. Press "esc" to exit this prompt\n' ..
            '2. Pause DF\n' ..
            '3. Run "quicksave" to save this world\n' ..
            '4. Run this script again and press "y" to enter legends mode\n' ..
            '5. IMMEDIATELY AFTER EXITING LEGENDS, run "die" to quit DF\n\n' ..
            'Press "esc" below to go back, or "y" to enter legends mode.\n' ..
            'By pressing "y", you acknowledge that your save could be\n' ..
            'permanently corrupted if you do not follow the above steps.',
            COLOR_LIGHTRED,
            show_screen
        )
    end
end

if not moduleMode then
    local iargs = utils.invert{...}
    main(iargs.force)
end
