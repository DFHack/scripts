--@ module=true

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')

local view_sheets = df.global.game.main_interface.view_sheets

-- the unit sheet is a right-side panel whose layout shifts with the window
-- size, so anchor to the "Overview" tab label, which sits on the bottom tab
-- row and is rendered on every sub-tab of the sheet. the tabs are near the
-- top of the sheet, so only scan that band
local function find_overview_tab()
    local dscreen = dfhack.screen
    local sw, sh = dscreen.getWindowSize()
    for y = 4, math.min(sh - 2, 25) do
        local line = {}
        for x = sw - 100, sw - 1 do
            local tile = dscreen.readTile(x, y)
            line[#line+1] = tile and tile.ch > 0 and tile.ch < 128
                and string.char(tile.ch) or ' '
        end
        local s = table.concat(line):find('Overview')
        if s then
            return y, sw - 101 + s
        end
    end
end

-- display names and colors follow the stress categories in spectate and
-- dwarfmonitor: index 1 is most stressed, 7 is least
local STRESS_LEVELS = {
    {name='Miserable',  pen=COLOR_LIGHTRED},
    {name='Unhappy',    pen=COLOR_RED},
    {name='Displeased', pen=COLOR_YELLOW},
    {name='Content',    pen=COLOR_WHITE},
    {name='Pleased',    pen=COLOR_CYAN},
    {name='Happy',      pen=COLOR_LIGHTBLUE},
    {name='Ecstatic',   pen=COLOR_LIGHTGREEN},
}

local function get_level(unit, stress)
    if not stress then
        return STRESS_LEVELS[dfhack.units.getStressCategory(unit) + 1]
    end
    return STRESS_LEVELS[dfhack.units.getStressCategoryRaw(stress) + 1]
end

OverallMoodOverlay = defclass(OverallMoodOverlay, overlay.OverlayWidget)
OverallMoodOverlay.ATTRS {
    desc="Show the viewed unit's current and long-term mood on their sheet.",
    default_pos={x=-96, y=10},
    default_enabled=true,
    version=1,
    viewscreens={
        'dwarfmode/ViewSheets/UNIT/Overview',
        'dungeonmode/ViewSheets/UNIT/Overview',
    },
    frame={w=27, h=2},
    -- anchor on the first tick the sheet is open so the widget never flashes
    -- at the default position; the scan itself is gated by a cheap key check
    overlay_onupdate_max_freq_seconds=0,
}

function OverallMoodOverlay:init()
    self:addviews{
        widgets.Label{
            view_id='mood',
            frame={t=0, l=0},
            auto_height=false,
            text='',
        },
    }
end

function OverallMoodOverlay:onRenderBody(dc)
    local text, key = {}, ''
    local unit = df.unit.find(view_sheets.active_id)
    local soul = unit and unit.status.current_soul
    if soul then
        local cur = get_level(unit)
        local longterm = get_level(unit, soul.personality.longterm_stress)
        key = cur.name .. '|' .. longterm.name
        text = {
            {text='Mood: '},
            {text=cur.name, pen=cur.pen},
            NEWLINE,
            {text='Long-term mood: '},
            {text=longterm.name, pen=longterm.pen},
        }
    end
    -- only rewrite the label when it changes; setText forces a relayout,
    -- which makes the text flicker every frame
    if key ~= self.last_text_key then
        self.last_text_key = key
        self.subviews.mood:setText(text)
    end
    OverallMoodOverlay.super.onRenderBody(self, dc)
end

function OverallMoodOverlay:overlay_onupdate()
    -- the overlay framework persists user-set positions in config.pos; if the
    -- user has repositioned us away from the default, don't fight them
    local config = overlay.get_state().config[self.name]
    if config and config.pos and
            (config.pos.x ~= self.default_pos.x or
             config.pos.y ~= self.default_pos.y) then
        return
    end
    -- only rescan when the window size or sheet unit changes, and only after a
    -- successful anchor so a transient miss doesn't stick
    local _, sh = dfhack.screen.getWindowSize()
    local scan_key = sh * 100000 + view_sheets.active_id
    if scan_key == self.scan_key and self.anchored then return end
    self.scan_key = scan_key
    local y, x = find_overview_tab()
    if not y then
        self.anchored = false
        return
    end
    -- the tab label sits on the lower tab row; put the mood text at the bottom
    -- of the vital-stats section (just above its divider), aligned with the
    -- section's left content margin
    local t = y + 13
    x = x - 2
    if self.anchored and self.frame.t == t and self.frame.l == x then return end
    self.frame.t = t
    self.frame.r = nil
    self.frame.l = x
    self.anchored = true
    self:updateLayout(gui.ViewRect{rect=gui.get_interface_rect()})
end
