-- building/construction mass removal/suspension tool

local gui = require('gui')
local guidm = require('gui.dwarfmode')
local utils = require('utils')
local widgets = require('gui.widgets')

local function noop()
end

local function get_first_job(bld)
    if not bld then return end
    if #bld.jobs ~= 1 then return end
    return bld.jobs[0]
end

local function process_building(built, planned, remove, bld)
    if (built and bld:getBuildStage() == bld:getMaxBuildStage()) or
        (planned and bld:getBuildStage() ~= bld:getMaxBuildStage())
    then
        if remove then
            dfhack.buildings.deconstruct(bld)
        else
            local job = get_first_job(bld)
            if not job or job.job_type ~= df.job_type.DestroyBuilding then return end
            dfhack.job.removeJob(job)
        end
    end
end

local function process_construction(built, planned, remove, grid, pos, bld)
    if planned and bld then
        process_building(false, true, remove, bld)
    elseif built and not bld then
        if remove then
            dfhack.constructions.designateRemove(pos)
        else
            local tileFlags = dfhack.maps.getTileFlags(pos)
            tileFlags.dig = df.tile_dig_designation.No
            dfhack.maps.getTileBlock(pos).flags.designated = true
            local job = safe_index(grid, pos.z, pos.y, pos.x)
            if job then dfhack.job.removeJob(job) end
        end
    end
end

local function remove_stockpile(bld)
    dfhack.buildings.deconstruct(bld)
end

local function remove_zone(pos)
    for _, bld in ipairs(dfhack.buildings.findCivzonesAt(pos) or {}) do
        dfhack.buildings.deconstruct(bld)
    end
end

--
-- DimsPanel
--

local function get_dims(pos1, pos2)
    local width, height, depth = math.abs(pos1.x - pos2.x) + 1,
            math.abs(pos1.y - pos2.y) + 1,
            math.abs(pos1.z - pos2.z) + 1
    return width, height, depth
end

DimsPanel = defclass(DimsPanel, widgets.ResizingPanel)
DimsPanel.ATTRS{
    get_mark_fn=DEFAULT_NIL,
    autoarrange_subviews=true,
}

function DimsPanel:init()
    self:addviews{
        widgets.WrappedLabel{
            text_to_wrap=self:callback('get_action_text')
        },
    }
end

function DimsPanel:get_action_text()
    local str = self.get_mark_fn() and 'second' or 'first'
    return ('Select the %s corner with the mouse.'):format(str)
end

local function is_something_selected()
    return dfhack.gui.getSelectedBuilding(true) or
        dfhack.gui.getSelectedStockpile(true) or
        dfhack.gui.getSelectedCivZone(true)
end

local function not_is_something_selected()
    return not is_something_selected()
end

--
-- MassRemove
--

MassRemove = defclass(MassRemove, widgets.Window)
MassRemove.ATTRS{
    frame_title='Mass Remove',
    frame={w=47, h=18, r=2, t=18},
    resizable=true,
    resize_min={h=9},
    autoarrange_subviews=true,
    autoarrange_gap=1,
}

function MassRemove:init()
    self:addviews{
        widgets.WrappedLabel{
            view_id='warning',
            text_to_wrap='Please deselect any selected buildings, stockpiles or zones before attempting to remove them.',
            text_pen=COLOR_RED,
            visible=is_something_selected,
        },
        widgets.WrappedLabel{
            text_to_wrap='Designate buildings, constructions, stockpiles, and/or zones for removal.',
            visible=function() return not_is_something_selected() and self.subviews.remove:getOptionValue() end,
        },
        widgets.WrappedLabel{
            text_to_wrap='Designate buildings or constructions to cancel removal.',
            visible=function() return not_is_something_selected() and not self.subviews.remove:getOptionValue() end,
        },
        DimsPanel{
            get_mark_fn=function() return self.mark end,
            visible=not_is_something_selected,
        },
        widgets.CycleHotkeyLabel{
            view_id='buildings',
            label='Buildings:',
            key='CUSTOM_B',
            key_back='CUSTOM_SHIFT_B',
            option_gap=5,
            options={
                {label='Leave alone', value=noop, pen=COLOR_BLUE},
                {label='Affect built and planned', value=curry(process_building, true, true), pen=COLOR_RED},
                {label='Affect built', value=curry(process_building, true, false), pen=COLOR_LIGHTRED},
                {label='Affect planned', value=curry(process_building, false, true), pen=COLOR_YELLOW},
            },
            initial_option=2,
            enabled=not_is_something_selected,
        },
        widgets.CycleHotkeyLabel{
            view_id='constructions',
            label='Constructions:',
            key='CUSTOM_V',
            key_back='CUSTOM_SHIFT_V',
            option_gap=1,
            options={
                {label='Leave alone', value=noop, pen=COLOR_BLUE},
                {label='Affect built and planned', value=curry(process_construction, true, true), pen=COLOR_RED},
                {label='Affect built', value=curry(process_construction, true, false), pen=COLOR_LIGHTRED},
                {label='Affect planned', value=curry(process_construction, false, true), pen=COLOR_YELLOW},
            },
            enabled=not_is_something_selected,
        },
        widgets.CycleHotkeyLabel{
            view_id='stockpiles',
            label='Stockpiles:',
            key='CUSTOM_T',
            key_sep=':  ',
            option_gap=4,
            options={
                {label='Leave alone', value=noop, pen=COLOR_BLUE},
                {label='Remove', value=remove_stockpile, pen=COLOR_RED},
            },
            enabled=not_is_something_selected,
            visible=function() return self.subviews.remove:getOptionValue() end,
        },
        widgets.CycleHotkeyLabel{
            label='Stockpiles:',
            key='CUSTOM_T',
            key_sep=':  ',
            option_gap=4,
            options={{label='Leave alone', value=noop}},
            enabled=false,
            visible=function() return not self.subviews.remove:getOptionValue() end,
        },
        widgets.CycleHotkeyLabel{
            view_id='zones',
            label='Zones:',
            key='CUSTOM_Z',
            key_sep=':  ',
            option_gap=9,
            options={
                {label='Leave alone', value=noop, pen=COLOR_BLUE},
                {label='Remove', value=remove_zone, pen=COLOR_RED},
            },
            enabled=not_is_something_selected,
            visible=function() return self.subviews.remove:getOptionValue() end,
        },
        widgets.CycleHotkeyLabel{
            label='Zones:',
            key='CUSTOM_Z',
            key_sep=':  ',
            option_gap=9,
            options={{label='Leave alone', value=noop}},
            enabled=false,
            visible=function() return not self.subviews.remove:getOptionValue() end,
        },
        widgets.CycleHotkeyLabel{
            view_id='remove',
            label='Mode:',
            key='CUSTOM_R',
            options={
                {label='Remove or schedule for removal', value=true, pen=COLOR_RED},
                {label='Cancel removal', value=false, pen=COLOR_GREEN},
            },
            on_change=function() self:updateLayout() end,
            enabled=not_is_something_selected,
        },
    }

    self:refresh_grid()
end

function MassRemove:refresh_grid()
    local grid = {}
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.RemoveConstruction then
            pos = job.pos
            ensure_key(ensure_key(grid, pos.z), pos.y)[pos.x] = job
        end
    end
    self.grid = grid
end

local function get_bounds(mark, cur)
    cur = cur or dfhack.gui.getMousePos()
    if not cur then return end
    mark = mark or cur

    return {
        x1=math.min(cur.x, mark.x),
        x2=math.max(cur.x, mark.x),
        y1=math.min(cur.y, mark.y),
        y2=math.max(cur.y, mark.y),
        z1=math.min(cur.z, mark.z),
        z2=math.max(cur.z, mark.z),
    }
end

function MassRemove:onInput(keys)
    if MassRemove.super.onInput(self, keys) then return true end

    if keys.LEAVESCREEN or keys._MOUSE_R then
        if self.mark then
            self.mark = nil
            self:updateLayout()
            return true
        end
        return false
    end

    local pos = nil
    if keys._MOUSE_L and not self:getMouseFramePos() then
        pos = dfhack.gui.getMousePos()
    end
    if not pos then return false end

    if is_something_selected() then
        self.mark = nil
        self:updateLayout()
        return true
    end

    if self.mark then
        self:commit(get_bounds(self.mark, pos))
        self.mark = nil
        self:updateLayout()
        self:refresh_grid()
    else
        self.mark = pos
        self:updateLayout()
    end
    return true
end

local to_pen = dfhack.pen.parse
local SELECTION_PEN = to_pen{ch='X', fg=COLOR_GREEN,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 1, 2)}
local DESTROYING_PEN = to_pen{ch='d', fg=COLOR_LIGHTRED,
                       tile=dfhack.screen.findGraphicsTile('CURSORS', 3, 0)}

local function is_construction(pos)
    local tt = dfhack.maps.getTileType(pos)
    if not tt then return false end
    return df.tiletype.attrs[tt].material == df.tiletype_material.CONSTRUCTION
end

local function is_destroying_construction(pos, grid)
    if safe_index(grid, pos.z, pos.y, pos.x) then return true end
    return is_construction(pos) and
        dfhack.maps.getTileFlags(pos).dig == df.tile_dig_designation.Default
end

local function get_job_pen(pos, grid)
    if is_destroying_construction(pos) then
        return DESTROYING_PEN
    end
    local bld = dfhack.buildings.findAtTile(pos)
    local job = get_first_job(bld)
    if not job then return end
    local jt = job.job_type
    if jt == df.job_type.DestroyBuilding
            or jt == df.job_type.RemoveConstruction then
        return DESTROYING_PEN
    end
end

function MassRemove:onRenderFrame(dc, rect)
    MassRemove.super.onRenderFrame(self, dc, rect)

    if not dfhack.screen.inGraphicsMode() and not gui.blink_visible(500) then
        return
    end

    local bounds = get_bounds(self.mark)
    local bounds_rect = gui.ViewRect{rect=bounds}
    self:refresh_grid()

    local function get_overlay_pen(pos)
        local job_pen = get_job_pen(pos)
        if job_pen then return job_pen end
        if bounds and bounds_rect:inClipGlobalXY(pos.x, pos.y) then
            return SELECTION_PEN
        end
    end

    guidm.renderMapOverlay(get_overlay_pen)
end

function MassRemove:commit(bounds)
    local bld_fn = self.subviews.buildings:getOptionValue()
    local constr_fn = self.subviews.constructions:getOptionValue()
    local stockpile_fn = self.subviews.stockpiles:getOptionValue()
    local zones_fn = self.subviews.zones:getOptionValue()
    local remove = self.subviews.remove:getOptionValue()

    self:refresh_grid()

    for z=bounds.z1,bounds.z2 do
        for y=bounds.y1,bounds.y2 do
            for x=bounds.x1,bounds.x2 do
                local pos = xyz2pos(x, y, z)
                local bld = dfhack.buildings.findAtTile(pos)
                if bld then
                    if bld:getType() == df.building_type.Stockpile then
                        stockpile_fn(bld)
                    elseif bld:getType() == df.building_type.Construction then
                        constr_fn(remove, self.grid, pos, bld)
                    else
                        bld_fn(remove, bld)
                    end
                end
                if not dfhack.buildings.findAtTile(pos) and is_construction(pos) then
                    constr_fn(remove, self.grid, pos)
                end
                zones_fn(pos)
            end
        end
    end
end

--
-- MassRemoveScreen
--

MassRemoveScreen = defclass(MassRemoveScreen, gui.ZScreen)
MassRemoveScreen.ATTRS {
    focus_path='mass-remove',
    pass_movement_keys=true,
    pass_mouse_clicks=false,
}

function MassRemoveScreen:init()
    local window = MassRemove{}
    self:addviews{
        window,
        widgets.DimensionsTooltip{
            get_anchor_pos_fn=function() return window.mark end,
        },
    }
end

function MassRemoveScreen:onDismiss()
    view = nil
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

view = view and view:raise() or MassRemoveScreen{}:show()
