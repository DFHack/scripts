--@ module = true

local argparse = require('argparse')
local control_panel = reqscript('control-panel')
local gui = require('gui')
local json = require('json')
local overlay = require('plugins.overlay')
local utils = require('utils')
local widgets = require('gui.widgets')

local GLOBAL_KEY = 'settings-manager'

config = config or json.open("dfhack-config/settings-manager.json")

--------------------------
-- DifficultyOverlayBase
--

DifficultyOverlayBase = defclass(DifficultyOverlayBase, overlay.OverlayWidget)
DifficultyOverlayBase.ATTRS {
    frame={w=46, h=5},
    frame_style=gui.MEDIUM_FRAME,
    frame_background=gui.CLEAR_PEN,
}

local function save_difficulty(df_difficulty)
    local difficulty = utils.clone(df_difficulty, true)
    for _, v in pairs(difficulty) do
        if type(v) == 'table' and not v[1] then
            for name in pairs(v) do
                if tonumber(name) then
                    -- remove numeric "filler" vals from bitflag records
                    v[name] = nil
                end
            end
        end
    end
    -- replace top-level button states to say "Custom"
    -- one of the vanilla presets might actually apply, but we don't know that
    -- unless we do some diffing
    difficulty.difficulty_enemies = df.setting_difficulty_enemies_type.Custom
    difficulty.difficulty_economy = df.setting_difficulty_economy_type.Custom
    config.data.difficulty = difficulty
    config:write()
end

local function load_difficulty(df_difficulty)
    local difficulty = utils.clone(config.data.difficulty or {}, true)
    for _, v in pairs(difficulty) do
        if type(v) == 'table' and v[1] then
            -- restore 0-based index for static arrays and prevent resizing
            for i, elem in ipairs(v) do
                v[i-1] = elem
                v[i] = nil
            end
            v.resize = false
        end
    end
    df_difficulty:assign(difficulty)
end

local function save_auto(val)
    config.data.auto = val
    config:write()
end

function DifficultyOverlayBase:init()
    self:addviews{
        widgets.HotkeyLabel{
            view_id='save',
            frame={l=0, t=0, w=16},
            key='CUSTOM_SHIFT_S',
            label='Save settings',
            on_activate=self:callback('do_save'),
        },
        widgets.Label{
            view_id='save_flash',
            frame={l=6, t=0},
            text='Saved',
            text_pen=COLOR_GREEN,
            visible=false,
        },
        widgets.HotkeyLabel{
            view_id='load',
            frame={l=22, t=0, w=22},
            key='CUSTOM_SHIFT_L',
            label='Load saved settings',
            on_activate=self:callback('do_load'),
            enabled=function() return next(config.data.difficulty or {}) end,
        },
        widgets.Label{
            view_id='load_flash',
            frame={l=28, t=0},
            text='Loaded',
            text_pen=COLOR_GREEN,
            visible=false,
        },
        widgets.ToggleHotkeyLabel{
            frame={l=0, t=2},
            key='CUSTOM_SHIFT_A',
            label='Apply saved settings for new embarks:',
            on_change=save_auto,
            initial_option=not not config.data.auto,
            enabled=function() return next(config.data.difficulty or {}) end,
        },
    }
end

local function flash(self, which)
    self.subviews[which].visible = false
    self.subviews[which..'_flash'].visible = true
    local end_ms = dfhack.getTickCount() + 5000
    local function label_reset()
        if dfhack.getTickCount() < end_ms then
            dfhack.timeout(10, 'frames', label_reset)
        else
            self.subviews[which..'_flash'].visible = false
            self.subviews[which].visible = true
        end
    end
    label_reset()
end

-- overridden by subclasses
function DifficultyOverlayBase:get_df_struct()
end

function DifficultyOverlayBase:do_save()
    flash(self, 'save')
    save_difficulty(self:get_df_struct().difficulty)
end

function DifficultyOverlayBase:do_load()
    flash(self, 'load')
    load_difficulty(self:get_df_struct().difficulty)
end

function DifficultyOverlayBase:onInput(keys)
    if self:get_df_struct().entering_value_str then return false end
    return DifficultyOverlayBase.super.onInput(self, keys)
end

----------------------------
-- DifficultyEmbarkOverlay
--

DifficultyEmbarkOverlay = defclass(DifficultyEmbarkOverlay, DifficultyOverlayBase)
DifficultyEmbarkOverlay.ATTRS {
    desc='Adds buttons to the embark difficulty screen for saving and restoring settings.',
    default_pos={x=-20, y=5},
    viewscreens='setupdwarfgame/CustomSettings',
    default_enabled=true,
}

show_notification = show_notification or false

function DifficultyEmbarkOverlay:get_df_struct()
    return dfhack.gui.getDFViewscreen(true)
end

function DifficultyEmbarkOverlay:onInput(keys)
    show_notification = false
    return DifficultyEmbarkOverlay.super.onInput(self, keys)
end

----------------------------------------
-- DifficultyEmbarkNotificationOverlay
--

DifficultyEmbarkNotificationOverlay = defclass(DifficultyEmbarkNotificationOverlay, overlay.OverlayWidget)
DifficultyEmbarkNotificationOverlay.ATTRS {
    desc='Displays a message when saved difficulty settings have been automatically applied.',
    default_pos={x=75, y=18},
    viewscreens='setupdwarfgame/Default',
    default_enabled=true,
    frame={w=23, h=3},
}

function DifficultyEmbarkNotificationOverlay:init()
    self:addviews{
        widgets.Panel{
            frame={t=0, w=25},
            frame_style=gui.FRAME_MEDIUM,
            frame_background=gui.CLEAR_PEN,
            subviews={
                widgets.Label{
                    text='Saved settings restored',
                    text_pen=COLOR_LIGHTGREEN,
                },
            },
            visible=function() return show_notification end,
        },
    }
end

function DifficultyEmbarkNotificationOverlay:preUpdateLayout(parent_rect)
    self.frame.w = parent_rect.width - (self.frame.l or (self.default_pos.x - 1))
end

local last_scr_type
dfhack.onStateChange[GLOBAL_KEY] = function(sc)
    if sc ~= SC_VIEWSCREEN_CHANGED then return end
    local scr = dfhack.gui.getDFViewscreen(true)
    if last_scr_type == scr._type then return end
    last_scr_type = scr._type
    show_notification = false
    if not df.viewscreen_setupdwarfgamest:is_instance(scr) then return end
    if not config.data.auto then return end
    load_difficulty(scr.difficulty)
    show_notification = true
end

------------------------------
-- DifficultySettingsOverlay
--

DifficultySettingsOverlay = defclass(DifficultySettingsOverlay, DifficultyOverlayBase)
DifficultySettingsOverlay.ATTRS {
    desc='Adds buttons to the fort difficulty screen for saving and restoring settings.',
    default_pos={x=-42, y=8},
    viewscreens='dwarfmode/Settings/DIFFICULTY/CustomSettings',
    default_enabled=true,
}

function DifficultySettingsOverlay:get_df_struct()
    return df.global.game.main_interface.settings
end

------------------------------
-- ImportExportAutoOverlay
--

ImportExportAutoOverlay = defclass(ImportExportAutoOverlay, overlay.OverlayWidget)
ImportExportAutoOverlay.ATTRS {
    default_enabled=true,
    frame_style=gui.MEDIUM_FRAME,
    frame_background=gui.CLEAR_PEN,
    save_label=DEFAULT_NIL,
    load_label=DEFAULT_NIL,
    auto_label=DEFAULT_NIL,
    save_fn=DEFAULT_NIL,
    load_fn=DEFAULT_NIL,
    has_data_fn=DEFAULT_NIL,
    autostart_command=DEFAULT_NIL,
}

function ImportExportAutoOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            view_id='save',
            frame={l=0, t=0, w=39},
            key='CUSTOM_CTRL_E',
            label=self.save_label,
            on_activate=self:callback('do_save'),
        },
        widgets.Label{
            view_id='save_flash',
            frame={l=18, t=0},
            text='Saved',
            text_pen=COLOR_GREEN,
            visible=false,
        },
        widgets.HotkeyLabel{
            view_id='load',
            frame={l=42, t=0, w=34},
            key='CUSTOM_CTRL_I',
            label=self.load_label,
            on_activate=self:callback('do_load'),
            enabled=self.has_data_fn,
        },
        widgets.Label{
            view_id='load_flash',
            frame={l=51, t=0},
            text='Loaded',
            text_pen=COLOR_GREEN,
            visible=false,
        },
        widgets.ToggleHotkeyLabel{
            view_id='auto',
            frame={l=0, t=2},
            key='CUSTOM_CTRL_A',
            label=self.auto_label,
            on_change=self:callback('do_auto'),
            enabled=self.has_data_fn,
        },
    }
end

function ImportExportAutoOverlay:do_save()
    flash(self, 'save')
    self.save_fn()
end

function ImportExportAutoOverlay:do_load()
    flash(self, 'load')
    self.load_fn()
end

AutoMessage = defclass(AutoMessage, widgets.Window)
AutoMessage.ATTRS {
    frame={w=61, h=9},
    autostart_command=DEFAULT_NIL,
    enabled=DEFAULT_NIL,
}

function AutoMessage:init()
    self:addviews{
        widgets.Label{
            view_id='label',
            frame={t=0, l=0},
            text={
                'The "', self.autostart_command, '" command', NEWLINE,
                'has been ',
                {text=self.enabled and 'enabled' or 'disabled', pen=self.enabled and COLOR_GREEN or COLOR_LIGHTRED},
                ' in the ',
                {text='Automation', pen=COLOR_YELLOW}, ' -> ',
                {text='Autostart', pen=COLOR_YELLOW}, ' tab of ', NEWLINE,
                {text='.', gap=25},
            },
        },
        widgets.HotkeyLabel{
            frame={t=2, l=0},
            label='gui/control-panel',
            key='CUSTOM_CTRL_G',
            auto_width=true,
            on_activate=function()
                self.parent_view:dismiss()
                dfhack.run_script('gui/control-panel')
            end,
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0, r=0},
            label='Ok',
            key='SELECT',
            auto_width=true,
            on_activate=function() self.parent_view:dismiss() end,
        },
    }
end

AutoMessageScreen = defclass(AutoMessageScreen, gui.ZScreenModal)
AutoMessageScreen.ATTRS {
    focus_path='settings-manager/prompt',
    autostart_command=DEFAULT_NIL,
    enabled=DEFAULT_NIL,
}

function AutoMessageScreen:init()
    self:addviews{
        AutoMessage{
            frame_title=(self.enabled and 'Enabled' or 'Disabled')..' auto-restore',
            autostart_command=self.autostart_command,
            enabled=self.enabled,
        },
    }
end

function ImportExportAutoOverlay:do_auto(val)
    dfhack.run_script('control-panel', (val and '' or 'no') .. 'autostart', self.autostart_command)
    AutoMessageScreen{autostart_command=self.autostart_command, enabled=val}:show()
end

function ImportExportAutoOverlay:onRenderFrame(dc, rect)
    ImportExportAutoOverlay.super.onRenderFrame(self, dc, rect)
    local enabled = control_panel.get_autostart(self.autostart_command)
    self.subviews.auto:setOption(enabled)
end

------------------------------
-- StandingOrdersOverlay
--

local li = df.global.plotinfo.labor_info

local function save_standing_orders()
    local standing_orders = {}
    for name, val in pairs(df.global) do
        if name:startswith('standing_orders_') then
            standing_orders[name] = val
        end
    end
    config.data.standing_orders = standing_orders
    local chores = {}
    chores.enabled = li.flags.children_do_chores
    chores.labors = utils.clone(li.chores)
    config.data.chores = chores
    config:write()
end

local function load_standing_orders()
    for name, val in pairs(config.data.standing_orders or {}) do
        df.global[name] = val
    end
    li.flags.children_do_chores = not not safe_index(config.data.chores, 'enabled')
    for i, val in ipairs(safe_index(config.data.chores, 'labors') or {}) do
        li.chores[i-1] = val
    end
end

local function has_saved_standing_orders()
    return next(config.data.standing_orders or {})
end

StandingOrdersOverlay = defclass(StandingOrdersOverlay, ImportExportAutoOverlay)
StandingOrdersOverlay.ATTRS {
    desc='Adds buttons to the standing orders screen for saving and restoring settings.',
    default_pos={x=6, y=-5},
    viewscreens='dwarfmode/Info/LABOR/STANDING_ORDERS/AUTOMATED_WORKSHOPS',
    frame={w=78, h=5},
    save_label='Save standing orders (all tabs)',
    load_label='Load saved standing orders',
    auto_label='Apply saved settings for new embarks:',
    save_fn=save_standing_orders,
    load_fn=load_standing_orders,
    has_data_fn=has_saved_standing_orders,
    autostart_command='gui/settings-manager load-standing-orders',
}

------------------------------
-- WorkDetailsOverlay
--

local function clone_wd_flags(flags)
    return {
        cannot_be_everybody=flags.cannot_be_everybody,
        no_modify=flags.no_modify,
        mode=flags.mode,
    }
end

local function save_work_details()
    local details = {}
    for idx, wd in ipairs(li.work_details) do
        local detail = {
            name=wd.name,
            icon=wd.icon,
            flags=clone_wd_flags(wd.flags),
            allowed_labors=utils.clone(wd.allowed_labors),
        }
        details[idx+1] = detail
    end
    config.data.work_details = details
    config:write()
end

local function load_work_details()
    if not config.data.work_details or #config.data.work_details < 10 then
        -- not enough data to cover built-in work details
        return
    end
    li.work_details:resize(#config.data.work_details)
    -- keep unit assignments for overwritten indices
    for idx, wd in ipairs(config.data.work_details) do
        local detail = {
            new=df.work_detail,
            name=wd.name,
            icon=wd.icon,
            flags=wd.flags or wd.work_detail_flags, -- compat for old name
        }
        li.work_details[idx-1] = detail
        local al = li.work_details[idx-1].allowed_labors
        for i,v in ipairs(wd.allowed_labors) do
            al[i-1] = v
        end
    end
    local scr = dfhack.gui.getDFViewscreen(true)
    if dfhack.gui.matchFocusString('dwarfmode/Info/LABOR/WORK_DETAILS', scr) then
        gui.simulateInput(scr, 'LEAVESCREEN')
        gui.simulateInput(scr, 'D_LABOR')
    end
end

local function has_saved_work_details()
    return next(config.data.work_details or {})
end

WorkDetailsOverlay = defclass(WorkDetailsOverlay, ImportExportAutoOverlay)
WorkDetailsOverlay.ATTRS {
    desc='Adds buttons to the work details screen for saving and restoring settings.',
    default_pos={x=80, y=-5},
    viewscreens='dwarfmode/Info/LABOR/WORK_DETAILS/Default',
    frame={w=35, h=5},
    save_label='Save work details',
    load_label='Load work details',
    auto_label='Load for new embarks:',
    save_fn=save_work_details,
    load_fn=load_work_details,
    has_data_fn=has_saved_work_details,
    autostart_command='gui/settings-manager load-work-details',
}

function WorkDetailsOverlay:init()
    self.subviews.save.frame.w = 25
    self.subviews.save_flash.frame.l = 10
    self.subviews.load.frame.t = 1
    self.subviews.load.frame.l = 0
    self.subviews.load.frame.w = 25
    self.subviews.load_flash.frame.t = 1
    self.subviews.load_flash.frame.l = 10
end

OVERLAY_WIDGETS = {
    embark_difficulty=DifficultyEmbarkOverlay,
    embark_notification=DifficultyEmbarkNotificationOverlay,
    settings_difficulty=DifficultySettingsOverlay,
    standing_orders=StandingOrdersOverlay,
    work_details=WorkDetailsOverlay,
}

if dfhack_flags.module then
    return
end

------------------------------
-- CLI processing
--

local help = false

local positionals = argparse.processArgsGetopt({...}, {
        {'h', 'help', handler=function() help = true end},
    })

local command = (positionals or {})[1]

if help then
    print(dfhack.script_help())
    return
end

local scr = dfhack.gui.getDFViewscreen(true)
local is_embark = df.viewscreen_setupdwarfgamest:is_instance(scr)
local is_fort = df.viewscreen_dwarfmodest:is_instance(scr)

if command == 'save-difficulty' then
    if is_embark then save_difficulty(scr.difficulty)
    elseif is_fort then
        save_difficulty(df.global.game.main_interface.settings.difficulty)
    else
        qerror('must be on the embark preparation screen or in a loaded fort')
    end
elseif command == 'load-difficulty' then
    if is_embark then
        load_difficulty(scr.difficulty)
        show_notification = true
    elseif is_fort then
        load_difficulty(df.global.game.main_interface.settings.difficulty)
    else
        qerror('must be on the embark preparation screen or in a loaded fort')
    end
elseif command == 'save-standing-orders' then
    if is_fort then save_standing_orders()
    else
        qerror('must be in a loaded fort')
    end
elseif command == 'load-standing-orders' then
    if is_fort then load_standing_orders()
    else
        qerror('must be in a loaded fort')
    end
elseif command == 'save-work-details' then
    if is_fort then save_work_details()
    else
        qerror('must be in a loaded fort')
    end
elseif command == 'load-work-details' then
    if is_fort then load_work_details()
    else
        qerror('must be in a loaded fort')
    end
else
    print(dfhack.script_help())
end

return

--[[

TODO: reinstate color editor

-- An in-game init file editor

VERSION = '0.6.0'

local gui = require "gui"
local dialog = require 'gui.dialogs'
local widgets = require "gui.widgets"

local enabler = df.global.enabler
local gps = df.global.gps

-- settings-manager display settings
ui_settings = {
    color = COLOR_GREEN,
    highlightcolor = COLOR_LIGHTGREEN,
}

function dup_table(tbl)
    -- Given {a, b, c}, returns {{a, a}, {b, b}, {c, c}}
    local t = {}
    for i = 1, #tbl do
        table.insert(t, {tbl[i], tbl[i]})
    end
    return t
end

function set_variable(name, value)
    local parts = name:split('.', true)
    local last_field = table.remove(parts, #parts)
    parent = _G
    for _, field in pairs(parts) do
        parent = parent[field]
    end
    parent[last_field] = value
end

-- Validation, used in FONT, FULLFONT, GRAPHICS_FONT, and GRAPHICS_FULLFONT
function font_exists(font)
    if font ~= '' and file_exists('data/art/' .. font) then
        return true
    else
        return false, '"' .. font .. '" does not exist'
    end
end

-- Used in NICKNAME_DWARF, NICKNAME_ADVENTURE, and NICKNAME_LEGENDS
local nickname_choices = {
    {'REPLACE_FIRST', 'Replace first name'},
    {'CENTRALIZE', 'Display between first and last name'},
    {'REPLACE_ALL', 'Replace entire name'}
}

-- Used in PRINT_MODE
local print_modes = {
    {'2D', '2D (default)'}, {'2DSW', '2DSW'}, {'2DASYNC', '2DASYNC'},
    {'STANDARD', 'STANDARD (OpenGL)'}, {'PROMPT', 'Prompt (STANDARD/2D)'},
    {'ACCUM_BUFFER', 'ACCUM_BUFFER'}, {'FRAME_BUFFER', 'FRAME_BUFFER'}, {'VBO', 'VBO'}
}
if dfhack.getOSType() == 'linux' or dfhack.getOSType() == 'darwin' then
    table.insert(print_modes, {'TEXT', 'TEXT (ncurses)'})
end

Setting descriptions

Settings listed MUST exist, but settings not listed will be ignored

Fields:
- id: "Tag name" in file (e.g. [id:params])
- type: Data type (used for entry). Valid choices:
  - 'bool' - boolean - "Yes" and "No", saved as "YES" and "NO"
  - 'int' - integer
  - 'string'
  - 'select' - string input restricted to the values given in the 'choices' field
- desc: Human-readable description
    '>>' is converted to string.char(192) .. ' '
- min (optional): Minimum
    Requires type 'int'
- max (optional): Maximum
    Requires type 'int'
- choices: A list of valid options
    Requires type 'select'
    Each choice should be a table of the following format:
    { "RAW_VALUE", "Human-readable value" [, "Enum value"] }
- validate (optional): Function that recieves string as input, should return true or false
    Requires type 'string'
- in_game (optional): Value to modify to change setting in-game (as a string)
    For type 'select', requires 'enum' to be specified
- enum: Enum to convert string setting values to in-game (numeric) values
    Uses "Enum value" specified in 'choices', or "RAW_VALUE" if not specified

Reserved field names:
- value (set to current setting value when settings are loaded)

SETTINGS = {
    init = {
        {id = 'SOUND', type = 'bool', desc = 'Enable sound'},
        {id = 'VOLUME', type = 'int', desc = '>>Volume', min = 0, max = 255},
        {id = 'INTRO', type = 'bool', desc = 'Display intro movies'},
        {id = 'WINDOWED', type = 'select', desc = 'Start in windowed mode',
            choices = {{'YES', 'Yes'}, {'PROMPT', 'Prompt'}, {'NO', 'No'}}
        },
        {id = 'WINDOWEDX', type = 'int', desc = 'Windowed X dimension (columns)', min = 80},
        {id = 'WINDOWEDY', type = 'int', desc = 'Windowed Y dimension (rows)', min = 25},
        {id = 'RESIZABLE', type = 'bool', desc = 'Allow resizing window'},
        {id = 'FONT', type = 'string', desc = 'Font (windowed)', validate = font_exists},
        {id = 'FULLSCREENX', type = 'int', desc = 'Fullscreen X dimension (columns)', min = 0},
        {id = 'FULLSCREENY', type = 'int', desc = 'Fullscreen Y dimension (rows)', min = 0},
        {id = 'FULLFONT', type = 'string', desc = 'Font (fullscreen)', validate = font_exists},
        {id = 'BLACK_SPACE', type = 'select', desc = 'Mismatched resolution behavior',
            choices = {{'YES', 'Pad with black space'}, {'NO', 'Stretch tiles'}}
        },
        {id = 'GRAPHICS', type = 'bool', desc = 'Enable graphics'},
        {id = 'GRAPHICS_WINDOWEDX', type = 'int', desc = '>>Windowed X dimension (columns)', min = 80},
        {id = 'GRAPHICS_WINDOWEDY', type = 'int', desc = '>>Windowed Y dimension (rows)', min = 25},
        {id = 'GRAPHICS_FONT', type = 'string', desc = '>>Font (windowed)', validate = font_exists},
        {id = 'GRAPHICS_FULLSCREENX', type = 'int', desc = '>>Fullscreen X dimension (columns)', min = 0},
        {id = 'GRAPHICS_FULLSCREENY', type = 'int', desc = '>>Fullscreen Y dimension (rows)', min = 0},
        {id = 'GRAPHICS_FULLFONT', type = 'string', desc = '>>Font (fullscreen)', validate = font_exists},

        {id = 'PRINT_MODE', type = 'select', desc = 'Print mode', choices = print_modes},
        {id = 'SINGLE_BUFFER', type = 'bool', desc = '>>Single-buffer'},
        {id = 'ARB_SYNC', type = 'bool', desc = '>>Enable ARB_sync (unstable)'},
        {id = 'VSYNC', type = 'bool', desc = '>>Enable vertical synchronization'},
        {id = 'TEXTURE_PARAM', type = 'select', desc = '>>Texture value behavior', choices = {
            {'NEAREST', 'Use nearest pixel'}, {'LINEAR', 'Average over adjacent pixels'}
        }},

        {id = 'TOPMOST', type = 'bool', desc = 'Make DF topmost window'},
        {id = 'FPS', type = 'bool', desc = 'Show FPS indicator',
            in_game = 'df.global.gps.display_frames',
            in_game_type = 'int',
        },
        {id = 'FPS_CAP', type = 'int', desc = 'Computational FPS cap', min = 1,
            in_game = 'df.global.enabler.fps', -- can't be set to 0
        },
        {id = 'G_FPS_CAP', type = 'int', desc = 'Graphical FPS cap', min = 1,
            in_game = 'df.global.enabler.gfps',
        },

        {id = 'PRIORITY', type = 'select', desc = 'Process priority',
            choices = dup_table({'REALTIME', 'HIGH', 'ABOVE_NORMAL', 'NORMAL', 'BELOW_NORMAL', 'IDLE'})
        },

        {id = 'ZOOM_SPEED', type = 'int', desc = 'Zoom speed', min = 1},
        {id = 'MOUSE', type = 'bool', desc = 'Enable mouse'},
        {id = 'MOUSE_PICTURE', type = 'bool', desc = '>>Use custom cursor'},

        {id = 'KEY_HOLD_MS', type = 'int', desc = 'Key repeat delay (ms)'},
        {id = 'KEY_REPEAT_ACCEL_LIMIT', type = 'int', desc = '>>Maximum key acceleration (multiple)', min = 1},
        {id = 'KEY_REPEAT_ACCEL_START', type = 'int', desc = '>>Key acceleration delay', min = 1},
        {id = 'MACRO_MS', type = 'int', desc = 'Macro instruction delay (ms)', min = 0,
            in_game = 'df.global.init.input.macro_time'},
        {id = 'RECENTER_INTERFACE_SHUTDOWN_MS', type = 'int', desc = 'Delay after recentering (ms)', min = 0,
            in_game = 'df.global.init.input.pause_zoom_no_interface_ms'},

        {id = 'COMPRESSED_SAVES', type = 'bool', desc = 'Enable compressed saves'},
    },
    d_init = {
        {id = 'AUTOSAVE', type = 'select', desc = 'Autosave', choices = {
            {'NONE', 'Disabled'}, {'SEASONAL', 'Seasonal'}, {'YEARLY', 'Yearly'}
        }},
        {id = 'AUTOBACKUP', type = 'bool', desc = 'Make backup copies of automatic saves'},
        {id = 'AUTOSAVE_PAUSE', type = 'bool', desc = 'Pause after autosaving'},
        {id = 'INITIAL_SAVE', type = 'bool', desc = 'Save after embarking'},
        {id = 'EMBARK_WARNING_ALWAYS', type = 'bool', desc = 'Always prompt before embark'},
        {id = 'SHOW_EMBARK_TUNNEL', type = 'select', desc = 'Local feature visibility', choices = {
            {'ALWAYS', 'Always'}, {'FINDER', 'Only in site finder'}, {'NO', 'Never'}
        }},

        {id = 'TEMPERATURE', type = 'bool', desc = 'Enable temperature'},
        {id = 'WEATHER', type = 'bool', desc = 'Enable weather'},
        {id = 'INVADERS', type = 'bool', desc = 'Enable invaders'},
        {id = 'CAVEINS', type = 'bool', desc = 'Enable cave-ins'},
        {id = 'ARTIFACTS', type = 'bool', desc = 'Enable artifacts'},
        {id = 'TESTING_ARENA', type = 'bool', desc = 'Enable object testing arena'},
        {id = 'WALKING_SPREADS_SPATTER_DWF', type = 'bool', desc = 'Walking spreads spatter (fort mode)'},
        {id = 'WALKING_SPREADS_SPATTER_ADV', type = 'bool', desc = 'Walking spreads spatter (adv mode)'},

        {id = 'LOG_MAP_REJECTS', type = 'bool', desc = 'Log map rejects'},
        {id = 'EMBARK_RECTANGLE', type = 'string', desc = 'Default embark size (x:y)', validate = function(s)
            local parts = s:split(':')
            if #parts == 2 then
                a, b = tonumber(parts[1]), tonumber(parts[2])
                if a~= nil and b ~= nil and a >= 2 and a <= 16 and b >= 2 and b <= 16 then
                    return true
                end
            else
                return false, 'Must be in format "x:y"'
            end
            return false, 'Dimensions must be integers\nbetween 2 and 16'
        end},
        {id = 'IDLERS', type = 'select', desc = 'Idlers indicator (fortress mode)', choices = {
            {'TOP', 'Top'}, {'BOTTOM', 'Bottom'}, {'OFF', 'Disabled'}
        }},
        {id = 'SET_LABOR_LISTS', type = 'select', desc = 'Automatically set labors', choices = {
            {'SKILLS', 'By skill'}, {'BY_UNIT_TYPE', 'By unit type'}, {'NO', 'Disabled'}
        }},
        {id = 'POPULATION_CAP', type = 'int', desc = 'Population cap', min = 0,
            in_game = 'df.global.d_init.population_cap'},
        {id = 'STRICT_POPULATION_CAP', type = 'int', desc = 'Strict population cap',
            min = 0, in_game = 'df.global.d_init.strict_population_cap'},
        {id = 'VARIED_GROUND_TILES', type = 'bool', desc = 'Varied ground tiles'},
        {id = 'ENGRAVINGS_START_OBSCURED', type = 'bool', desc = 'Obscure engravings by default'},
        {id = 'SHOW_IMP_QUALITY', type = 'bool', desc = 'Show item quality indicators'},
        {id = 'SHOW_FLOW_AMOUNTS', type = 'select', desc = 'Liquid display', choices = {
            {'NO', 'Symbols (' .. string.char(247) .. ')'}, {'YES', 'Numbers (1-7)'}
        }},
        {id = 'SHOW_ALL_HISTORY_IN_DWARF_MODE', type = 'bool', desc = 'Show all history (fortress mode)'},
        {id = 'DISPLAY_LENGTH', type = 'int', desc = 'Announcement display length (adv mode)', min = 1,
            in_game = 'df.global.d_init.display_length'},
        {id = 'MORE', type = 'bool', desc = '>>"More" indicator',
            in_game = 'df.global.d_init.flags2.MORE'},
        {id = 'ADVENTURER_TRAPS', type = 'bool', desc = 'Enable traps in adventure mode'},
        {id = 'ADVENTURER_ALWAYS_CENTER', type = 'bool', desc = 'Center screen on adventurer'},
        {id = 'NICKNAME_DWARF', type = 'select', desc = 'Nickname behavior (fortress mode)', choices = nickname_choices},
        {id = 'NICKNAME_ADVENTURE', type = 'select', desc = 'Nickname behavior (adventure mode)', choices = nickname_choices},
        {id = 'NICKNAME_LEGENDS', type = 'select', desc = 'Nickname behavior (legends mode)', choices = nickname_choices},
    },
    colors = {
        -- populated below
    }
}

COLORS = {
    {id = 'BLACK', name = 'Black'},
    {id = 'BLUE', name = 'Dark Blue'},
    {id = 'GREEN', name = 'Dark Green'},
    {id = 'CYAN', name = 'Dark Cyan'},
    {id = 'RED', name = 'Dark Red'},
    {id = 'MAGENTA', name = 'Dark Magenta'},
    {id = 'BROWN', name = 'Brown'},
    {id = 'LGRAY', name = 'Light Gray'},
    {id = 'DGRAY', name = 'Dark Gray'},
    {id = 'LBLUE', name = 'Light Blue'},
    {id = 'LGREEN', name = 'Light Green'},
    {id = 'LCYAN', name = 'Light Cyan'},
    {id = 'LRED', name = 'Light Red'},
    {id = 'LMAGENTA', name = 'Light Magenta'},
    {id = 'YELLOW', name = 'Yellow'},
    {id = 'WHITE', name = 'White'},
}

for k, v in pairs(COLORS) do
    v.num_id = k - 1
    for _, component in pairs({'R', 'G', 'B'}) do
        table.insert(SETTINGS.colors, {
            id = v.id .. '_' .. component,
            type = 'int',
            min = 0,
            max = 255,
            desc = v.name .. ' - ' .. component
        })
    end
end

function file_exists(path)
    local f = io.open(path, "r")
    if f ~= nil then io.close(f) return true
    else return false
    end
end

function settings_load()
    for file, settings in pairs(SETTINGS) do
        local f = io.open('data/init/' .. file .. '.txt')
        local contents = f:read('*all')
        for i, s in pairs(settings) do
            local a, b = contents:find('[' .. s.id .. ':', 1, true)
            if a ~= nil then
                s.value = contents:sub(b + 1, contents:find(']', b, true) - 1)
            else
                return false, 'Could not find "' .. s.id .. '" in ' .. file .. '.txt'
            end
        end
        f:close()
    end
    return true
end

function settings_save()
    for file, settings in pairs(SETTINGS) do
        local path = 'data/init/' .. file .. '.txt'
        local f = io.open(path, 'r')
        local contents = f:read('*all')
        for i, s in pairs(settings) do
            local a, b = contents:find('[' .. s.id .. ':', 1, true)
            if a ~= nil then
                local e = contents:find(']', b, true)
                contents = contents:sub(1, b) .. s.value .. contents:sub(e)
            else
                return false, 'Could not find ' .. s.id .. ' in ' .. file .. '.txt'
            end
        end
        f:close()
        f = io.open(path, 'w')
        f:write(contents)
        f:close()
    end
    print('Saved settings')
end

function dialog.showValidationError(str)
    dialog.showMessage('Error', str, COLOR_LIGHTRED)
end

settings_manager = defclass(settings_manager, gui.FramedScreen)
settings_manager.focus_path = 'settings_manager'

function settings_manager:reset()
    self.frame_title = "Settings"
    self.file = nil
end

function settings_manager:init()
    self:reset()
    local file_list = widgets.List{
        choices = {"init.txt", "d_init.txt", "colors.txt"},
        text_pen = {fg = ui_settings.color},
        cursor_pen = {fg = ui_settings.highlightcolor},
        on_submit = self:callback("select_file"),
        frame = {l = 1, t = 3},
        view_id = "file_list",
    }
    local file_page = widgets.Panel{
        subviews = {
            widgets.Label{
                text = 'File:',
                frame = {l = 1, t = 1},
            },
            file_list,
            widgets.Label{
                text = {
                    {key = 'LEAVESCREEN', text = ': Back'}
                },
                frame = {l = 1, t = 4 + #file_list.choices},
            },
            widgets.Label{
                text = 'settings-manager v' .. VERSION,
                frame = {l = 1, b = 0},
                text_pen = {fg = COLOR_GREY},
            },
        },
    }
    local settings_list = widgets.List{
        choices = {},
        text_pen = {fg = ui_settings.color},
        cursor_pen = {fg = ui_settings.highlightcolor},
        on_submit = self:callback("edit_setting"),
        frame = {l = 1, t = 1, b = 3},
        view_id = "settings_list",
    }
    local settings_page = widgets.Panel{
        subviews = {
            settings_list,
            widgets.Label{
                text = {
                    {key = "LEAVESCREEN", text = ": Back"},
                },
                frame = {l = 1, b = 1},
            },
        },
        view_id = "settings_page",
    }
    local pages = widgets.Pages{
        subviews = {file_page, settings_page},
        view_id = "pages"
    }
    self:addviews{
        pages
    }
end

function settings_manager:onInput(keys)
    local page = self.subviews.pages:getSelected()
    if keys.LEAVESCREEN then
        if page == 2 then
            settings_save()
            self.subviews.pages:setSelected(1)
            self:reset()
        else
            self:dismiss()
        end
    elseif keys.CURSOR_RIGHT or keys.CURSOR_LEFT or keys.CURSOR_RIGHT_FAST or keys.CURSOR_LEFT_FAST then
        if self.page == 2 then
            local incr
            if keys.CURSOR_RIGHT then incr = 1
            elseif keys.CURSOR_RIGHT_FAST then incr = 10
            elseif keys.CURSOR_LEFT then incr = -1
            elseif keys.CURSOR_LEFT_FAST then incr = -10
            end
            local setting = self:get_selected_setting()
            val = setting.value
            if setting.type == 'int' then
                val = val + incr
                if setting.min ~= nil then val = math.max(setting.min, val) end
                if setting.max ~= nil then val = math.min(setting.max, val) end
                self:commit_edit(nil, val)
            elseif setting.type == 'bool' then
                val = (val == 'YES' and 0) or 1
                self:commit_edit(nil, val)
            end
        end
    elseif keys._MOUSE_L_DOWN then
        local mouse_y = df.global.gps.mouse_y
        local list = nil
        if page == 1 then
            list = self.subviews.file_list
        elseif page == 2 then
            list = self.subviews.settings_list
        end
        if list then
            local idx = mouse_y - list.frame.t
            if idx <= #list:getChoices() and idx >= 1 then
                list:setSelected(idx)
                list:submit()
            end
        end
    end
    self.super.onInput(self, keys)
end

function settings_manager:select_file(index, choice)
    local res, err = settings_load()
    if not res then
        dialog.showMessage('Error loading settings', err, COLOR_LIGHTRED, self:callback('dismiss'))
    end
    if choice.text == 'colors.txt' then
        color_editor():show()
        return
    end
    self.frame_title = choice.text
    self.file = choice.text:sub(1, choice.text:find('.', 1, true) - 1)
    self.subviews.pages:setSelected(2)
    self:refresh_settings_list()
end

function settings_manager:refresh_settings_list()
    self.subviews.settings_list:setChoices(self:get_choice_strings(self.file))
end

function settings_manager:get_value_string(opt)
    local value_str = '<unknown>'
    if opt.value ~= nil then
        if opt.type == 'int' or opt.type == 'string' then
            value_str = opt.value
        elseif opt.type == 'bool' then
            value_str = opt.value:lower():gsub("^%l", string.upper)
        elseif opt.type == 'select' then
            for i, c in pairs(opt.choices) do
                if c[1] == opt.value then
                    value_str = c[2]
                end
            end
        end
    end
    return value_str
end

function settings_manager:get_choice_strings(file)
    local settings = SETTINGS[file] or error('Invalid settings file: ' .. file)
    local choices = {}
    for i, opt in pairs(settings) do
        table.insert(choices, ('%-40s %s'):format(opt.desc:gsub('>>', string.char(192) .. ' '), self:get_value_string(opt)))
    end
    return choices
end

function settings_manager:get_selected_setting()
    return SETTINGS[self.file][self.subviews.settings_list:getSelected()]
end

function settings_manager:edit_setting(index, choice)
    local setting = SETTINGS[self.file][index]
    local desc = setting.desc:gsub('>>', '')
    if setting.type == 'bool' then
        dialog.showListPrompt(
            desc,
            nil,
            COLOR_WHITE,
            {'Yes', 'No'},
            self:callback('commit_edit', index)
        )
    elseif setting.type == 'int' then
        local text = ''
        if setting.min then
            text = text .. 'min: ' .. setting.min
        end
        if setting.max then
            text = text .. ', max: ' .. setting.max
        end
        while text:sub(1, 1) == ' ' or text:sub(1, 1) == ',' do
            text = text:sub(2)
        end
        dialog.showInputPrompt(
            desc,
            text,
            COLOR_WHITE,
            '',
            self:callback('commit_edit', index)
        )
    elseif setting.type == 'string' then
        dialog.showInputPrompt(
            desc,
            nil,
            COLOR_WHITE,
            setting.value,
            self:callback('commit_edit', index)
        )
    elseif setting.type == 'select' then
        local choices = {}
        for i, c in pairs(setting.choices) do
            table.insert(choices, c[2])
        end
        dialog.showListPrompt(
            desc,
            nil,
            COLOR_WHITE,
            choices,
            self:callback('commit_edit', index)
        )
    end
end

local bool_value_map = {
    YES = {bool = true, int = 1},
    NO = {bool = false, int = 0},
}
function settings_manager:commit_edit(index, value)
    local setting = self:get_selected_setting()
    if setting.type == 'bool' then
        if value == 1 then
            value = 'YES'
        else
            value = 'NO'
        end
        if setting.in_game ~= nil then
            set_variable(setting.in_game, bool_value_map[value][setting.in_game_type or 'bool'])
        end
    elseif setting.type == 'int' then
        if value == '' then return false end
        value = tonumber(value)
        if value == nil or value ~= math.floor(value) then
            dialog.showValidationError('Must be a number!')
            return false
        end
        if setting.min and value < setting.min then
            dialog.showValidationError(value .. ' is too low!')
            return false
        end
        if setting.max and value > setting.max then
            dialog.showValidationError(value .. ' is too high!')
            return false
        end
        if setting.in_game ~= nil then
            set_variable(setting.in_game, value)
        end
    elseif setting.type == 'string' then
        if setting.validate then
            res, err = setting.validate(value)
            if not res then
                dialog.showValidationError(err)
                return false
            end
        end
    elseif setting.type == 'select' then
        value = setting.choices[value][1]
    end
    self:save_setting(value)
end

function settings_manager:save_setting(value)
    self:get_selected_setting().value = value
    self:refresh_settings_list()
end

color_editor = defclass(color_editor, gui.FramedScreen)
color_editor.focus_path = 'settings_manager/colors'
color_editor.ATTRS = {
    frame_title = 'Color editor',
    ui_colors = {
        black = 0,
        gray = 1,
        white = 2,
        r_min = 3,
        r_max = 4,
        g_min = 5,
        g_max = 6,
        -- 7 and 8 (DGRAY and LGRAY) reserved for frame border
        b_min = 9,
        b_max = 10,
        preview = 11,
    },
    component_names = {'Red', 'Green', 'Blue'},
    component_controls = {
        {increase = 'CUSTOM_R', decrease = 'CUSTOM_E', reset = 'CUSTOM_ALT_R',
         increase_fast = 'CUSTOM_SHIFT_R', decrease_fast = 'CUSTOM_SHIFT_E',},
        {increase = 'CUSTOM_G', decrease = 'CUSTOM_F', reset = 'CUSTOM_ALT_G',
         increase_fast = 'CUSTOM_SHIFT_G', decrease_fast = 'CUSTOM_SHIFT_F',},
        {increase = 'CUSTOM_B', decrease = 'CUSTOM_V', reset = 'CUSTOM_ALT_B',
         increase_fast = 'CUSTOM_SHIFT_B', decrease_fast = 'CUSTOM_SHIFT_V',},
        reset_all = 'CUSTOM_ALT_C',
    },
}

function color_editor:init()
    self.sel_idx = 0
    self.current_color = -1
    self.drag_component = -1
    self.real_colors = {}
    self.old_display_frames = df.global.gps.display_frames
    df.global.gps.display_frames = 0
    for i, color in pairs(df.global.enabler.ccolor) do
        self.real_colors[i] = {}
        for component, value in pairs(color) do
            self.real_colors[i][component] = value
        end
    end
    df.global.gps.force_full_display_count = 1
end

function color_editor:set_temp_color(color, r, g, b)
    df.global.enabler.ccolor[color][0] = r
    df.global.enabler.ccolor[color][1] = g
    df.global.enabler.ccolor[color][2] = b
end

function color_editor:set_ui_colors()
    local cc = self.real_colors[self.current_color]
    self:set_temp_color(self.ui_colors.black, 0, 0, 0)
    self:set_temp_color(self.ui_colors.gray, 0.5, 0.5, 0.5)
    self:set_temp_color(self.ui_colors.white, 1, 1, 1)
    self:set_temp_color(self.ui_colors.preview, cc[0], cc[1], cc[2])
    self:update_preview_colors()
    df.global.gps.force_full_display_count = 1
end

function color_editor:update_preview_colors()
    local pc = df.global.enabler.ccolor[self.ui_colors.preview]
    self:set_temp_color(self.ui_colors.r_min, 0, pc[1], pc[2])
    self:set_temp_color(self.ui_colors.r_max, 1, pc[1], pc[2])
    self:set_temp_color(self.ui_colors.g_min, pc[0], 0, pc[2])
    self:set_temp_color(self.ui_colors.g_max, pc[0], 1, pc[2])
    self:set_temp_color(self.ui_colors.b_min, pc[0], pc[1], 0)
    self:set_temp_color(self.ui_colors.b_max, pc[0], pc[1], 1)
    df.global.gps.force_full_display_count = 1
end

function color_editor:reset_color(color)
    for i = 0, 2 do
        df.global.enabler.ccolor[color][i] = self.real_colors[color][i]
    end
end

function color_editor:reset_colors()
    for i = 0, 15 do self:reset_color(i) end
end

function color_editor:color_to_pos(color)
    return ((color >= 8 and 40) or 1), ((color % 8) * 2 + 1)
end

function color_editor:pos_to_color(x, y)
    if x == nil then x = df.global.gps.mouse_x end
    if y == nil then y = df.global.gps.mouse_y end
    if y >= 2 and y <= 17 then
        if (x >= 2 and x <= 31) or (x >= 41 and x <= 70) then
            return math.floor((y - 2) / 2) + (x >= 41 and 8 or 0)
        end
    end
    return -1
end

function color_editor:full_color(color)
    if color == nil then color = self.current_color end
    return df.global.enabler.ccolor[color]
end

function color_editor:edit(color)
    self.current_color = color
    self.frame_title = (color == -1 and self.ATTRS.frame_title)
        or "Editing color: " .. COLORS[color + 1].name
    df.global.gps.force_full_display_count = 1
    if color ~= -1 then
        local cc = df.global.enabler.ccolor[self.current_color]
        self.sel_idx = color
        self:set_ui_colors()
    end
end

function color_editor:save()
    local id = COLORS[self.current_color + 1].id
    local cc = enabler.ccolor[self.ui_colors.preview]
    for k, v in pairs(SETTINGS.colors) do
        if v.id == id .. '_R' then
            v.value = math.floor(cc[0] * 255)
        elseif v.id == id .. '_G' then
            v.value = math.floor(cc[1] * 255)
        elseif v.id == id .. '_B' then
            v.value = math.floor(cc[2] * 255)
        end
    end
    self.real_colors[self.current_color][0] = cc[0]
    self.real_colors[self.current_color][1] = cc[1]
    self.real_colors[self.current_color][2] = cc[2]
end

function color_editor:process_color_keys(keys)
    local cc = df.global.enabler.ccolor[self.ui_colors.preview]
    local g_controls = self.component_controls
    for i = 0, 2 do
        local controls = self.component_controls[i + 1]
        if keys[controls.increase_fast] then
            keys[controls.increase_fast] = nil
            cc[i] = math.min(1, cc[i] + 10/255)
            self:update_preview_colors()
        end
        if keys[controls.increase] then
            keys[controls.increase] = nil
            cc[i] = math.min(1, cc[i] + 1/255)
            self:update_preview_colors()
        end
        if keys[controls.decrease] then
            keys[controls.decrease] = nil
            cc[i] = math.max(0, cc[i] - 1/255)
            self:update_preview_colors()
        end
        if keys[controls.decrease_fast] then
            keys[controls.decrease_fast] = nil
            cc[i] = math.max(0, cc[i] - 10/255)
            self:update_preview_colors()
        end
        if keys[controls.reset] or keys[g_controls.reset_all] then
            keys[controls.reset] = nil
            cc[i] = self.real_colors[self.current_color][i]
            self:update_preview_colors()
        end
    end
end

function color_editor:onInput(keys)
    if self.current_color == -1 then
        if keys.LEAVESCREEN then
            self:dismiss()
        elseif keys._MOUSE_L_DOWN then
            self:edit(self:pos_to_color())
        elseif keys.SELECT then
            self:edit(self.sel_idx)
        elseif keys.CURSOR_UP then
            self.sel_idx = self.sel_idx - 1
            if self.sel_idx < 0 then self.sel_idx = 15 end
        elseif keys.CURSOR_DOWN then
            self.sel_idx = self.sel_idx + 1
            if self.sel_idx > 15 then self.sel_idx = 0 end
        elseif keys.CURSOR_LEFT or keys.CURSOR_RIGHT then
            self.sel_idx = (self.sel_idx + 8) % 16
        end
    else
        if keys._MOUSE_L_DOWN and self.drag_component == -1 and gps.mouse_y >= 8 and gps.mouse_y <= 16 then
            self.drag_component = math.floor((gps.mouse_y - 8) / 3)
        end
        self:process_color_keys(keys)
        if keys.SELECT then
            self:save()
            keys.LEAVESCREEN = true
        end
        if keys.LEAVESCREEN then
            self:edit(-1)
            self:reset_colors()
        end
    end
end

function color_editor:onRenderBody(painter)
    if self.current_color == -1 then
        local space = (' '):rep(30)
        for i = 0, 15 do
            local x, y = self:color_to_pos(i)
            local color_name = (i == self.sel_idx and string.char(26) or ' ') ..
                                ' ' .. COLORS[i + 1].name .. ' ' ..
                                (i == self.sel_idx and string.char(27) or ' ')
            painter:pen({fg = COLOR_BLACK, bg = i})
            painter:seek(x, y):string(space)
            painter:seek(x, y + 1):string(space)
            painter:pen({fg = COLOR_WHITE, bg = i})
            painter:seek(x + 1, y + 1):string(color_name)
            painter:pen({fg = i, bg = COLOR_BLACK})
            painter:seek(x + 1, y):string(color_name)
        end
    else
        local min_x = 2
        local max_x = df.global.gps.dimx - 4
        local bar_min_x = min_x + 4
        local bar_max_x = max_x - 4
        local bar_width = bar_max_x - bar_min_x + 1
        local mouse_x = gps.mouse_x - 1
        local mouse_y = gps.mouse_y - 1
        if enabler.mouse_lbut == 1 and self.drag_component ~= -1 then
            local cc = enabler.ccolor[self.ui_colors.preview]
            local old_color = cc[self.drag_component]
            if mouse_x >= bar_max_x then
                cc[self.drag_component] = 1
            elseif mouse_x <= bar_min_x then
                cc[self.drag_component] = 0
            else
                cc[self.drag_component] = ((mouse_x - bar_min_x) / bar_width) + (1 / (2 * bar_width))
                if math.abs(cc[self.drag_component] - 128/255) <= 1/255 then
                    -- snap to 128/255
                    cc[self.drag_component] = 128/255
                end
            end
            if old_color ~= cc[self.drag_component] then
                self:update_preview_colors()
            end
        elseif enabler.mouse_lbut == 0 then
            self.drag_component = -1
        end
        local space = (' '):rep(70)
        painter:pen({fg = self.ui_colors.gray, bg = self.ui_colors.black})
               :seek(2,  1):string(string.char(205):rep(70))
               :seek(2,  4):string(string.char(205):rep(70))
               :seek(1,  1):string(string.char(201))
               :seek(72, 1):string(string.char(187))
               :seek(1,  2):string(string.char(186))
               :seek(72, 2):string(string.char(186))
               :seek(1,  3):string(string.char(186))
               :seek(72, 3):string(string.char(186))
               :seek(1,  4):string(string.char(200))
               :seek(72, 4):string(string.char(188))
        painter:pen({fg = self.ui_colors.white})
               :seek(3,  1):string('Preview:')
        painter:pen({bg = self.ui_colors.preview})
               :seek(2,  2):string(space)
               :seek(2,  3):string(space)
        for i = 1, 3 do
            local y = 3 * i + 4
            local bar = string.char(198) .. string.char(205):rep(bar_width - 2) .. string.char(181)
            local controls = self.component_controls[i]
            local value = df.global.enabler.ccolor[self.ui_colors.preview][i - 1]
            local rgb_value = value * 255
            local min_color_id = ({self.ui_colors.r_min, self.ui_colors.g_min, self.ui_colors.b_min})[i]
            painter:pen({fg = self.ui_colors.white})
                   :seek(bar_min_x + 1, y)
                   :string(('%s <%i>'):format(self.component_names[i], math.floor(rgb_value)))
                   :seek(bar_min_x + 5, y + 2)
                   :string(('%s,%s: Decrease    %s: Reset    %s,%s: Increase'):format(
                        dfhack.screen.getKeyDisplay(df.interface_key[controls.decrease_fast]),
                        dfhack.screen.getKeyDisplay(df.interface_key[controls.decrease]),
                        dfhack.screen.getKeyDisplay(df.interface_key[controls.reset]),
                        dfhack.screen.getKeyDisplay(df.interface_key[controls.increase]),
                        dfhack.screen.getKeyDisplay(df.interface_key[controls.increase_fast])
                    ))
            painter:pen({fg = self.ui_colors.gray})
                   :seek(bar_min_x, y + 1)
                   :string(bar)
            -- cursor
            painter:pen({fg = self.ui_colors.white})
                   :seek(math.min(bar_max_x, bar_min_x + math.floor(bar_width * value)), y + 1)
                   :string(string.char(233))
            painter:pen({bg = min_color_id})
                   :seek(min_x, y + 1)
                   :string('    ')
            painter:pen({bg = min_color_id + 1})
                   :seek(max_x - 3, y + 1)
                   :string('    ')
        end
        painter:pen({fg = self.ui_colors.white})
               :seek(7, 5)
               :string(dfhack.screen.getKeyDisplay(df.interface_key[self.component_controls.reset_all]) .. ': Reset')
               :seek(1, painter.y2 - 2)
               :string(dfhack.screen.getKeyDisplay(df.interface_key.LEAVESCREEN) .. ': Cancel')
               :seek(painter.x2 - 15, painter.y2 - 2)
               :string(dfhack.screen.getKeyDisplay(df.interface_key.SELECT) .. ': Save')
    end
end

function color_editor:onDismiss()
    self:reset_colors()
    df.global.gps.force_full_display_count = 1
    df.global.gps.display_frames = self.old_display_frames
    settings_save()
end

if dfhack.gui.getCurFocus() == 'dfhack/lua/settings_manager' then
    dfhack.screen.dismiss(dfhack.gui.getCurViewscreen())
end
settings_manager():show()

]]
