-- Makes the game immediately save the state.

local gui = require("gui")

--luacheck: defclass={run:bool}
QuicksaveOverlay = defclass(QuicksaveOverlay, gui.Screen)

function QuicksaveOverlay:render()
    if not self.run then
        self.run = true
        save()
        self:renderParent()
        self:dismiss()
    end
end

if not dfhack.isMapLoaded() then
    qerror("World and map aren't loaded.")
end

if not dfhack.world.isFortressMode() then
    qerror('This script can only be used in fortress mode')
end

function save()
    local ui_main = df.global.plotinfo.main

    -- Request auto-save (preparation steps below discovered from rev eng)
    ui_main.autosave_request = true
    ui_main.autosave_timer = 5
    ui_main.save_progress.substage = 0
    ui_main.save_progress.stage = 0
    ui_main.save_progress.info.nemesis_save_file_id:resize(0)
    ui_main.save_progress.info.nemesis_member_idx:resize(0)
    ui_main.save_progress.info.units:resize(0)
    ui_main.save_progress.info.cur_unit_chunk = nil
    ui_main.save_progress.info.cur_unit_chunk_num = -1
    ui_main.save_progress.info.units_offloaded = -1
    print 'The game should autosave now.'
end

QuicksaveOverlay():show()
