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

-- if_squads.open toggles synchronously on D_SQUADS; focus strings for the
-- squads tab only update on the next frame, so they cannot be used here
local function set_panel_open(open)
    if if_squads.open ~= open then
        feed_keys'D_SQUADS'
    end
end

-- the CI test fort may not have any squads; create one on a free squad
-- position (positions with squad_size > 0) so the panel lists something
local function ensure_test_squad()
    local fort = df.historical_entity.find(df.global.plotinfo.group_id)
    if not fort then return end
    local free_aid
    for _, a in ipairs(fort.positions.assignments) do
        if a.squad_id ~= -1 then return end
        if not free_aid then
            for _, p in ipairs(fort.positions.own) do
                if p.id == a.position_id and p.squad_size > 0 then
                    free_aid = a.id
                    break
                end
            end
        end
    end
    if free_aid then
        dfhack.military.makeSquad(free_aid)
    end
end

local function with_squads_panel(test_fn)
    ensure_test_squad()
    local was_open = if_squads.open
    local saved_sel
    dfhack.with_finalize(
        function()
            set_panel_open(was_open)
            if saved_sel then
                for i = 0, #saved_sel - 1 do
                    if i < #if_squads.squad_selected then
                        if_squads.squad_selected[i] = saved_sel[i]
                    end
                end
            end
            overlay.setEnabled(was_overlay_enabled)
        end,
        function()
            -- squad_id/squad_selected are only populated while the panel is open
            set_panel_open(true)
            expect.true_(if_squads.open)
            expect.gt(#if_squads.squad_id, 0,
                'test fort must have at least one squad')
            saved_sel = {}
            for i = 0, #if_squads.squad_selected - 1 do
                saved_sel[i] = if_squads.squad_selected[i]
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

function test.widget_hidden_during_disband_confirmation()
    with_squads_panel(function(widget)
        local getval = require('utils').getval
        expect.false_(if_squads.disband_confirmation)
        expect.true_(getval(widget.visible))
        dfhack.with_finalize(
            function()
                if_squads.disband_confirmation = false
            end,
            function()
                if_squads.disband_confirmation = true
                expect.false_(getval(widget.visible))
                -- hidden widgets must not consume the hotkey
                feed_keys{CUSTOM_CTRL_A=true}
                expect.eq(0, count_selected())
            end)
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
