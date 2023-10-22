-- Mouse/keyboard monitor

DFH_MOD_SHIFT = 1
DFH_MOD_CTRL = 2
DFH_MOD_ALT = 4

bit32 = require 'bit32'
gui = require 'gui'

enabler = df.global.enabler
gps = df.global.gps
OutputString = dfhack.screen.paintString

function format_modstate(m)
    s = ''
    if bit32.band(m, DFH_MOD_SHIFT) ~= 0 then s = s .. 'Shift-' end
    if bit32.band(m, DFH_MOD_CTRL) ~= 0 then s = s .. 'Ctrl-' end
    if bit32.band(m, DFH_MOD_ALT) ~= 0 then s = s .. 'Alt-' end
    if #s > 0 then s = s:sub(1, #s - 1) end
    return s
end

viewscreen_inputst = defclass(viewscreen_inputst, gui.Screen)
viewscreen_inputst.focus_path = 'input_monitor'
function viewscreen_inputst:init()
    self.keys = {}
    self.key_max_length = 0
    self.key_pressed = false
    self.old_fps = gps.display_frames
    gps.display_frames = 0
end

function viewscreen_inputst:onRender()
    dfhack.screen.clear()
    local p = gui.Painter()
    p:seek(0, gps.dimy - 1)
    local mx = gps.mouse_x
    local my = gps.mouse_y
    p:string(format_modstate(dfhack.internal.getModstate()))
    p:seek(15)
    p:string(('(%i,%i)'):format(mx, my))
    p:seek(15 + 8)
    local mouse_bg = COLOR_RED
    if enabler.mouse_rbut_down == 1 then
        mouse_bg = COLOR_GREEN
        p:string('Right ')
    elseif enabler.mouse_lbut_down == 1 then
        mouse_bg = COLOR_BLUE
        p:string('Left  ')
    else
        p:string('      ')
    end
    p:string(('FPS: %i (%i)'):format(enabler.calculated_fps, enabler.calculated_gfps))
    for y = 0, math.min(#self.keys - 1, gps.dimy - 2) do
        OutputString(COLOR_GREY, 0, y, self.keys[y + 1])
    end
    p:seek(15 + 8 + 6 + 15):string(#self.keys .. ' key' .. (#self.keys == 1 and ' ' or 's'),
        {fg = self.key_pressed and COLOR_LIGHTGREEN or COLOR_GREY})
    self.key_pressed = false
    if mx >= 0 and my >= 0 then
        local tile = dfhack.screen.readTile(mx, my)
        tile.bg = mouse_bg
        dfhack.screen.paintTile(tile, mx, my)
    end
end

function viewscreen_inputst:onInput(keys)
    if keys.LEAVESCREEN then
        self:dismiss()
    else
        local new_keys = {}
        self.key_max_length = 0
        for k, _ in pairs(keys) do
            if k:sub(1, 1) ~= '_' then
                table.insert(new_keys, k)
                self.key_max_length = math.max(self.key_max_length, #k)
            end
        end
        if #new_keys > 0 then
            table.sort(new_keys)
            self.key_pressed = true
            self.keys = new_keys
        end
    end
end

function viewscreen_inputst:onDismiss()
    gps.display_frames = self.old_fps
end

viewscreen_inputst():show()
