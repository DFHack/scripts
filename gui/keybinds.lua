-- Graphically configure DFHack keybinds

local gui = require('gui')
local widgets = require('gui.widgets')

-- Constants
local initfile = "dfhack-config/init/dfhack.auto.keybinds.init"

--
-- Icons
--
local function make_button(ascii, pens, x, y)
    local out = {}
    for i = 1, 3 do
        local tmp = {}
        for j = 1, 3 do
            table.insert(tmp, {
                tile = dfhack.pen.parse {
                    ch = ascii[i][j],
                    fg = pens[i][j],
                    keep_lower = true,
                    tile = dfhack.screen.findGraphicsTile('INTERFACE_BITS', x + j - 1, y + i - 1)
                },
            })
        end
        table.insert(out, tmp)
    end
    return out
end

local trash_icon = make_button(
    {

        { 218, 196, 191 },
        { 179, 'D', 179 },
        { 192, 196, 217 },
    },
    {
        { COLOR_GRAY, COLOR_GRAY, COLOR_GRAY },
        { COLOR_GRAY, COLOR_RED,  COLOR_GRAY },
        { COLOR_GRAY, COLOR_GRAY, COLOR_GRAY },
    },
    41, 0
)
local inspect_icon = make_button(
    {
        { 218, 196, 191 },
        { 26,  'E', 179 },
        { 192, 196, 217 },
    },
    {
        { COLOR_GRAY,  COLOR_GRAY,   COLOR_GRAY },
        { COLOR_WHITE, COLOR_YELLOW, COLOR_GRAY },
        { COLOR_GRAY,  COLOR_GRAY,   COLOR_GRAY },
    },
    35, 0
)

--
-- SelectKeyDialog
--
SelectKeyDialog = defclass(SelectKeyDialog, gui.ZScreenModal)
SelectKeyDialog.ATTRS = {
    -- Callbacks
    on_select = DEFAULT_NIL,
    on_cancel = DEFAULT_NIL,
}

function SelectKeyDialog:init()
    self.warning = false
    self.key = nil

    self:addviews({
        widgets.Window {
            frame = { w = 65, h = 16 },
            frame_title = 'Select a Key Combination',
            frame_style = gui.FRAME_BOLD,
            resizable = false,
            subviews = {
                widgets.Label {
                    frame = { t = 0 },
                    text = { { text = self:callback('getKeyLabelText') } },
                    on_click = self:callback('startListeningForKey'),
                    auto_width = true,
                    xalign = 0.5,
                },
                widgets.Label {
                    frame = { t = 2 },
                    auto_width = true,
                    xalign = 0.5,
                    text_pen = COLOR_RED,
                    text = "WARNING: This keybind may be disruptive to gameplay.\nProceed cautiously.",
                    visible = function() return self.warning end,
                },
                widgets.HotkeyLabel {
                    frame = { b = 0, l = 2 },
                    key = 'SELECT',
                    label = 'Confirm',
                    auto_width = true,
                    enabled = function() return self.key ~= nil end,
                    on_activate = self:callback('onConfirm')
                },
                widgets.HotkeyLabel {
                    frame = { b = 0, l = 18 },
                    key = 'LEAVESCREEN',
                    label = 'Cancel',
                    auto_width = true,
                    on_click = self:callback('onCancel')
                },
            },
        },
    })

    self:startListeningForKey()
end

function SelectKeyDialog:onIdle()
    if not self.key then
        -- Check to see if we have gotten a key input since issuing the request
        self.key = dfhack.hotkey.getKeybindingInput()
        if self.key then
            self.needs_refresh = true
            self.warning = dfhack.hotkey.isDisruptiveKeybind(self.key)
        end
    end

    -- Force the width of the keyspec label to update
    if self.needs_refresh then
        self.needs_refresh = false
        self:updateLayout()
    end
end

function SelectKeyDialog:onConfirm()
    -- Cancel ongoing input requests
    dfhack.hotkey.requestKeybindingInput(true)

    self:dismiss()
    if self.on_select then self.on_select(self.key) end
end

function SelectKeyDialog:onCancel()
    -- Cancel ongoing input requests
    dfhack.hotkey.requestKeybindingInput(true)

    self:dismiss()
    if self.on_cancel then self.on_cancel() end
end

function SelectKeyDialog:startListeningForKey()
    self.key = nil
    self.needs_refresh = true
    dfhack.hotkey.requestKeybindingInput()
end

function SelectKeyDialog:getKeyLabelText()
    if self.key then
        return self.key
    else
        return "Listening..."
    end
end

function SelectKeyDialog:getWarningText()
    return self.warning and "WARNING: This keybind may be disruptive to gameplay." or ""
end

--
-- EditKeybindWindow
--
EditKeybindWindow = defclass(EditKeybindWindow, gui.ZScreenModal)
EditKeybindWindow.ATTRS = {
    hotkey = '',
    spec_focus = '',
    command = '',
    -- Callbacks
    on_apply = DEFAULT_NIL,
    on_cancel = DEFAULT_NIL,
}

function EditKeybindWindow:init()
    -- Specifically request the focus strings of the first *DF* viewscreen
    local focus_list = dfhack.gui.getFocusStrings(dfhack.gui.getDFViewscreen())
    self.current_focus = "Current context:"
    for i = 1, #focus_list do
        self.current_focus = self.current_focus .. "\n" .. focus_list[i]
    end

    self:addviews({
        widgets.Window {
            frame = { w = 65, h = 16 },
            frame_title = 'Edit Keybind',
            resizable = false,
            subviews = {
                widgets.HotkeyLabel {
                    key = 'CUSTOM_ALT_A',
                    frame = { t = 0, l = 0 },
                    label = 'Hotkey: ',
                    text_pen = COLOR_WHITE,
                    on_activate = self:callback('changeHotkey'),
                },
                widgets.Label {
                    frame = { t = 0, l = 15 },
                    text = { { text = function() return self.hotkey or '' end } },
                    text_pen = COLOR_CYAN,
                    on_click = self:callback('changeHotkey'),
                },
                widgets.EditField {
                    frame = { t = 2 },
                    key = 'CUSTOM_ALT_B',
                    label_text = 'Command to Execute: ',
                    text = self.command or '',
                    on_change = function(cmd, _) self.command = cmd end
                },
                widgets.Label {
                    frame = { t = 4 },
                    text = 'List of active contexts, separated by |.\n'
                        .. 'Blank for always active',
                    text_pen = COLOR_GRAY,
                },
                widgets.EditField {
                    frame = { t = 6 },
                    key = 'CUSTOM_ALT_C',
                    label_text = 'Focus Context: ',
                    text = self.spec_focus or '',
                    on_change = function(focus, _) self.spec_focus = focus end
                },
                widgets.Label {
                    frame = { t = 8 },
                    text = self.current_focus,
                },
                widgets.HotkeyLabel {
                    frame = { t = 11, l = 0 },
                    key = 'LEAVESCREEN',
                    label = 'Cancel',
                    auto_width = true,
                    on_activate = self:callback('onCancel'),
                },
                widgets.HotkeyLabel {
                    frame = { t = 11, l = 14 },
                    key = 'SELECT',
                    label = 'Apply',
                    auto_width = true,
                    enabled = function() return self.command ~= '' and self.hotkey ~= '' end,
                    on_activate = self:callback('onApply'),
                }
            },
        },
    })
end

function EditKeybindWindow:changeHotkey()
    self._key_dialog = SelectKeyDialog {
        on_select = function(key) self.hotkey = key end,
    }
    self._key_dialog:show()
end

function EditKeybindWindow:onApply()
    self:dismiss()
    if self.on_apply then
        self.on_apply(self.hotkey, self.spec_focus, self.command)
    end
end

function EditKeybindWindow:onCancel()
    self:dismiss()
    if self.on_cancel then self.on_cancel() end
end

--
-- SaveKeybindsWindow
--
SaveKeybindsWindow = defclass(SaveKeybindsWindow, gui.ZScreenModal)
SaveKeybindsWindow.ATTRS = {}

function SaveKeybindsWindow:init()
    self:addviews({
        widgets.Window {
            frame = { w = 65, h = 12 },
            frame_title = 'Save Keybinds',
            resizable = false,
            subviews = {
                widgets.WrappedLabel {
                    frame = { t = 0 },
                    text_to_wrap = 'Keybinds are saved to "' .. initfile .. '" and loaded on startup.\n',
                },
                widgets.Label {
                    frame = { t = 4 },
                    text = 'This will not remove any keybinds set by other init files.',
                    text_pen = COLOR_LIGHTRED,
                },
                widgets.HotkeyLabel {
                    frame = { b = 0, l = 0 },
                    key = 'LEAVESCREEN',
                    label = 'Cancel',
                    auto_width = true,
                    on_activate = function() self:dismiss() end
                },
                widgets.HotkeyLabel {
                    frame = { b = 0, l = 14 },
                    key = 'SELECT',
                    label = 'Save',
                    auto_width = true,
                    on_activate = self:callback('createSave')
                },
                widgets.HotkeyLabel {
                    frame = { b = 0, l = 28 },
                    key = 'CUSTOM_ALT_D',
                    label = 'Delete Saved Keybinds',
                    auto_width = true,
                    on_activate = self:callback('deleteSave')
                },
            }
        }
    })
end

function SaveKeybindsWindow:createSave()
    local file = io.open(initfile, "w")
    if file then
        file:write('# This file is generated by gui/keybinds.\n'
            .. '# To manually remove saved keybinds delete this file, or\n'
            .. '# remove the line pertaining to the keybind you wish to remove\n')

        local list = dfhack.hotkey.listAllKeybinds()
        for _, bind in ipairs(list) do
            local sanitized_command = string.gsub(bind.command, '"', '\\"')
            file:write('keybinding add ' .. bind.spec .. ' "' .. sanitized_command .. '"\n')
        end
        file:close()
    end

    self:dismiss()
end

function SaveKeybindsWindow:deleteSave()
    -- Only remove the file if we can verify it exists
    local file = io.open(initfile, "r")
    if file then
        file:close()
        os.remove(initfile)
    end

    self:dismiss()
end

--
-- KeybindList
--
KeybindList = defclass(KeybindList, widgets.FilteredList)
KeybindList.ATTRS = {
    view_id = 'list',
    frame_style = gui.FRAME_INTERIOR,
    frame = { b = 3 },
}

function KeybindList:init()
    self.list.row_height = 3
    self:refreshData()
end

function KeybindList:deleteKeybind()
    local idx, bind = self:getSelected()

    dfhack.hotkey.removeKeybind(bind.data.spec, true, bind.data.command)
    self:refreshData()
end

function KeybindList:editKeybind()
    local idx, bind = self:getSelected()

    local focus = ''
    local spec = bind.data.spec
    local focus_start = string.find(spec, '@')
    if focus_start then
        focus = string.sub(spec, focus_start + 1)
        spec = string.sub(spec, 1, focus_start - 1)
    end

    self._edit_dialog = EditKeybindWindow {
        hotkey = spec,
        spec_focus = focus,
        command = bind.data.command,
        on_apply = function(spec, focus, command)
            -- Remove old keybind
            dfhack.hotkey.removeKeybind(bind.data.spec, true, bind.data.command)
            local fullspec = spec
            if focus ~= '' then
                fullspec = fullspec .. '@' .. focus
            end
            dfhack.hotkey.addKeybind(fullspec, command)
            self:refreshData()
        end,
    }
    self._edit_dialog:show()
end

function KeybindList:get_list_pen(base_color, selected_color, idx)
    local sel_idx, _ = self:getSelected()
    if sel_idx == idx then
        return selected_color
    else
        return base_color
    end
end

local function concat_tables(to, from)
    for _, val in ipairs(from) do
        table.insert(to, val)
    end
end

local function concat_multiline(to, from)
    for i = 1, 3 do
        concat_tables(to[i], from[i])
    end
end

function KeybindList:make_list_label(bind, idx, longest_command)
    local multiline = { {}, {}, {} }
    concat_multiline(multiline, trash_icon)
    concat_multiline(multiline, inspect_icon)
    concat_multiline(multiline, { { { text = '', width = 1 } }, { { text = '', width = 1 } }, { { text = '', width = 1 } } })

    local spec = bind.spec
    local focus = ''
    local focus_start = string.find(spec, '@')
    if focus_start then
        focus = string.sub(spec, focus_start)
        spec = string.sub(spec, 1, focus_start - 1)
    end
    concat_tables(multiline[2], {
        { text = bind.command, width = longest_command + 2, pen = self:callback('get_list_pen', COLOR_GRAY, COLOR_CYAN, idx) },
        { text = spec,         pen = COLOR_LIGHTGREEN },
        { text = focus,        pen = COLOR_BROWN },
    })

    local out = {}

    for i = 1, 3 do
        concat_tables(out, multiline[i])
        table.insert(out, NEWLINE)
    end
    return out
end

function KeybindList:refreshData()
    local options = {}

    local list = dfhack.hotkey.listAllKeybinds()

    -- Determine longest command, displaying up to 40 characters
    local longest_command = 0
    for _, bind in ipairs(list) do
        if #bind.command > longest_command then
            longest_command = #bind.command
        end
    end
    longest_command = longest_command > 40 and 40 or longest_command

    for _, bind in ipairs(list) do
        table.insert(options, {
            data = bind,
            text = self:make_list_label(bind, #options + 1, longest_command),
            search_key = bind.command .. " " .. bind.spec,
        })
    end

    -- Set choices, persisting filter
    local filter = self:getFilter()
    self:setChoices(options)
    if filter then
        self:setFilter(filter)
    end
end

function KeybindList:onInput(keys)
    if not keys._MOUSE_L then
        return KeybindList.super.onInput(self, keys)
    end

    local idx = self.list:getIdxUnderMouse()
    if not idx then
        return KeybindList.super.onInput(self, keys)
    end

    local x = self:getMousePos()
    if x < 0 or x > 6 then
        return KeybindList.super.onInput(self, keys)
    end

    self.list:setSelected(idx)
    if x <= 3 then
        self:deleteKeybind()
    else
        self:editKeybind()
    end
    return true
end

-- KeybindWindow
KeybindWindow = defclass(KeybindWindow, widgets.Window)
KeybindWindow.ATTRS = {
    frame_title = "Keybinds",
    frame = { w = 100 },
    resizable = true,

    _key_dialog = DEFAULT_NIL,
    _edit_dialog = DEFAULT_NIL,
}

function KeybindWindow:init()
    self:addviews({
        KeybindList {
            frame = { t = 0, b = 4 },
        },
        widgets.HotkeyLabel {
            key = 'CUSTOM_ALT_N',
            label = 'New Keybind',
            on_activate = self:callback('createNewKeybind'),
            auto_width = true,
            frame = { b = 2, l = 0 }
        },
        widgets.HotkeyLabel {
            key = 'CUSTOM_ALT_D',
            label = 'Delete Keybind',
            auto_width = true,
            on_activate = self:callback('deleteKeybind'),
            frame = { b = 2, l = 25 }
        },
        widgets.HotkeyLabel {
            key = 'CUSTOM_ALT_E',
            label = 'Edit Keybind',
            auto_width = true,
            on_activate = self:callback('editKeybind'),
            frame = { b = 1, l = 0 },
        },
        widgets.HotkeyLabel {
            key = 'CUSTOM_ALT_S',
            label = 'Save Keybinds',
            auto_width = true,
            on_activate = self:callback('saveKeybinds'),
            frame = { b = 1, l = 25 }
        }
    })
end

function KeybindWindow:createNewKeybind()
    self._edit_dialog = EditKeybindWindow {
        on_apply = function(spec, focus, command)
            local fullspec = spec
            if focus ~= '' then
                fullspec = fullspec .. '@' .. focus
            end
            dfhack.hotkey.addKeybind(fullspec, command)
            self.subviews.list:refreshData()
        end
    }
    self._edit_dialog:show()
end

function KeybindWindow:deleteKeybind()
    self.subviews.list:deleteKeybind()
end

function KeybindWindow:editKeybind()
    self.subviews.list:editKeybind()
end

function KeybindWindow:saveKeybinds()
    self._save_dialog = SaveKeybindsWindow {}
    self._save_dialog:show()
end

-- KeybindScreen
KeybindScreen = defclass(KeybindScreen, gui.ZScreen)

function KeybindScreen:init()
    self:addviews({
        KeybindWindow {},
    })
end

function KeybindScreen:onDismiss()
    view = nil
end

view = view and view:raise() or KeybindScreen {}:show()
