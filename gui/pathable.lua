-- View whether tiles on the map can be pathed to

--[====[

gui/pathable
============

Highlights each visible map tile to indicate whether it is possible to path to
from the tile at the cursor - green if possible, red if not, similar to
`gui/siege-engine`. A few options are available:

* :kbd:`l`: Lock cursor: when enabled, the movement keys move around the map
  instead of moving the cursor. This is useful to check whether parts of the map
  far away from the cursor can be pathed to from the cursor.
* :kbd:`d`: Draw: allows temporarily disabling the highlighting entirely.
* :kbd:`u`: Skip unrevealed: when enabled, unrevealed tiles will not be
  highlighed at all. (These would otherwise be highlighted in red.)

.. note::
    This tool uses a cache used by DF, which currently does *not* account for
    climbing. If an area of the map is only accessible by climbing, this tool
    may report it as inaccessible. Care should be taken when digging into the
    upper levels of caverns, for example.

]====]

local guidm = require 'gui.dwarfmode'
local plugin = require 'plugins.pathable'

opts = opts or {
    lock_cursor = false,
    draw = true,
    skip_unrevealed = false,
}

function render_toggle(p, key, text, state)
    p:key_string(key, text .. ': ')
    p:string(state and 'Yes' or 'No', state and COLOR_GREEN or COLOR_RED)
end

Pathable = defclass(Pathable, guidm.MenuOverlay)

Pathable.ATTRS = {
    sidebar_mode=df.ui_sidebar_mode.LookAround,
}

function Pathable:onRenderBody(p)
    local cursor = df.global.cursor
    local block = dfhack.maps.getTileBlock(pos2xyz(cursor))

    p:seek(1, 1)
    p:string("DFHack pathable tile viewer"):newline():newline(1)
    render_toggle(p, 'CUSTOM_L', 'Lock cursor', opts.lock_cursor)
    p:newline(1)
    render_toggle(p, 'CUSTOM_D', 'Draw', opts.draw)
    p:newline(1)
    render_toggle(p, 'CUSTOM_U', 'Skip unrevealed', opts.skip_unrevealed)

    p:newline():newline(1)
    p:key_string('LEAVESCREEN', "Exit to cursor"):newline(1)
    p:key_string('LEAVESCREEN_ALL', "Exit to here"):newline(1)

    p:newline(1)
    p:string('Group: ' .. block.walkable[cursor.x % 16][cursor.y % 16])
    p:newline(1)
    p:string(df.tiletype[block.tiletype[cursor.x % 16][cursor.y % 16]], COLOR_CYAN)

    if opts.draw then
        plugin.paintScreen(xyz2pos(pos2xyz(cursor)), opts.skip_unrevealed)
    end
end

function Pathable:onInput(keys)
    if keys.LEAVESCREEN then
        self:dismiss()
        dfhack.gui.refreshSidebar()
    elseif keys.LEAVESCREEN_ALL then
        self:dismiss()
    elseif keys.CUSTOM_L then
        opts.lock_cursor = not opts.lock_cursor
    elseif keys.CUSTOM_D then
        opts.draw = not opts.draw
    elseif keys.CUSTOM_U then
        opts.skip_unrevealed = not opts.skip_unrevealed
    else
        if opts.lock_cursor then
            -- no_clip_cursor=true: allow scrolling so the cursor isn't in view
            self:simulateViewScroll(keys, nil, true)
        else
            self:propagateMoveKeys(keys)
        end
    end
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

Pathable():show()
