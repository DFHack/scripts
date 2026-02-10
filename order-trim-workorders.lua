--[====[

order-trim-workorders
=====================

UI tool for managing DFHack order JSON files.

1) Picker
  - Lists only ``.json`` files in ``dfhack-config/orders``
  - Includes a search filter for filenames
  - Selecting a file creates/overwrites a pretty-formatted ``.txt`` copy and
    opens the Trimmer.

2) Trimmer
  - Shows the pretty ``.txt`` as lines
  - Includes a search filter for text content
  - Hides noisy JSON fields by default (display-only)
  - Marking targets *work orders* (top-level objects in the outer JSON array)

Controls
--------

Trimmer:
  - Mouse: click to select a line
  - Toggle mark:
      * Double left-click the same line, OR
      * Enter/Space
  - Hotkeys (Alt required):
      * Alt+A: apply deletions (remove all marked lines)
      * Alt+S: save
      * Alt+R: reload (discard unsaved changes)
      * Alt+H: toggle hide-noise (show all lines)
  - Esc: close (prompts if unsaved changes)

Picker:
  - Type in Search to filter filenames
  - Enter/click: duplicate to pretty .txt and open trimmer
  - Esc: close

Notes:
  - Hidden fields only affect what is displayed. When you mark a work order and
    apply deletions, all lines belonging to that work order are removed from the
    underlying .txt, including lines that were hidden.

]====]

local fs = dfhack.filesystem
local gui = require('gui')
local widgets = require('gui.widgets')
local dialogs = require('gui.dialogs')
local utils = require('utils')

local BASE_PATH = dfhack.getDFPath() .. '/dfhack-config/orders'
local MAX_LINES = 20000

-- Hide these tokens in the Trimmer by default (display-only).
-- We treat them as simple case-insensitive substrings.
local DEFAULT_HIDE_TOKENS = {
    '"amount_left"',
    '"amount_total"',
    '"frequency"',
    '"id"',
    '"is_active"',
    '"is_validated"',
    '"item_conditions"',
    '"condition"',
    '"item_type"',    '"min_dimension"',
    '"value"',
    '"flags"',

    '"empty"',
    '"unrotten"',
    '"cookable"',
    '"solid"',
    '"meal_ingredients"',
    '"food_storage"',
    '"customReaction"',
    '"non_absorbent"',
    '"non_pressed"',
    '"honey"',
    '"millable"',
    '"body_part"',
    '"hair_wool"',

    '"drink_mat"',
    '"milk"',
    '"item_tool_honeycomb"',
    '"honeycomb_press_mat"',
    '"press_liquid_mat"',
    '"soap_mat"',
    '"liquid_container"',
    '"processable"',
    '"bag_item"',
    '"processable_to_barrel"',

    '"reaction_product"',
    '"contains"',
    '"collected"',
    '"dyeable"',
    '"non_economic"',
    '"hard"',
    '"maketool"',

    '"strand"',
    '"dye"',
    '"wax"',
    '"totemable"',
    '"make_soap_from_tallow"',
    '"sand_bearing"',
    '"melt_designated"',
    '"allow_melt_dump"',
    '"bearing"',

    '[',
    ']',
    '{',
    '}',    '},',

    '"id": "Make"',
    '"lye"',
    '"soap"',
    '"material": "INORGANIC"',
}

-- -----------------------------------------------------------------------------
-- Utilities

local function basename(path)
    return (path:match('([^/]+)$') or path)
end

local function is_json_filename(name)
    return name:lower():match('%.json$') ~= nil
end

local function normalize_newlines(s)
    return (s:gsub('\r\n', '\n'):gsub('\r', '\n'))
end

local function slurp(path)
    local f, err = io.open(path, 'rb')
    if not f then
        qerror(('Failed to open file: %s (%s)'):format(path, tostring(err)))
    end
    local data = f:read('*all')
    f:close()
    if data == nil then
        qerror('Failed to read data from: ' .. path)
    end
    return data
end

local function spit(path, data)
    local f, err = io.open(path, 'wb')
    if not f then
        qerror(('Failed to write file: %s (%s)'):format(path, tostring(err)))
    end
    f:write(data)
    f:close()
end

local function list_txt_files(dir)
    local entries = {}
    for _, name in ipairs(fs.listdir(dir) or {}) do
        if name:lower():match('%.txt$') then
            local path = dir .. '/' .. name
            if fs.isfile(path) then
                entries[#entries + 1] = path
            end
        end
    end
    return entries
end

local function snapshot_existing_txt_files(dir)
    local snapshot = {}
    for _, path in ipairs(list_txt_files(dir)) do
        snapshot[path] = slurp(path)
    end
    return snapshot
end

local function remember_txt_file(snapshot, path, data)
    if not snapshot or not path or not path:lower():match('%.txt$') then return end
    snapshot[path] = data or slurp(path)
end

local function restore_missing_txt_files(snapshot)
    local restored = 0
    for path, data in pairs(snapshot or {}) do
        if not fs.isfile(path) then
            spit(path, data)
            restored = restored + 1
        end
    end
    return restored
end

local TXT_PRESERVE_CACHE = snapshot_existing_txt_files(BASE_PATH)

local function txt_variant_path(json_path)
    local dir, name = json_path:match('^(.*)/([^/]+)$')
    dir = dir or BASE_PATH
    name = name or json_path
    local stem = name:gsub('%.json$', ''):gsub('%.JSON$', '')
    return dir .. '/' .. stem .. '.txt'
end

local function json_variant_path(txt_path)
    local dir, name = txt_path:match('^(.*)/([^/]+)$')
    dir = dir or BASE_PATH
    name = name or txt_path
    local stem = name:gsub('%.txt$', ''):gsub('%.TXT$', '')
    return dir .. '/' .. stem .. '.json'
end

local function icontains(haystack, needle)
    if not needle or #needle == 0 then return true end
    if not haystack then return false end
    return haystack:lower():find(needle:lower(), 1, true) ~= nil
end

local function line_is_hidden(line, hide_tokens)
    if not hide_tokens or #hide_tokens == 0 then return false end
    if icontains(line, '"material_category": [') then return false end
    for _, tok in ipairs(hide_tokens) do
        if icontains(line, tok) then
            return true
        end
    end
    return false
end



-- -----------------------------------------------------------------------------
-- Pretty-format JSON (string-aware; best-effort)

local function pretty_json(raw)
    raw = normalize_newlines(raw)
    raw = raw:match('^%s*(.-)%s*$') or raw

    local out = {}
    local indent = 0
    local in_string = false
    local escape = false

    local function push(x) out[#out + 1] = x end
    local function nl()
        push('\n')
        push(string.rep('  ', indent))
    end

    for i = 1, #raw do
        local ch = raw:sub(i, i)

        if in_string then
            push(ch)
            if escape then
                escape = false
            elseif ch == '\\' then
                escape = true
            elseif ch == '"' then
                in_string = false
            end
        else
            if ch == '"' then
                in_string = true
                push(ch)
            elseif ch == '{' or ch == '[' then
                push(ch)
                indent = indent + 1
                nl()
            elseif ch == '}' or ch == ']' then
                indent = math.max(0, indent - 1)
                nl()
                push(ch)
            elseif ch == ',' then
                push(ch)
                nl()
            elseif ch == ':' then
                push(': ')
            elseif ch:match('%s') then
            else
                push(ch)
            end
        end
    end

    push('\n')
    return table.concat(out)
end

-- -----------------------------------------------------------------------------
-- Line model

local function split_lines(text, max_lines)
    text = normalize_newlines(text)

    local lines = {}
    if #text == 0 then return lines end

    max_lines = max_lines or MAX_LINES
    local n = 0

    for line in (text .. '\n'):gmatch('(.-)\n') do
        n = n + 1
        if n > max_lines then
            lines[#lines + 1] = ('[... truncated after %d lines ...]'):format(max_lines)
            break
        end
        lines[#lines + 1] = line
    end

    return lines
end

local function join_lines(lines)
    return table.concat(lines, '\n')
end

-- -----------------------------------------------------------------------------
-- Work order span detection

local function compute_curly_depth(lines)
    local depth_before, opens, closes = {}, {}, {}

    local depth = 0
    local in_string = false
    local escape = false

    for i, line in ipairs(lines) do
        depth_before[i] = depth
        local o, c = 0, 0

        for ch in line:gmatch('.') do
            if in_string then
                if escape then
                    escape = false
                elseif ch == '\\' then
                    escape = true
                elseif ch == '"' then
                    in_string = false
                end
            else
                if ch == '"' then
                    in_string = true
                elseif ch == '{' then
                    o = o + 1
                    depth = depth + 1
                elseif ch == '}' then
                    c = c + 1
                    depth = math.max(0, depth - 1)
                end
            end
        end

        opens[i] = o
        closes[i] = c
    end

    return depth_before, opens, closes
end

local function enclosing_work_order_span(lines, idx)
    if idx < 1 or idx > #lines then return idx, idx end

    local depth_before, opens, closes = compute_curly_depth(lines)

    local start_line
    for i = idx, 1, -1 do
        if depth_before[i] == 0 and (opens[i] or 0) > 0 then
            start_line = i
            break
        end
    end

    if not start_line then
        return idx, idx
    end

    local depth = 0
    local end_line
    for i = start_line, #lines do
        depth = depth + (opens[i] or 0) - (closes[i] or 0)
        if i > start_line and depth == 0 then
            end_line = i
            break
        end
    end

    if not end_line then
        return start_line, idx
    end

    return start_line, end_line
end

local function compute_work_order_groups(lines)
    local depth_before, opens, closes = compute_curly_depth(lines)
    local groups = {}
    local group_id = 0
    local active = false
    local depth = 0

    for i = 1, #lines do
        if depth_before[i] == 0 and (opens[i] or 0) > 0 then
            group_id = group_id + 1
            active = true
        end

        if active then
            groups[i] = group_id
        end

        depth = depth + (opens[i] or 0) - (closes[i] or 0)
        if active and depth == 0 then
            active = false
        end
    end

    return groups
end

-- -----------------------------------------------------------------------------
-- Trimmer UI

TrimmerWindow = defclass(TrimmerWindow, widgets.Window)
TrimmerWindow.ATTRS{
    path = DEFAULT_NIL,
    frame_title = 'TXT Trimmer',
    frame = {w = 104, h = 34},
    resizable = true,
    resize_min = {w = 72, h = 18},
}

function TrimmerWindow:init()
    if not self.path or #tostring(self.path) == 0 then
        qerror('TrimmerWindow requires a path')
    end

    self.lines = {}
    self.filtered = {}
    self.marked = {}
    self.dirty = false
    self._last_click_row = nil

    self.hide_noise = true
    self.hide_tokens = DEFAULT_HIDE_TOKENS

    self:addviews{
        widgets.Label{
            view_id = 'help',
            frame = {t = 0, l = 0, r = 0, h = 4},
            text = {},
        },
        widgets.EditField{
            view_id = 'filter',
            frame = {t = 4, l = 0, r = 0, h = 1},
            label_text = 'Search: ',
            on_change = function() self:_refresh_ui(1) end,
        },
        widgets.Label{
            view_id = 'status',
            frame = {t = 5, l = 0, r = 0, h = 1},
            text = 'Marked: 0    Lines: 0    Showing: 0',
            text_pen = COLOR_GREY,
        },
        widgets.List{
            view_id = 'list',
            frame = {t = 7, l = 0, r = 0, b = 0},
            choices = {},
        },
    }

    self:reload_from_disk(true)
end

function TrimmerWindow:_set_title()
    local star = self.dirty and '*' or ''
    self.frame_title = ('TXT: %s%s'):format(basename(self.path), star)
end

function TrimmerWindow:_update_help()
    local hide_txt = self.hide_noise and 'ON' or 'OFF'
    self.subviews.help:setText({
        {text = self.path, pen = COLOR_GREY},
        NEWLINE,
        {text = 'Marking toggles an entire work order { ... } (top-level object). Hidden lines still get deleted with the work order.', pen = COLOR_GREY},
        NEWLINE,
        {text = ('Hotkeys: Alt+D Delete  Alt+S save  Alt+R reload  Alt+H hide-noise(%s)  |  Enter/Space or double-click: toggle  |  Esc: close'):format(hide_txt), pen = COLOR_CYAN},
        NEWLINE,
    })
end

function TrimmerWindow:_count_marked()
    local n = 0
    for _, v in pairs(self.marked) do
        if v then n = n + 1 end
    end
    return n
end

function TrimmerWindow:_build_filtered_indices()
    self.filtered = {}
    local q = self.subviews.filter.text or ''
    local groups = compute_work_order_groups(self.lines)

    if #q == 0 then
        for i, line in ipairs(self.lines) do
            if self.hide_noise and line_is_hidden(line, self.hide_tokens) then
            elseif icontains(line, q) then
                self.filtered[#self.filtered + 1] = i
            end
        end
        return
    end

    local matched_groups = {}
    for i, line in ipairs(self.lines) do
        if not (self.hide_noise and line_is_hidden(line, self.hide_tokens)) and icontains(line, q) then
            local group_id = groups[i]
            if group_id then
                matched_groups[group_id] = true
            end
        end
    end

    for i, line in ipairs(self.lines) do
        if not (self.hide_noise and line_is_hidden(line, self.hide_tokens)) then
            local group_id = groups[i]
            if (group_id and matched_groups[group_id]) or (not group_id and icontains(line, q)) then
                self.filtered[#self.filtered + 1] = i
            end
        end
    end
end

function TrimmerWindow:_refresh_ui(keep_row)
    self:_build_filtered_indices()
    local groups = compute_work_order_groups(self.lines)

    local choices = {}
    local displayed_group_color = {}
    local display_group_index = 0
    for _, idx in ipairs(self.filtered) do
        local mark = self.marked[idx] and '{X}' or '{ }'
        local group_id = groups[idx]
        local pen
        if group_id then
            if not displayed_group_color[group_id] then
                display_group_index = display_group_index + 1
                displayed_group_color[group_id] =
                    (display_group_index % 2 == 0) and COLOR_WHITE or COLOR_LIGHTCYAN
            end
            pen = displayed_group_color[group_id]
        end
        local line_text = ('%s %5d: %s'):format(mark, idx, self.lines[idx])
        local text = pen and {{text = line_text, pen = pen}} or line_text
        choices[#choices + 1] = {text = text}
    end

    if #choices == 0 then
        choices[#choices + 1] = {text = '{ }  (no matches)'}
    end

    local list = self.subviews.list
    list:setChoices(choices)

    local row = keep_row or list:getSelected() or 1
    row = math.max(1, math.min(row, #choices))
    list:setSelected(row)

    self.subviews.status:setText(
        ('Marked: %d    Lines: %d    Showing: %d'):format(self:_count_marked(), #self.lines, #self.filtered)
    )

    self:_update_help()
    self:_set_title()
end

function TrimmerWindow:reload_from_disk(silent)
    self.lines = split_lines(slurp(self.path), MAX_LINES)
    self.marked = {}
    self.dirty = false
    self._last_click_row = nil
    self.subviews.filter:setText('')
    self:_refresh_ui(1)
    if not silent then
        dialogs.showMessage('order-trim-workorders', 'Reloaded.', COLOR_LIGHTGREEN)
    end
end

function TrimmerWindow:save_to_disk()
    local data = join_lines(self.lines)
    spit(self.path, data)
    remember_txt_file(TXT_PRESERVE_CACHE, self.path, data)

    local json_path = json_variant_path(self.path)
    spit(json_path, data)

    self.dirty = false
    self:_refresh_ui(self.subviews.list:getSelected())
    dialogs.showMessage(
        'order-trim-workorders',
        ('Saved to\n%s\nand\n%s'):format(self.path, json_path),
        COLOR_LIGHTGREEN)
end

function TrimmerWindow:_toggle_span(start_line, end_line)
    if #self.lines == 0 then return end

    start_line = math.max(1, math.min(start_line, #self.lines))
    end_line = math.max(1, math.min(end_line, #self.lines))
    if end_line < start_line then start_line, end_line = end_line, start_line end

    local cur_row = self.subviews.list:getSelected() or 1

    local new_state = not self.marked[start_line]
    for i = start_line, end_line do
        self.marked[i] = new_state
    end

    self.dirty = true
    self:_refresh_ui(cur_row)
end

function TrimmerWindow:_selected_line_index()
    if #self.filtered == 0 then return nil end

    local row = self.subviews.list:getSelected() or 1
    row = math.max(1, math.min(row, #self.filtered))

    return self.filtered[row]
end

function TrimmerWindow:toggle_selected_work_order()
    local idx = self:_selected_line_index()
    if not idx then return end

    local s, e = enclosing_work_order_span(self.lines, idx)
    self:_toggle_span(s, e)
end

function TrimmerWindow:apply_deletions()
    local marked_count = self:_count_marked()
    if marked_count == 0 then
        dialogs.showMessage('order-trim-workorders', 'No lines are marked for deletion.', COLOR_GREY)
        return
    end

    local cur_row = self.subviews.list:getSelected() or 1

    dialogs.showYesNoPrompt(
        'Apply deletions',
        ('Remove %d marked line(s)?'):format(marked_count),
        nil,
        function()
            local new_lines = {}
            local removed = 0
            for i, line in ipairs(self.lines) do
                if self.marked[i] then
                    removed = removed + 1
                else
                    new_lines[#new_lines + 1] = line
                end
            end

            self.lines = new_lines
            self.marked = {}
            self.dirty = true
            self._last_click_row = nil

            self:_refresh_ui(cur_row)
            dialogs.showMessage('order-trim-workorders', ('Removed %d line(s).'):format(removed), COLOR_LIGHTGREEN)
        end)
end

function TrimmerWindow:toggle_hide_noise()
    local cur_row = self.subviews.list:getSelected() or 1
    self.hide_noise = not self.hide_noise
    self:_refresh_ui(cur_row)
end

function TrimmerWindow:onInput(keys)
    if keys._MOUSE_L then
        local list = self.subviews.list
        local before = list:getSelected() or 1

        local handled = TrimmerWindow.super.onInput(self, keys)

        local after = list:getSelected() or 1
        if after == before and self._last_click_row == after then
            self:toggle_selected_work_order()
            self._last_click_row = nil
        else
            self._last_click_row = after
        end

        return handled or true
    end

    if keys.SELECT or keys.SEC_SELECT then
        self:toggle_selected_work_order()
        return true
    end

    if keys.CUSTOM_ALT_D then
        self:apply_deletions()
        return true
    end

    if keys.CUSTOM_ALT_S then
        if not self.dirty then
            dialogs.showMessage('order-trim-workorders', 'No changes to save.', COLOR_GREY)
            return true
        end
        self:save_to_disk()
        return true
    end

    if keys.CUSTOM_ALT_R then
        if self.dirty then
            dialogs.showYesNoPrompt(
                'order-trim-workorders',
                'Reload from disk and discard unsaved changes?',
                nil,
                function() self:reload_from_disk(false) end)
            return true
        end
        self:reload_from_disk(false)
        return true
    end

    if keys.CUSTOM_ALT_H then
        self:toggle_hide_noise()
        return true
    end

    return TrimmerWindow.super.onInput(self, keys)
end

TrimmerScreen = defclass(TrimmerScreen, gui.ZScreen)
TrimmerScreen.ATTRS{
    focus_path = 'order-trim-workorders/trimmer',
    path = DEFAULT_NIL,
}

function TrimmerScreen:init()
    self:addviews{TrimmerWindow{path = self.path}}
end

function TrimmerScreen:onInput(keys)
    if keys.LEAVESCREEN or keys._MOUSE_R then
        local window = self.subviews[1]
        if window and window.dirty then
            dialogs.showYesNoPrompt(
                'order-trim-workorders',
                'You have unsaved changes. Close anyway?',
                nil,
                function() self:dismiss() end)
            return true
        end
        self:dismiss()
        return true
    end
    return TrimmerScreen.super.onInput(self, keys)
end

local function open_trimmer(path)
    if fs.isfile(path) then
        TrimmerScreen{path = path}:show()
    end
end

-- -----------------------------------------------------------------------------
-- Picker UI (filename search)

local function list_json_files()
    if not fs.isdir(BASE_PATH) then
        qerror('Orders directory not found: ' .. BASE_PATH)
    end

    local entries = {}
    for _, name in ipairs(fs.listdir(BASE_PATH) or {}) do
        if is_json_filename(name) then
            local path = BASE_PATH .. '/' .. name
            if fs.isfile(path) then
                entries[#entries + 1] = {text = name, path = path}
            end
        end
    end

    table.sort(entries, function(a, b) return a.text:lower() < b.text:lower() end)
    return entries
end

local function duplicate_json_to_pretty_txt(json_path, quiet, open_after)
    if not fs.isdir(BASE_PATH) then
        qerror('Orders directory not found: ' .. BASE_PATH)
    end
    if not fs.isfile(json_path) then
        qerror('Source file not found: ' .. json_path)
    end

    local dst = txt_variant_path(json_path)

    local function write_copy()
        local pretty = pretty_json(slurp(json_path))
        spit(dst, pretty)
        remember_txt_file(TXT_PRESERVE_CACHE, dst, pretty)
        print('Duplicated ' .. json_path .. ' -> ' .. dst)
        if open_after then
            open_trimmer(dst)
        end
    end

    if fs.isfile(dst) and not quiet then
        dialogs.showYesNoPrompt(
            'order-trim-workorders',
            ('Destination already exists:\n%s\n\nOverwrite?'):format(dst),
            nil,
            write_copy)
        return
    end

    write_copy()
end

PickerWindow = defclass(PickerWindow, widgets.Window)
PickerWindow.ATTRS{
    frame_title = 'Order Trim Workorders',
    frame = {w = 64, h = 27},
    resizable = true,
    resize_min = {w = 50, h = 18},
}

function PickerWindow:init()
    self.all_files = list_json_files()

    self:addviews{
        widgets.Label{
            frame = {t = 0, l = 0, r = 0, h = 2},
            text = {
                {text = 'Pick an order JSON file (filtered).', pen = COLOR_CYAN},
                NEWLINE,
                {text = 'Search filters filenames. Enter/click opens the trimmer. Esc closes.', pen = COLOR_GREY},
            },
        },
        widgets.EditField{
            view_id = 'filter',
            frame = {t = 2, l = 0, r = 0, h = 1},
            label_text = 'Search: ',
            on_change = function() self:_refresh_list(1) end,
        },
        widgets.List{
            view_id = 'files',
            frame = {t = 4, l = 0, r = 0, b = 1},
            choices = {},
            on_submit = function(_, choice)
                if not choice or not choice.path then return end
                duplicate_json_to_pretty_txt(choice.path, false, true)
            end,
        },
        widgets.Label{
            frame = {b = 0, l = 0, r = 0, h = 1},
            text = {{text = ('Folder: %s'):format(BASE_PATH), pen = COLOR_GREY}},
        },
    }

    self:_refresh_list(1)
end

function PickerWindow:_refresh_list(keep_row)
    local q = self.subviews.filter.text or ''

    local choices = {}
    for _, entry in ipairs(self.all_files) do
        if icontains(entry.text, q) then
            choices[#choices + 1] = entry
        end
    end

    if #choices == 0 then
        choices[#choices + 1] = {text = '(no matches)', path = nil}
    end

    local list = self.subviews.files
    list:setChoices(choices)

    local row = keep_row or list:getSelected() or 1
    row = math.max(1, math.min(row, #choices))
    list:setSelected(row)
end


PickerScreen = defclass(PickerScreen, gui.ZScreen)
PickerScreen.ATTRS{
    focus_path = 'order-trim-workorders/picker',
}

function PickerScreen:init()
    self:addviews{PickerWindow{}}
end

function PickerScreen:onInput(keys)
    if keys.LEAVESCREEN or keys._MOUSE_R then
        self:dismiss()
        return true
    end
    return PickerScreen.super.onInput(self, keys)
end

function PickerScreen:onDismiss()
    local restored = restore_missing_txt_files(TXT_PRESERVE_CACHE)
    if restored > 0 then
        dialogs.showMessage(
            'order-trim-workorders',
            ('Restored %d missing .txt file(s) in orders folder.'):format(restored),
            COLOR_YELLOW)
    end
end

-- -----------------------------------------------------------------------------
-- CLI

local validArgs = {help = false, file = true}
local args = utils.processArgs({...}, validArgs)

if args.help then
    print(dfhack.script_help())
    return
end

if args.file then
    local src = args.file
    if not src:find('/') then
        src = BASE_PATH .. '/' .. src
    end
    if not is_json_filename(basename(src)) then
        qerror('Only .json files are supported: ' .. tostring(args.file))
    end
    duplicate_json_to_pretty_txt(src, true, false)
    return
end

PickerScreen{}:show()
