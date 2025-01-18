-- Show tooltips on units and/or mouse

--@ module = true

local RELOAD = false -- set to true when actively working on this script

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')
local ResizingPanel = require('gui.widgets.containers.resizing_panel')

--------------------------------------------------------------------------------

-- pens are the same as gui/control-panel.lua
local textures = require('gui.textures')
local function get_icon_pens()
    local enabled_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 1), ch=string.byte('[')}
    local enabled_pen_center = dfhack.pen.parse{fg=COLOR_LIGHTGREEN,
            tile=curry(textures.tp_control_panel, 2) or nil, ch=251} -- check
    local enabled_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 3) or nil, ch=string.byte(']')}
    local disabled_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 4) or nil, ch=string.byte('[')}
    local disabled_pen_center = dfhack.pen.parse{fg=COLOR_RED,
            tile=curry(textures.tp_control_panel, 5) or nil, ch=string.byte('x')}
    local disabled_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 6) or nil, ch=string.byte(']')}
    local button_pen_left = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 7) or nil, ch=string.byte('[')}
    local button_pen_right = dfhack.pen.parse{fg=COLOR_CYAN,
            tile=curry(textures.tp_control_panel, 8) or nil, ch=string.byte(']')}
    local help_pen_center = dfhack.pen.parse{
            tile=curry(textures.tp_control_panel, 9) or nil, ch=string.byte('?')}
    local configure_pen_center = dfhack.pen.parse{
            tile=curry(textures.tp_control_panel, 10) or nil, ch=15} -- gear/masterwork symbol
    return enabled_pen_left, enabled_pen_center, enabled_pen_right,
            disabled_pen_left, disabled_pen_center, disabled_pen_right,
            button_pen_left, button_pen_right,
            help_pen_center, configure_pen_center
end
local ENABLED_PEN_LEFT, ENABLED_PEN_CENTER, ENABLED_PEN_RIGHT,
      DISABLED_PEN_LEFT, DISABLED_PEN_CENTER, DISABLED_PEN_RIGHT,
      BUTTON_PEN_LEFT, BUTTON_PEN_RIGHT,
      HELP_PEN_CENTER, CONFIGURE_PEN_CENTER = get_icon_pens()

if RELOAD then ToggleLabel = nil end
ToggleLabel = defclass(ToggleLabel, widgets.CycleHotkeyLabel)
ToggleLabel.ATTRS{
    options={{value=true},
             {value=false}},
}
function ToggleLabel:init()
    ToggleLabel.super.init(self)

    local text = self.text
    -- the very last token is the On/Off text -- we'll repurpose it as an indicator
    text[#text] =     { tile = function() return self:getOptionValue() and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT end }
    text[#text + 1] = { tile = function() return self:getOptionValue() and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER end }
    text[#text + 1] = { tile = function() return self:getOptionValue() and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT end }
    self:setText(text)
end

---

if RELOAD then config = nil end
config = config or {
    follow_units = true,
    follow_mouse = false,
    show_happiness = true,
    happiness_levels = {
        -- keep in mind, the text will look differently with game's font
        -- colors are same as in ASCII mode, but for then middle (3), which is GREY instead of WHITE
        [0] =
        {text = "=C", pen = COLOR_RED,        visible = true,  name = "Miserable"},
        {text = ":C", pen = COLOR_LIGHTRED,   visible = true,  name = "Unhappy"},
        {text = ":(", pen = COLOR_YELLOW,     visible = false, name = "Displeased"},
        {text = ":]", pen = COLOR_GREY,       visible = false, name = "Content"},
        {text = ":)", pen = COLOR_GREEN,      visible = false, name = "Pleased"},
        {text = ":D", pen = COLOR_LIGHTGREEN, visible = true,  name = "Happy"},
        {text = "=D", pen = COLOR_LIGHTCYAN,  visible = true,  name = "Ecstatic"},
    },
    show_unit_jobs = true,
    job_shortenings = {
        ["Store item in stockpile"] = "Store item",
    }
}

--------------------------------------------------------------------------------

local TITLE = "Tooltips"

if RELOAD then TooltipControlScreen = nil end
TooltipControlScreen = defclass(TooltipControlScreen, gui.ZScreen)
TooltipControlScreen.ATTRS {
    focus_path = "TooltipControlScreen",
    pass_movement_keys = true,
}

function TooltipControlScreen:init()
    local controls = TooltipControlWindow{view_id = 'controls'}
    self:addviews{controls}
end

function TooltipControlScreen:onDismiss()
    view = nil
end

if RELOAD then TooltipControlWindow = nil end
TooltipControlWindow = defclass(TooltipControlWindow, widgets.Window)
TooltipControlWindow.ATTRS {
    frame_title=TITLE,
    frame_inset=0,
    resizable=false,
    frame = {
        w = 27,
        h = 2 -- border
          + 4 -- main options
          + 7 -- happiness
        ,
        -- just under the minimap:
        r = 2,
        t = 18,
    },
}

-- right pad string `s` to `n` symbols with spaces
local function rpad(s, n)
    local formatStr = "%-" .. n .. "s" -- `"%-10s"`
    return string.format(formatStr, s)
end

function TooltipControlWindow:init()
    local w = self.frame.w - 2 - 3 -- 2 is border, 3 is active indicator width
    local keyW = 7 -- Length of "Alt+u: "

    self:addviews{
        ToggleLabel{
            view_id = 'btn_follow_units',
            frame={t=0, h=1},
            label=rpad("Unit banners", w - keyW),
            key='CUSTOM_ALT_U',
            initial_option=config.follow_units,
            on_change=function(new) config.follow_units = new end,
        },
        ToggleLabel{
            view_id = 'btn_follow_mouse',
            frame={t=1, h=1},
            label=rpad("Mouse tooltip", w - keyW),
            key='CUSTOM_ALT_M',
            initial_option=config.follow_mouse,
            on_change=function(new) config.follow_mouse = new end,
        },
        ToggleLabel{
            frame={t=2, h=1},
            label=rpad("Show jobs", w),
            initial_option=config.show_unit_jobs,
            on_change=function(new) config.show_unit_jobs = new end,
        },
        ToggleLabel{
            frame={t=3, h=1},
            label=rpad("Show stress levels", w),
            initial_option=config.show_happiness,
            on_change=function(new) config.show_happiness = new end,
        },
    }

    local happinessLabels = {}

    -- align the emoticons
    local maxNameLength = 1
    for _, v in pairs(config.happiness_levels) do
        local l = #v.name
        if l > maxNameLength then
            maxNameLength = l
        end
    end

    local indent = 3
    for lvl, cfg in pairs(config.happiness_levels) do
        happinessLabels[#happinessLabels + 1] = ToggleLabel{
            frame={t=4+lvl, h=1, l=indent},
            initial_option=cfg.visible,
            text_pen = cfg.pen,
            label = rpad(rpad(cfg.name, maxNameLength) .. " " .. cfg.text, w - indent),
            on_change = function(new) cfg.visible = new end
        }
    end
    self:addviews(happinessLabels)
end

local function GetUnitHappiness(unit)
    if not config.show_happiness then return end
    local stressCat = dfhack.units.getStressCategory(unit)
    if stressCat > 6 then stressCat = 6 end
    local happiness_level_cfg = config.happiness_levels[stressCat]
    if not happiness_level_cfg.visible then return end
    return happiness_level_cfg.text, happiness_level_cfg.pen
end

local function GetUnitJob(unit)
    if not config.show_unit_jobs then return end
    local job = unit.job.current_job
    return job and dfhack.job.getName(job)
end

local function GetUnitNameAndJob(unit)
    local sb = {}
    sb[#sb+1] = dfhack.units.getReadableName(unit)
    local jobName = GetUnitJob(unit)
    if jobName then
        sb[#sb+1] = ": "
        sb[#sb+1] = jobName
    end
    return table.concat(sb)
end

local function GetTooltipText(pos)
    if not pos then return end

    local txt = {}
    local units = dfhack.units.getUnitsInBox(pos, pos) or {} -- todo: maybe (optionally) use filter parameter here?

    for _,unit in ipairs(units) do
        txt[#txt+1] = GetUnitNameAndJob(unit)
        txt[#txt+1] = NEWLINE
    end

    return txt
end

--------------------------------------------------------------------------------
-- MouseTooltip is an almost copy&paste of the DimensionsTooltip
--
if RELOAD then MouseTooltip = nil end
MouseTooltip = defclass(MouseTooltip, ResizingPanel)

MouseTooltip.ATTRS{
    frame_style=gui.FRAME_THIN,
    frame_background=gui.CLEAR_PEN,
    no_force_pause_badge=true,
    auto_width=true,
    display_offset={x=3, y=3},
}

function MouseTooltip:init()
    ensure_key(self, 'frame').w = 17
    self.frame.h = 4

    self.label = widgets.Label{
        frame={t=0},
        auto_width=true,
    }

    self:addviews{
        widgets.Panel{
            -- set minimum size for tooltip frame so the DFHack frame badge fits
            frame={t=0, l=0, w=7, h=2},
        },
        self.label,
    }
end

function MouseTooltip:render(dc)
    if not config.follow_mouse then return end

    local x, y = dfhack.screen.getMousePos()
    if not x then return end

    local pos = dfhack.gui.getMousePos()
    local text = GetTooltipText(pos)
    if not text or #text == 0 then return end
    self.label:setText(text)

    local sw, sh = dfhack.screen.getWindowSize()
    local frame_width = math.max(9, self.label:getTextWidth() + 2)
    self.frame.l = math.min(x + self.display_offset.x, sw - frame_width)
    self.frame.t = math.min(y + self.display_offset.y, sh - self.frame.h)
    self:updateLayout()
    MouseTooltip.super.render(self, dc)
end

--------------------------------------------------------------------------------
if RELOAD then TooltipsOverlay = nil end
TooltipsOverlay = defclass(TooltipsOverlay, overlay.OverlayWidget)
TooltipsOverlay.ATTRS{
    desc='Adds tooltips with some info to units.',
    default_pos={x=1,y=1},
    default_enabled=true,
    fullscreen=true, -- not player-repositionable
    viewscreens={
        'dwarfmode/Default',
    },
}

function TooltipsOverlay:init()
    local tooltip = MouseTooltip{view_id = 'tooltip'}
    self:addviews{tooltip}
end

-- map coordinates -> interface layer coordinates
local function GetScreenCoordinates(map_coord)
    -- -> map viewport offset
    local vp = df.global.world.viewport
    local vp_Coord = vp.corner
    local map_offset_by_vp = {
        x = map_coord.x - vp_Coord.x,
        y = map_coord.y - vp_Coord.y,
        z = map_coord.z - vp_Coord.z,
    }

    if not dfhack.screen.inGraphicsMode() then
        return map_offset_by_vp
    else
        -- -> pixel offset
        local gps = df.global.gps
        local map_tile_pixels = gps.viewport_zoom_factor // 4;
        local screen_coord_px = {
            x = map_tile_pixels * map_offset_by_vp.x,
            y = map_tile_pixels * map_offset_by_vp.y,
        }
        -- -> interface layer coordinates
        local screen_coord_text = {
            x = math.ceil( screen_coord_px.x / gps.tile_pixel_x ),
            y = math.ceil( screen_coord_px.y / gps.tile_pixel_y ),
        }

        return screen_coord_text
    end
end

function TooltipsOverlay:render(dc)
    TooltipsOverlay.super.render(self, dc)

    if not config.follow_units then return end

    if not dfhack.screen.inGraphicsMode() and not gui.blink_visible(500) then
        return
    end

    local vp = df.global.world.viewport
    local topleft = vp.corner
    local width = vp.max_x
    local height = vp.max_y
    local bottomright = {x = topleft.x + width, y = topleft.y + height, z = topleft.z}

    local units = dfhack.units.getUnitsInBox(topleft, bottomright)
    if not units or #units == 0 then return end

    local oneTileOffset = GetScreenCoordinates({x = topleft.x + 1, y = topleft.y + 1, z = topleft.z + 0})
    local pen = COLOR_WHITE

    local shortenings = config.job_shortenings
    local used_tiles = {}
    for i = #units, 1, -1 do
        local unit = units[i]

        local happiness, happyPen = GetUnitHappiness(unit)
        local job = GetUnitJob(unit)
        job = shortenings[job] or job
        if not job and not happiness then goto continue end

        local pos = xyz2pos(dfhack.units.getPosition(unit))
        if not pos then goto continue end

        local txt = (happiness and job and happiness .. " " .. job)
                    or happiness
                    or job

        local scrPos = GetScreenCoordinates(pos)
        local y = scrPos.y - 1 -- subtract 1 to move the text over the heads
        local x = scrPos.x + oneTileOffset.x - 1 -- subtract 1 to move the text inside the map tile

        -- to resolve overlaps, we'll mark every coordinate we write anything in,
        -- and then check if the new tooltip will overwrite any used coordinate.
        -- if it will, try the next row, to a maximum offset of 4.
        local row
        local dy = 0
        -- todo: search for the "best" offset instead, f.e. max `usedAt` value, with `-1` the best
        local usedAt = -1
        for yOffset = 0, 4 do
            dy = yOffset

            row = used_tiles[y + dy]
            if not row then
                row = {}
                used_tiles[y + dy] = row
            end

            usedAt = -1
            for j = 0, #txt - 1 do
                if row[x + j] then
                    usedAt = j
                    break
                end
            end

            if usedAt == -1 then break end
        end -- for dy

        -- in case there isn't enough space, cut the text off
        if usedAt > 0 then
            local s = happiness and #happiness + 1 or 0
            job = job:sub(0, usedAt - s - 1) .. '_'
            txt = txt:sub(0, usedAt - 1) .. '_' -- for marking
        end

        dc:seek(x, y + dy)
            :pen(happyPen):string(happiness or "")
            :string((happiness and job) and " " or "")
            :pen(pen):string(job or "")

        -- mark coordinates as used
        for j = 0, #txt - 1 do
            row[x + j] = true
        end

        ::continue::
    end
end

function TooltipsOverlay:preUpdateLayout(parent_rect)
    self.frame.w = parent_rect.width
    self.frame.h = parent_rect.height
end

----------------------------------------------------------------

OVERLAY_WIDGETS = {
    tooltips=TooltipsOverlay,
}

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('gui/tooltips requires a map to be loaded')
end

if RELOAD and view then
    view:dismiss()
    -- view is nil now
end

view = view and view:raise() or TooltipControlScreen{}:show()
