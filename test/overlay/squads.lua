local gui = require('gui')
local overlay = require('plugins.overlay')

local if_squads = df.global.game.main_interface.squads

config = {
    target = 'squads',
    mode = 'fortress',
}

local was_overlay_enabled = overlay.isEnabled()

local function get_widget()
    overlay.setEnabled(true)
    overlay.rescan()
    overlay.overlay_command({'enable', 'squads.select_all'})
    if not overlay.isOverlayEnabled('squads.select_all') then
        qerror('could not enable squads.select_all overlay')
    end
    return overlay.get_state().db['squads.select_all'].widget
end

local function count_selected()
    local n = 0
    for i = 0, #if_squads.squad_selected - 1 do
        if if_squads.squad_selected[i] then n = n + 1 end
    end
    return n
end

local function feed_keys(keys)
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), keys)
end

local function panel_is_open()
    return dfhack.gui.matchFocusString('dwarfmode/Squads',
        dfhack.gui.getDFViewscreen(true))
end

local function set_panel_open(open)
    if panel_is_open() ~= open then
        feed_keys'D_SQUADS'
    end
end

local function with_squads_panel(test_fn)
    expect.gt(#if_squads.squad_id, 0,
        'test fort must have at least one squad')
    local saved_sel = {}
    for i = 0, #if_squads.squad_selected - 1 do
        saved_sel[i] = if_squads.squad_selected[i]
    end
    local was_open = panel_is_open()
    dfhack.with_finalize(
        function()
            set_panel_open(was_open)
            for i = 0, #saved_sel - 1 do
                if_squads.squad_selected[i] = saved_sel[i]
            end
            overlay.setEnabled(was_overlay_enabled)
        end,
        function()
            set_panel_open(true)
            expect.true_(panel_is_open())
            for i = 0, #if_squads.squad_selected - 1 do
                if_squads.squad_selected[i] = false
            end
            test_fn(get_widget())
        end)
end

function test.select_all_hotkey_selects_all_squads()
    with_squads_panel(function()
        expect.eq(0, count_selected())
        feed_keys{CUSTOM_CTRL_A=true}
        expect.eq(#if_squads.squad_id, count_selected())
    end)
end

function test.select_all_hotkey_deselects_all_squads()
    with_squads_panel(function()
        feed_keys{CUSTOM_CTRL_A=true}
        expect.eq(#if_squads.squad_id, count_selected())
        feed_keys{CUSTOM_CTRL_A=true}
        expect.eq(0, count_selected())
    end)
end

function test.select_all_click_toggles()
    with_squads_panel(function(widget)
        -- compute the widget's frame rect so mouse hit-testing works
        local sw, sh = dfhack.screen.getWindowSize()
        widget:updateLayout(gui.ViewRect{rect=gui.mkdims_wh(0, 0, sw, sh)})
        -- position the mouse inside the widget frame and click
        local rect = widget.frame_rect
        df.global.gps.mouse_x = rect.x1 + (widget.frame_parent_rect and widget.frame_parent_rect.x1 or 0) + 1
        df.global.gps.mouse_y = rect.y1 + (widget.frame_parent_rect and widget.frame_parent_rect.y1 or 0)
        feed_keys{_MOUSE_L=true}
        expect.eq(#if_squads.squad_id, count_selected())
        feed_keys{_MOUSE_L=true}
        expect.eq(0, count_selected())
    end)
end

function test.widget_tracks_external_selection_changes()
    with_squads_panel(function(widget)
        -- the label should reflect selection changes made outside the widget
        local label = widget.subviews.select_all
        widget:onRenderBody()
        expect.eq('Select all', label.label)
        if_squads.squad_selected[0] = true
        widget:onRenderBody()
        expect.eq('Select all', label.label)
        for i = 0, #if_squads.squad_selected - 1 do
            if_squads.squad_selected[i] = true
        end
        widget:onRenderBody()
        expect.eq('Deselect all', label.label)
    end)
end
