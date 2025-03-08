local gui = require('gui')
local guidm = require('gui.dwarfmode')

if dfhack.world.isAdventureMode() then
    local open = df.global.game.main_interface.adventure.look.open
    gui.simulateInput(dfhack.gui.getDFViewscreen(), open and 'LEAVESCREEN' or 'A_LOOK')
    print('Look mode '..(open and 'disabled.' or 'enabled.'))
else
    local flags = df.global.d_init.feature.flags
    if flags.KEYBOARD_CURSOR then
        flags.KEYBOARD_CURSOR = false
        guidm.clearCursorPos()
        print('Keyboard cursor disabled.')
    else
        guidm.setCursorPos(guidm.Viewport.get():getCenter())
        flags.KEYBOARD_CURSOR = true
        print('Keyboard cursor enabled.')
    end
end
