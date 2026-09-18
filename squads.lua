-- Adds a "select all" toggle to the squads sidebar
--@ module=true

local help = [====[

squads
======
Adds a "Ctrl+a: Select all" toggle button to the squads sidebar panel. When
activated, all squads are selected; when all squads are already selected,
activating it deselects them all.

The button is implemented as an overlay widget and can be repositioned or
disabled via `gui/overlay`.

Usage::

    squads
]====]

local overlay = require('plugins.overlay')
local widgets = require('gui.widgets')

local if_squads = df.global.game.main_interface.squads

local function all_selected()
    local sel = if_squads.squad_selected
    for i = 0, #sel - 1 do
        if not sel[i] then return false end
    end
    return #sel > 0
end

local function set_all(value)
    -- don't hijack the hotkey while the user is typing a name
    if if_squads.entering_squad_nickname or if_squads.entering_cell_nickname then
        return
    end
    local sel = if_squads.squad_selected
    for i = 0, #sel - 1 do
        sel[i] = value
    end
end

-- the squads sidebar is docked to the right edge of the screen, but its
-- vertical layout shifts with the window height, so we anchor ourselves to the
-- "Create new squad" button, which sits right below the squad list
local function find_create_squad_button()
    local dscreen = dfhack.screen
    local sw, sh = dscreen.getWindowSize()
    for y = 4, sh - 6 do
        local line = {}
        for x = sw - 45, sw - 1 do
            local tile = dscreen.readTile(x, y)
            line[#line+1] = tile and tile.ch > 0 and tile.ch < 128
                and string.char(tile.ch) or ' '
        end
        local s, e = table.concat(line):find('Create new squad')
        if s then
            return y, sw - 46 + s, sw - 46 + e
        end
    end
end

SquadsOverlay = defclass(SquadsOverlay, overlay.OverlayWidget)
SquadsOverlay.ATTRS{
    desc='Adds a "select all" toggle to the squads sidebar.',
    default_pos={x=-7, y=44},
    viewscreens='dwarfmode/Squads',
    default_enabled=true,
    overlay_onupdate_max_freq_seconds=0.5,
    frame={w=23, h=1},
}

function SquadsOverlay:init()
    self:addviews{
        widgets.ToggleHotkeyLabel{
            view_id='select_all',
            frame={t=0, l=0},
            key='CUSTOM_CTRL_A',
            label='Select all',
            initial_option=false,
            on_change=set_all,
        },
    }
end

function SquadsOverlay:onRenderBody(dc)
    -- keep the displayed state in sync with the actual selection so the toggle
    -- is accurate when the user clicks individual squad checkboxes
    self.subviews.select_all:setOption(all_selected())
    SquadsOverlay.super.onRenderBody(self, dc)
end

function SquadsOverlay:overlay_onupdate()
    -- the overlay framework persists user-set positions in config.pos; if the
    -- user has repositioned us away from the default, don't fight them
    local config = overlay.get_state().config[self.name]
    if config and config.pos and
            (config.pos.x ~= self.default_pos.x or
             config.pos.y ~= self.default_pos.y) then
        return
    end
    local y, x1, x2 = find_create_squad_button()
    if not y then return end
    local sw = dfhack.screen.getWindowSize()
    local w = self.frame.w or 23
    self.frame.t = y + 2
    self.frame.r = sw - math.floor((x1 + x2) / 2) - math.ceil(w / 2)
end

OVERLAY_WIDGETS = {select_all=SquadsOverlay}

if dfhack_flags.module then
    return
end

local args = {...}
if args[1] == 'help' or #args > 0 then
    print(dfhack.script_help())
    return
end

print('The squads sidebar select-all toggle is managed by the overlay framework.')
print('Use "gui/overlay" to reposition or disable it.')
