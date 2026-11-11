-- gui/setup_editor.lua
local gui     = require('gui')
local widgets = require('gui.widgets')
local dialog  = require('gui.dialogs')

---------------------------
-- Utility
---------------------------

local function getStringValue(val)
    return tostring(val)
end

local function make_editable_list(rows, get_tab_index, flip_tabs)
    local function build_choices()
        local choices = {}
        for _, row in ipairs(rows) do
            local val
            local ok, result = pcall(row.get)
            if ok then val = getStringValue(result) else val = '(error)' end
            table.insert(choices, {
                label = row.label,
                get = row.get,
                set = row.set,
                text = row.label .. ': ' .. val,
            })
        end
        return choices
    end

    local list = widgets.List{
        frame = {t=0, l=0, r=0, b=0},
        choices = build_choices(),
        on_submit = function(idx, choice)
            local current_val = choice.get() or ''
            dialog.showInputPrompt(
                choice.label,
                "Enter new value:",
                COLOR_WHITE,
                tostring(current_val),
                function(new_val)
                    local num = tonumber(new_val)
                    if num ~= nil then
                        choice.set(num)
                        local current_tab = get_tab_index()
                        local other_tab = current_tab == 1 and 2 or 1
                        flip_tabs(other_tab)
                        flip_tabs(current_tab)
                    end
                end
            )
        end
    }

    list.refreshDisplay = function()
        local idx = list:getSelected()
        list:setChoices(build_choices())
        list:setSelected(idx)
    end

    return list
end

---------------------------
-- Variable Wrappers
---------------------------

local function try_points_remaining(screen)
    local ok = pcall(function() return screen.points_remaining end)
    if not ok then return nil end
    return {
        label = 'Embark points',
        get = function() return screen.points_remaining end,
        set = function(v) screen.points_remaining = v end
    }
end

local function try_dwarf_skill_picks(screen, i)
    local ok = pcall(function() return screen.dwarf_info[i].skill_picks_left end)
    if not ok then return nil end
    return {
        label = ('Dwarf %d skill picks'):format(i+1),
        get = function() return screen.dwarf_info[i].skill_picks_left end,
        set = function(v) screen.dwarf_info[i].skill_picks_left = v end
    }
end

local function try_char_skill_picks(screen, i)
    local ok = pcall(function() return screen.csheet[i].skill_picks_left end)
    if not ok then return nil end
    return {
        label = ('Char %d skill picks'):format(i+1),
        get = function() return screen.csheet[i].skill_picks_left end,
        set = function(v) screen.csheet[i].skill_picks_left = v end
    }
end

local function try_char_att_points(screen, i)
    local ok = pcall(function() return screen.csheet[i].att_points end)
    if not ok then return nil end
    return {
        label = ('Char %d attribute pts'):format(i+1),
        get = function() return screen.csheet[i].att_points end,
        set = function(v) screen.csheet[i].att_points = v end
    }
end

local function try_char_ip(screen, i)
    local ok = pcall(function() return screen.csheet[i].ip end)
    if not ok then return nil end
    return {
        label = ('Char %d IP'):format(i+1),
        get = function() return screen.csheet[i].ip end,
        set = function(v) screen.csheet[i].ip = v end
    }
end

local function try_char_eqpet_points(screen, i)
    local ok = pcall(function() return screen.csheet[i].eqpet_points end)
    if not ok then return nil end
    return {
        label = ('Char %d eq/pet pts'):format(i+1),
        get = function() return screen.csheet[i].eqpet_points end,
        set = function(v) screen.csheet[i].eqpet_points = v end
    }
end

---------------------------
-- Page Builders
---------------------------

local function make_fortress_page(screen, get_tab_index, flip_tabs)
    local rows = {}

    local points = try_points_remaining(screen)
    if points then table.insert(rows, points) end

    for i = 0, 6 do
        local row = try_dwarf_skill_picks(screen, i)
        if row then table.insert(rows, row) end
    end

    if #rows == 0 then
        table.insert(rows, {
            label = '(Not on fortress setup screen)',
            get = function() return '' end,
            set = function() end
        })
    end

    return make_editable_list(rows, get_tab_index, flip_tabs)
end

local function make_adventure_page(screen, get_tab_index, flip_tabs)
    local rows = {}

    for i = 0, 1 do
        local funcs = {
            try_char_skill_picks,
            try_char_att_points,
            try_char_ip,
            try_char_eqpet_points,
        }
        for _, f in ipairs(funcs) do
            local row = f(screen, i)
            if row then table.insert(rows, row) end
        end
    end

    if #rows == 0 then
        table.insert(rows, {
            label = '(Not on adventure setup screen)',
            get = function() return '' end,
            set = function() end
        })
    end

    return make_editable_list(rows, get_tab_index, flip_tabs)
end

---------------------------
-- UI Class
---------------------------

TabbedEditor = defclass(TabbedEditor, widgets.Window)
TabbedEditor.ATTRS{
    frame_title = 'Mode Setup Editor',
    frame = {w=80, h=25, r=2, t=2},
    frame_style = gui.FRAME_WINDOW,
    resizable = true,
}

function TabbedEditor:init()
    local ok, vscreen = pcall(dfhack.gui.getCurViewscreen, true)
    local screen = ok and vscreen or {}

    local initial_tab = 1
    if try_points_remaining(screen) then
        initial_tab = 1
    elseif try_char_skill_picks(screen, 0) then
        initial_tab = 2
    end

    local tab_pages = widgets.Pages{
        view_id='pages',
        frame={t=2, l=0, r=0, b=0},
        subviews={},
    }

    local get_tab_index = function()
        return tab_pages:getSelected()
    end

    local flip_tabs = function(to_idx)
        tab_pages:setSelected(to_idx)
        self:refreshCurrentPage()
    end

    self.page_refs = {nil, nil}

    local function ensure_page(tab_idx)
        if not self.page_refs[tab_idx] then
            if tab_idx == 1 then
                self.page_refs[1] = make_fortress_page(screen, get_tab_index, flip_tabs)
            elseif tab_idx == 2 then
                self.page_refs[2] = make_adventure_page(screen, get_tab_index, flip_tabs)
            end
            tab_pages.subviews[tab_idx] = self.page_refs[tab_idx]
            if tab_idx == tab_pages:getSelected() and self.page_refs[tab_idx].refreshDisplay then
                self.page_refs[tab_idx]:refreshDisplay()
            end
        end
    end

    local tab_bar = widgets.TabBar{
        view_id = 'tab_bar',
        frame={t=0, l=0},
        labels={'Fortress', 'Adventure'},
        on_select = function(idx)
            ensure_page(idx)
            tab_pages:setSelected(idx)
            self:refreshCurrentPage()
        end,
        get_cur_page = function()
            return tab_pages:getSelected()
        end,
    }

    self:addviews{
        tab_bar,
        tab_pages,
    }

    ensure_page(1)
    ensure_page(2)
    local other_tab = initial_tab == 1 and 2 or 1
    tab_bar.on_select(other_tab)
    tab_bar.on_select(initial_tab)
end

function TabbedEditor:refreshCurrentPage()
    local idx = self.subviews.pages:getSelected()
    local current_page = self.page_refs[idx]
    if current_page and current_page.refreshDisplay then
        current_page:refreshDisplay()
    end
end

TabbedEditorScreen = defclass(TabbedEditorScreen, gui.ZScreen)
TabbedEditorScreen.ATTRS{
    focus_path = 'setup_editor',
}

function TabbedEditorScreen:init()
    self:addviews{TabbedEditor{}}
end

function TabbedEditorScreen:onDismiss()
    view = nil
end

view = view and view:raise() or TabbedEditorScreen{}:show()
