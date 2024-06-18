local guidm = require('gui.dwarfmode')

local flags = df.global.d_init.feature.flags

if flags.KEYBOARD_CURSOR then
    flags.KEYBOARD_CURSOR = false
    guidm.setCursorPos(xyz2pos(-30000, -30000, -30000))
    print('Keyboard cursor disabled.')
else
    guidm.setCursorPos(guidm.Viewport.get():getCenter())
    flags.KEYBOARD_CURSOR = true
    print('Keyboard cursor enabled.')
end
