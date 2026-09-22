local gui = require('gui')
local overlay = require('plugins.overlay')

local view_sheets = df.global.game.main_interface.view_sheets

config = {
    target = 'unit-info-viewer',
    mode = 'fortress',
}

local was_overlay_enabled = overlay.isEnabled()

local function get_widget()
    overlay.setEnabled(true)
    overlay.rescan()
    overlay.overlay_command({'enable', 'gui/unit-info-viewer.mood'})
    if not overlay.isOverlayEnabled('gui/unit-info-viewer.mood') then
        qerror('could not enable gui/unit-info-viewer.mood overlay')
    end
    return overlay.get_state().db['gui/unit-info-viewer.mood'].widget
end

local function sheet_is_open()
    return dfhack.gui.matchFocusString('dwarfmode/ViewSheets/UNIT/Overview',
        dfhack.gui.getDFViewscreen(true))
end

local function get_citizen()
    for _,u in ipairs(df.global.world.units.active) do
        if dfhack.units.isCitizen(u) and u.status.current_soul then
            return u
        end
    end
end

local function open_sheet(unit)
    view_sheets.open = true
    view_sheets.context = df.view_sheets_context_type.REGULAR_PLAY
    view_sheets.active_sheet = df.view_sheet_type.UNIT
    view_sheets.active_id = unit.id
    view_sheets.active_sub_tab = 0
    view_sheets.viewing_unid:insert('#', unit.id)
end

local function close_sheet()
    view_sheets.open = false
    view_sheets.active_id = -1
    view_sheets.active_sheet = df.view_sheet_type.NONE
    view_sheets.viewing_unid:resize(0)
end

local function with_unit_sheet(test_fn)
    local unit = get_citizen()
    expect.true_(unit ~= nil, 'test fort must have at least one citizen')
    local was_open = sheet_is_open()
    local saved = {
        open = view_sheets.open,
        context = view_sheets.context,
        sheet = view_sheets.active_sheet,
        id = view_sheets.active_id,
        sub_tab = view_sheets.active_sub_tab,
    }
    local saved_unids = {}
    for i = 0, #view_sheets.viewing_unid - 1 do
        saved_unids[i] = view_sheets.viewing_unid[i]
    end
    dfhack.with_finalize(
        function()
            view_sheets.viewing_unid:resize(0)
            if was_open then
                view_sheets.open = saved.open
                view_sheets.context = saved.context
                view_sheets.active_sheet = saved.sheet
                view_sheets.active_id = saved.id
                view_sheets.active_sub_tab = saved.sub_tab
                for i = 0, #saved_unids - 1 do
                    view_sheets.viewing_unid:insert('#', saved_unids[i])
                end
            else
                close_sheet()
            end
            overlay.setEnabled(was_overlay_enabled)
        end,
        function()
            open_sheet(unit)
            test_fn(get_widget(), unit)
        end)
end

local function label_text(widget)
    widget:onRenderBody()
    local parts = {}
    for _,tok in ipairs(widget.subviews.mood.text) do
        parts[#parts+1] = type(tok) == 'table' and tok.text or tostring(tok)
    end
    return table.concat(parts)
end

function test.mood_shows_stress_categories()
    with_unit_sheet(function(widget, unit)
        local soul = unit.status.current_soul
        local cur = soul.personality.stress
        local lt = soul.personality.longterm_stress
        local text = label_text(widget)
        expect.true_(text:find('Mood:') ~= nil, 'mood line missing: ' .. text)
        expect.true_(text:find('Long%-term mood:') ~= nil,
            'long-term line missing: ' .. text)
        expect.true_(#text > 0)
    end)
end

function test.mood_reflects_stress_change()
    with_unit_sheet(function(widget, unit)
        local soul = unit.status.current_soul
        local saved = soul.personality.stress
        local function restore()
            soul.personality.stress = saved
        end
        dfhack.with_finalize(restore, function()
            soul.personality.stress = 100000
            local text = label_text(widget)
            expect.true_(text:find('Miserable') ~= nil,
                'expected Miserable at stress=100000: ' .. text)
            soul.personality.stress = -150000
            text = label_text(widget)
            expect.true_(text:find('Ecstatic') ~= nil,
                'expected Ecstatic at stress=-150000: ' .. text)
        end)
    end)
end

function test.mood_hides_for_soulless_unit()
    with_unit_sheet(function(widget, unit)
        local soul = unit.status.current_soul
        local saved = unit.status.current_soul
        dfhack.with_finalize(function()
                unit.status.current_soul = saved
            end, function()
            unit.status.current_soul = nil
            local text = label_text(widget)
            expect.eq('', text, 'expected empty text for soul-less unit')
        end)
    end)
end
