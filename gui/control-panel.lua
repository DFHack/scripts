local common = reqscript('internal/control-panel/common')
local dialogs = require('gui.dialogs')
local gui = require('gui')
local helpdb = require('helpdb')
local textures = require('gui.textures')
local overlay = require('plugins.overlay')
local registry = reqscript('internal/control-panel/registry')
local widgets = require('gui.widgets')

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

--
-- ConfigPanel
--

-- provides common structure across control panel tabs
ConfigPanel = defclass(ConfigPanel, widgets.Panel)
ConfigPanel.ATTRS{
    intro_text=DEFAULT_NIL,
}

function ConfigPanel:init()
    local main_panel = widgets.Panel{
        frame={t=0, b=7},
        autoarrange_subviews=true,
        autoarrange_gap=1,
        subviews={
            widgets.WrappedLabel{
                frame={t=0},
                text_to_wrap=self.intro_text,
            },
            -- extended by subclasses
        },
    }
    self:init_main_panel(main_panel)

    local footer = widgets.Panel{
        view_id='footer',
        frame={b=0, h=3},
        subviews={
            widgets.HotkeyLabel{
                frame={t=2, l=0},
                label='Restore defaults',
                key='CUSTOM_CTRL_D',
                auto_width=true,
                on_activate=self:callback('restore_defaults')
            },
            -- extended by subclasses
    }
    }
    self:init_footer(footer)

    self:addviews{
        main_panel,
        widgets.WrappedLabel{
            view_id='desc',
            frame={b=4, h=2},
            auto_height=false,
            text_to_wrap='', -- updated in on_select
        },
        footer,
    }
end

-- overridden by subclasses
function ConfigPanel:init_main_panel(panel)
end

-- overridden by subclasses
function ConfigPanel:init_footer(panel)
end

-- overridden by subclasses
function ConfigPanel:refresh()
end

-- overridden by subclasses
function ConfigPanel:restore_defaults()
end

-- attach to lists in subclasses
-- choice.data is an entry from one of the registry tables
function ConfigPanel:on_select(_, choice)
    local desc = self.subviews.desc
    desc.text_to_wrap = choice and common.get_description(choice.data) or ''
    if desc.frame_body then
        desc:updateLayout()
    end
end














--
-- Enabled subtab functions
--

local function get_gui_config(command)
    command = common.get_first_word(command)
    local gui_config = 'gui/' .. command
    if helpdb.is_entry(gui_config) then
        return gui_config
    end
end

local function make_enabled_text(self, command, mode, gui_config)
    local label = command
    if mode == 'system_enable' then
        label = label .. ' (global)'
    end

    local function get_enabled_button_token(enabled_tile, disabled_tile)
        return {
            tile=function() return self.enabled_map[command] and enabled_tile or disabled_tile end,
        }
    end

    local function get_config_button_token(tile)
        return {
            tile=gui_config and tile or nil,
            text=not gui_config and ' ' or nil,
        }
    end

    return {
        get_enabled_button_token(ENABLED_PEN_LEFT, DISABLED_PEN_LEFT),
        get_enabled_button_token(ENABLED_PEN_CENTER, DISABLED_PEN_CENTER),
        get_enabled_button_token(ENABLED_PEN_RIGHT, DISABLED_PEN_RIGHT),
        ' ',
        {tile=BUTTON_PEN_LEFT},
        {tile=HELP_PEN_CENTER},
        {tile=BUTTON_PEN_RIGHT},
        ' ',
        get_config_button_token(BUTTON_PEN_LEFT),
        get_config_button_token(CONFIGURE_PEN_CENTER),
        get_config_button_token(BUTTON_PEN_RIGHT),
        ' ',
        label,
    }
end

local function get_enabled_choices(self)
    local choices = {}
    self.enabled_map = common.get_enabled_map()
    for _,data in ipairs(registry.COMMANDS_BY_IDX) do
        if data.mode == 'run' then goto continue end
        if data.mode ~= 'system_enable' and not dfhack.world.isFortressMode() then
            goto continue
        end
        if not common.command_passes_filters(data, self.group) then goto continue end
        local gui_config = get_gui_config(data.command)
        table.insert(choices, {
            text=make_enabled_text(self, data.command, data.mode, gui_config),
            search_key=data.command,
            data=data,
            gui_config=gui_config,
        })
        ::continue::
    end
    return choices
end

local function enabled_onInput(self, keys)
    if not keys._MOUSE_L then return end
    local list = self.subviews.list.list
    local idx = list:getIdxUnderMouse()
    if idx then
        local x = list:getMousePos()
        if x <= 2 then
            self:on_submit()
        elseif x >= 4 and x <= 6 then
            self:show_help()
        elseif x >= 8 and x <= 10 then
            self:launch_config()
        end
    end
end

local function enabled_on_submit(self, data)
    common.apply_command(data, self.enabled_map, not self.enabled_map[data.command])
end

local function enabled_restore_defaults(self)
    for _,data in ipairs(registry.COMMANDS_BY_IDX) do
        if data.mode == 'run' then goto continue end
        if (data.mode == 'enable' or data.mode == 'repeat')
            and not dfhack.world.isFortressMode()
        then
            goto continue
        end
        if not common.command_passes_filters(data, self.group) then goto continue end
        common.apply_command(data, self.enabled_map, not not data.default)
        ::continue::
    end
end


--
-- Autostart subtab functions
--

local function make_autostart_text(label, mode, enabled)
    if mode == 'system_enable' then
        label = label .. ' (global)'
    end
    return {
        {tile=enabled and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT},
        {tile=enabled and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER},
        {tile=enabled and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT},
        ' ',
        {tile=BUTTON_PEN_LEFT},
        {tile=HELP_PEN_CENTER},
        {tile=BUTTON_PEN_RIGHT},
        ' ',
        label,
    }
end

local function get_autostart_choices(self)
    local choices = {}
    for _,data in ipairs(registry.COMMANDS_BY_IDX) do
        if not common.command_passes_filters(data, self.group) then goto continue end
        local enabled = safe_index(common.config.data.commands, data.command, 'autostart')
        if enabled == nil then
            enabled = data.default
        end
        table.insert(choices, {
            text=make_autostart_text(data.command, data.mode, enabled),
            search_key=data.command,
            data=data,
            enabled=enabled,
        })
        ::continue::
    end
    return choices
end

local function autostart_onInput(self, keys)
    if keys._MOUSE_L then
        local list = self.subviews.list.list
        local idx = list:getIdxUnderMouse()
        if idx then
            local x = list:getMousePos()
            if x <= 2 then
                self:on_submit()
            elseif x >= 4 and x <= 6 then
                self:show_help()
            end
        end
    end
end

local function autostart_on_submit(self, data)
    common.set_autostart(data, not choice.enabled)
    common.config:write()
end

local function autostart_restore_defaults(self)
    for _,data in ipairs(registry.COMMANDS_BY_IDX) do
        if not common.command_passes_filters(data, self.group) then goto continue end
        print(data.command, data.default)
        common.set_autostart(data, data.default)
        ::continue::
    end
    common.config:write()
end


--
-- CommandTab
--

CommandTab = defclass(CommandTab, ConfigPanel)
CommandTab.ATTRS {
    group=DEFAULT_NIL,
}

local Subtabs = {
    enabled=1,
    autostart=2,
}

local subtab = Subtabs.enabled

function CommandTab:init()
    self.blurbs = {
        [Subtabs.enabled]='These are the tools that can be enabled right now.'..
            ' Most tools can only be enabled when you have a fort loaded.'..
            ' Once enabled, tools will stay enabled when you save and reload'..
            ' your fort. If you want them to be auto-enabled for new forts,'..
            ' please see the "Autostart" tab.',
        [Subtabs.autostart]='Tools that are enabled on this page will be'..
            ' auto-run or auto-enabled for you when you start a new fort (or,'..
            ' for "global" tools, when you start the game). To see tools that'..
            ' are enabled right now, please click on the "Enabled" tab.',
    }
end

function CommandTab:init_main_panel(panel)
    panel:addviews{
        widgets.TabBar{
            view_id='subtabbar',
            frame={t=5},
            key='CUSTOM_CTRL_N',
            key_back='CUSTOM_CTRL_M',
            labels={
                'Enabled',
                'Autostart',
            },
            on_select=function(val)
                subtab = val
                self:updateLayout()
                self:refresh()
            end,
            get_cur_page=function() return subtab end,
        },
        widgets.WrappedLabel{
            frame={t=7},
            text_to_wrap=function() return self.blurbs[subtab] end,
        },
        widgets.FilteredList{
            frame={t=9},
            view_id='list',
            on_select=self:callback('on_select'),
            on_double_click=self:callback('on_submit'),
            on_double_click2=self:callback('launch_config'),
            row_height=2,
            visible=function() return #self.subviews.list:getChoices() > 0 end,
        },
        widgets.Label{
            frame={t=9, l=0},
            text={
                'Please load a fort to see the fort-mode tools. Alternately,', NEWLINE,
                'please switch to the "Autostart" tab to configure which', NEWLINE,
                'tools should be run or enabled on embark.',
            },
            text_pen=COLOR_LIGHTRED,
            visible=function() return #self.subviews.list:getChoices() == 0 end,
        },
    }
end

function CommandTab:init_footer(panel)
    panel:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='Toggle enabled',
            key='SELECT',
            auto_width=true,
            on_activate=self:callback('on_submit')
        },
        widgets.HotkeyLabel{
            frame={t=1, l=0},
            label='Show full tool help or run custom command',
            auto_width=true,
            key='CUSTOM_CTRL_H',
            on_activate=self:callback('show_help'),
        },
        widgets.HotkeyLabel{
            frame={t=2, l=26},
            label='Launch tool-specific config UI',
            key='CUSTOM_CTRL_G',
            auto_width=true,
            enabled=self:callback('has_config'),
            visible=function() return subtab == Subtabs.enabled end,
            on_activate=self:callback('launch_config'),
        },
    }
end

local function launch_help(data)
    dfhack.run_command('gui/launcher', data.help_command or data.command .. ' ')
end

function CommandTab:show_help()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    launch_help(choice.data)
end

function CommandTab:has_config()
    _,choice = self.subviews.list:getSelected()
    return choice and choice.gui_config
end

function CommandTab:launch_config()
    if subtab ~= Subtabs.enabled then return end
    _,choice = self.subviews.list:getSelected()
    if not choice or not choice.gui_config then return end
    dfhack.run_command(choice.gui_config)
end

function CommandTab:refresh()
    local choices = subtab == Subtabs.enabled and
        get_enabled_choices(self) or get_autostart_choices(self)
    local list = self.subviews.list
    local filter = list:getFilter()
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setFilter(filter, selected)
    list.edit:setFocus(true)
end

function CommandTab:on_submit()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    if subtab == Subtabs.enabled then
        enabled_on_submit(self, choice.data)
    else
        autostart_on_submit(self, choice.data)
    end
    self:refresh()
end

-- pick up enablement changes made from other sources (e.g. gui config tools)
function CommandTab:onRenderFrame(dc, rect)
    if subtab == Subtabs.enabled then
        self.enabled_map = common.get_enabled_map()
    end
    CommandTab.super.onRenderFrame(self, dc, rect)
end

function CommandTab:onInput(keys)
    local handled = CommandTab.super.onInput(self, keys)
    if subtab == Subtabs.enabled then
        enabled_onInput(self, keys)
    else
        autostart_onInput(self, keys)
    end
    return handled
end

function CommandTab:restore_defaults()
    dialogs.showYesNoPrompt('Are you sure?',
        ('Are you sure you want to restore %s\ndefaults for %s tools?'):format(
            self.subviews.subtabbar.labels[subtab], self.group),
        nil, function()
            if subtab == Subtabs.enabled then
                enabled_restore_defaults(self)
            else
                autostart_restore_defaults(self)
            end
            self:refresh()
            dialogs.showMessage('Success',
                ('%s defaults restored for %s tools.'):format(
                    self.subviews.subtabbar.labels[subtab], self.group))
        end)
end


--
-- AutomationTab
--

AutomationTab = defclass(AutomationTab, CommandTab)
AutomationTab.ATTRS{
    intro_text='These run in the background and help you manage your'..
        ' fort. They are always safe to enable, and allow you to concentrate'..
        ' on other aspects of gameplay that you find more enjoyable.',
    group='automation',
}


--
-- BugFixesTab
--

BugFixesTab = defclass(BugFixesTab, CommandTab)
BugFixesTab.ATTRS{
    intro_text='These automatically fix dangerous or annoying vanilla'..
        ' bugs. You should generally have all of these enabled.',
    group='bugfix',
}


--
-- GameplayTab
--

GameplayTab = defclass(GameplayTab, CommandTab)
GameplayTab.ATTRS{
    intro_text='These change or extend gameplay. Read their help docs to'..
        ' see what they do and enable the ones that appeal to you.',
    group='gameplay'
}


--
-- OverlaysTab
--

OverlaysTab = defclass(OverlaysTab, ConfigPanel)
OverlaysTab.ATTRS{
    intro_text='These are DFHack overlays that add information and'..
                ' functionality to native DF screens. You can toggle whether'..
                ' they are enabled here, or you can reposition them with'..
                ' gui/overlay.',
}

function OverlaysTab:init_main_panel(panel)
    panel:addviews{
        widgets.FilteredList{
            frame={t=5},
            view_id='list',
            on_select=self:callback('on_select'),
            on_double_click=self:callback('on_submit'),
            row_height=2,
        },
    }
end

function OverlaysTab:init_footer(panel)
    panel:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='Toggle overlay',
            key='SELECT',
            auto_width=true,
            on_activate=self:callback('on_submit')
        },
        widgets.HotkeyLabel{
            frame={t=1, l=0},
            label='Show overlay help',
            auto_width=true,
            key='CUSTOM_CTRL_H',
            on_activate=self:callback('show_help'),
        },
        widgets.HotkeyLabel{
            frame={t=2, l=26},
            label='Launch widget position adjustment UI',
            key='CUSTOM_CTRL_G',
            auto_width=true,
            on_activate=function() dfhack.run_script('gui/overlay') end,
        },
    }
end

function OverlaysTab:onInput(keys)
    local handled = OverlaysTab.super.onInput(self, keys)
    if keys._MOUSE_L then
        local list = self.subviews.list.list
        local idx = list:getIdxUnderMouse()
        if idx then
            local x = list:getMousePos()
            if x <= 2 then
                self:on_submit()
            elseif x >= 4 and x <= 6 then
                self:show_help()
            end
        end
    end
    return handled
end

local function make_overlay_text(label, enabled)
    return {
        {tile=enabled and ENABLED_PEN_LEFT or DISABLED_PEN_LEFT},
        {tile=enabled and ENABLED_PEN_CENTER or DISABLED_PEN_CENTER},
        {tile=enabled and ENABLED_PEN_RIGHT or DISABLED_PEN_RIGHT},
        ' ',
        {tile=BUTTON_PEN_LEFT},
        {tile=HELP_PEN_CENTER},
        {tile=BUTTON_PEN_RIGHT},
        ' ',
        label,
    }
end

function OverlaysTab:refresh()
    local choices = {}
    local state = overlay.get_state()
    for _,name in ipairs(state.index) do
        enabled = state.config[name].enabled
        local text = make_overlay_text(name, enabled)
        table.insert(choices, {
            text=text,
            search_key=name,
            data={
                name=name,
                command=name:match('^(.-)%.') or 'overlay',
                desc=state.db[name].widget.desc,
            },
            enabled=enabled,
        })
    end
    local list = self.subviews.list
    local filter = list:getFilter()
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setFilter(filter, selected)
    list.edit:setFocus(true)
end

local function enable_overlay(name, enabled)
    local tokens = {'overlay'}
    table.insert(tokens, enabled and 'enable' or 'disable')
    table.insert(tokens, name)
    dfhack.run_command(tokens)
end

function OverlaysTab:on_submit()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    local data = choice.data
    enable_overlay(data.name, not choice.enabled)
    self:refresh()
end

function OverlaysTab:restore_defaults()
    dialogs.showYesNoPrompt('Are you sure?',
    'Are you sure you want to restore overlay defaults?',
    nil, function()
        local state = overlay.get_state()
        for name, db_entry in pairs(state.db) do
            enable_overlay(name, db_entry.widget.default_enabled)
        end
        self:refresh()
        dialogs.showMessage('Success', 'Overlay defaults restored.')
    end)
end

function OverlaysTab:show_help()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    launch_help(choice.data)
end


--
-- PreferencesTab
--

IntegerInputDialog = defclass(IntegerInputDialog, widgets.Window)
IntegerInputDialog.ATTRS{
    visible=false,
    frame={w=50, h=11},
    frame_title='Edit setting',
    frame_style=gui.PANEL_FRAME,
    on_hide=DEFAULT_NIL,
}

function IntegerInputDialog:init()
    self:addviews{
        widgets.Label{
            frame={t=0, l=0},
            text={
                'Please enter a new value for ', NEWLINE,
                {
                    gap=4,
                    text=function() return self.id or '' end,
                },
                NEWLINE,
                {text=self:callback('get_spec_str')},
            },
        },
        widgets.EditField{
            view_id='input_edit',
            frame={t=4, l=0},
            on_char=function(ch) return ch:match('%d') end,
        },
        widgets.HotkeyLabel{
            frame={b=0, l=0},
            label='Save',
            key='SELECT',
            auto_width=true,
            on_activate=function() self:hide(self.subviews.input_edit.text) end,
        },
        widgets.HotkeyLabel{
            frame={b=0, r=0},
            label='Reset to default',
            key='CUSTOM_CTRL_D',
            auto_width=true,
            on_activate=function() self.subviews.input_edit:setText(tostring(self.data.default)) end,
        },
    }
end

function IntegerInputDialog:get_spec_str()
    local data = self.data
    local strs = {
        ('default: %d'):format(data.default),
    }
    if data.min then
        table.insert(strs, ('at least %d'):format(data.min))
    end
    if data.max then
        table.insert(strs, ('at most %d'):format(data.max))
    end
    return ('(%s)'):format(table.concat(strs, ', '))
end

function IntegerInputDialog:show(id, data, initial)
    self.visible = true
    self.id, self.data = id, data
    local edit = self.subviews.input_edit
    edit:setText(tostring(initial))
    edit:setFocus(true)
    self:updateLayout()
end

function IntegerInputDialog:hide(val)
    self.visible = false
    self.on_hide(tonumber(val))
end

function IntegerInputDialog:onInput(keys)
    if IntegerInputDialog.super.onInput(self, keys) then
        return true
    end
    if keys.LEAVESCREEN or keys._MOUSE_R then
        self:hide()
        return true
    end
end

PreferencesTab = defclass(PreferencesTab, ConfigPanel)
PreferencesTab.ATTRS{
    intro_text='These are the customizable DFHack system settings.',
}

function PreferencesTab:init_main_panel(panel)
    panel:addviews{
        widgets.FilteredList{
            frame={t=5},
            view_id='list',
            on_select=self:callback('on_select'),
            on_double_click=self:callback('on_submit'),
            row_height=3,
        },
        IntegerInputDialog{
            view_id='input_dlg',
            on_hide=self:callback('set_val'),
        },
    }
end

function PreferencesTab:init_footer(panel)
    panel:addviews{
        widgets.HotkeyLabel{
            frame={t=0, l=0},
            label='Toggle/edit setting',
            key='SELECT',
            auto_width=true,
            on_activate=self:callback('on_submit')
        },
    }
end

function PreferencesTab:onInput(keys)
    if self.subviews.input_dlg.visible then
        self.subviews.input_dlg:onInput(keys)
        return true
    end
    local handled = PreferencesTab.super.onInput(self, keys)
    if keys._MOUSE_L then
        local list = self.subviews.list.list
        local idx = list:getIdxUnderMouse()
        if idx then
            local x = list:getMousePos()
            if x <= 2 then
                self:on_submit()
            end
        end
    end
    return handled
end

local function make_preference_text(label, default, value)
    return {
        {tile=BUTTON_PEN_LEFT},
        {tile=CONFIGURE_PEN_CENTER},
        {tile=BUTTON_PEN_RIGHT},
        ' ',
        label,
        NEWLINE,
        {gap=4, text=('(default: %s, current: %s)'):format(default, value)},
    }
end

function PreferencesTab:refresh()
    if self.subviews.input_dlg.visible then return end
    local choices = {}
    for _, data in ipairs(registry.PREFERENCES_BY_IDX) do
        local text = make_preference_text(data.label, data.default, data.get_fn())
        table.insert(choices, {
            text=text,
            search_key=text[#text],
            data=data
        })
    end
    local list = self.subviews.list
    local filter = list:getFilter()
    local selected = list:getSelected()
    list:setChoices(choices)
    list:setFilter(filter, selected)
    list.edit:setFocus(true)
end

local function preferences_set_and_save(self, data, val)
    common.set_preference(data, val)
    common.config:write()
    self:refresh()
end

function PreferencesTab:on_submit()
    _,choice = self.subviews.list:getSelected()
    if not choice then return end
    local data = choice.data
    local cur_val = data.get_fn()
    local data_type = type(data.default)
    if data_type == 'boolean' then
        preferences_set_and_save(self, data, not cur_val)
    elseif data_type == 'number' then
        self.subviews.input_dlg:show(data.label, data, cur_val)
    end
end

function PreferencesTab:set_val(val)
    _,choice = self.subviews.list:getSelected()
    if not choice or not val then return end
    preferences_set_and_save(self, choice.data, val)
end

function PreferencesTab:restore_defaults()
    dialogs.showYesNoPrompt('Are you sure?',
    'Are you sure you want to restore default preferences?',
    nil, function()
        for _,data in ipairs(registry.PREFERENCES_BY_IDX) do
            common.set_preference(data, data.default)
        end
        common.config:write()
        self:refresh()
        dialogs.showMessage('Success', 'Default preferences restored.')
    end)
end


--
-- ControlPanel
--

ControlPanel = defclass(ControlPanel, widgets.Window)
ControlPanel.ATTRS {
    frame_title='DFHack Control Panel',
    frame={w=74, h=44},
    resizable=true,
    resize_min={h=39},
    autoarrange_subviews=true,
    autoarrange_gap=1,
}

function ControlPanel:init()
    self:addviews{
        widgets.TabBar{
            frame={t=0},
            labels={
                'Automation',
                'Bug Fixes',
                'Gameplay',
                'UI Overlays',
                'Preferences',
            },
            on_select=self:callback('set_page'),
            get_cur_page=function() return self.subviews.pages:getSelected() end,
        },
        widgets.Pages{
            view_id='pages',
            frame={t=5, l=0, b=0, r=0},
            subviews={
                AutomationTab{},
                BugFixesTab{},
                GameplayTab{},
                OverlaysTab{},
                PreferencesTab{},
            },
        },
    }

    if not dfhack.world.isFortressMode() then
        self.subviews.pages:setSelected(3)
    end

    self:refresh_page()
end

function ControlPanel:refresh_page()
    self.subviews.pages:getSelectedPage():refresh()
end

function ControlPanel:set_page(val)
    self.subviews.pages:setSelected(val)
    self:refresh_page()
    self:updateLayout()
end


--
-- ControlPanelScreen
--

ControlPanelScreen = defclass(ControlPanelScreen, gui.ZScreen)
ControlPanelScreen.ATTRS {
    focus_path='control-panel',
}

function ControlPanelScreen:init()
    self:addviews{ControlPanel{}}
end

function ControlPanelScreen:onDismiss()
    view = nil
end

view = view and view:raise() or ControlPanelScreen{}:show()
