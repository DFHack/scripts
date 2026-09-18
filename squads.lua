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

local gui = require('gui')
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

local function toggle_all()
    set_all(not all_selected())
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
    default_pos={x=-4, y=44},
    version=1,
    viewscreens='dwarfmode/Squads',
    default_enabled=true,
    -- anchor on the first tick the panel opens so the widget never flashes
    -- at the default position; the rescan is gated by a cheap key check
    overlay_onupdate_max_freq_seconds=0,
    frame={w=20, h=1},
}

function SquadsOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            view_id='select_all',
            frame={t=0, l=0},
            key='CUSTOM_CTRL_A',
            label='Select all',
            on_activate=toggle_all,
        },
    }
end

function SquadsOverlay:onRenderBody(dc)
    -- keep the label in sync with the actual selection so it stays accurate
    -- when the user clicks individual squad checkboxes
    self.subviews.select_all:setLabel(
        all_selected() and 'Deselect all' or 'Select all')
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
    -- cheap bail-out: only rescan when something that can move the "Create new
    -- squad" button changes (squad count, list scroll, window height), and
    -- only after a successful anchor so a transient miss doesn't stick
    local _, sh = dfhack.screen.getWindowSize()
    local scan_key = #if_squads.squad_id * 1000 +
        if_squads.scroll_position * 10 + sh
    if scan_key == self.scan_key and self.anchored then return end
    self.scan_key = scan_key
    local y, x1, x2 = find_create_squad_button()
    if not y then
        self.anchored = false
        return
    end
    -- sit directly above the button, centered on it and nudged right so the
    -- label text lines up under the squad checkmark column
    local t = y - 2
    local sw = dfhack.screen.getWindowSize()
    local w = self.frame.w or 20
    local r = sw - math.floor((x1 + x2) / 2) - math.ceil(w / 2) - 2
    if self.anchored and self.frame.t == t and self.frame.r == r then return end
    self.frame.t = t
    self.frame.l = nil
    self.frame.r = r
    self.anchored = true
    self:updateLayout(gui.ViewRect{rect=gui.get_interface_rect()})
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
