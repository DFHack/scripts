-- Interface for spawning liquids on tiles.

local liquids = reqscript('modtools/spawn-liquid')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

local SpawnLiquidMode = {
    SET = 1,
    ADD = 2,
    REMOVE = 3,
    CLEAN = 4,
}

local SpawnLiquidPaintMode = {
    DRAG = 1,
    CLICK = 2,
    AREA = 3,
}

local SpawnLiquidPaintShape = {
    SQUARE = 1,
    ROUND = 2,
}

local SpawnLiquidCursor = {
    [df.tile_liquid.Water] = dfhack.screen.findGraphicsTile('MINING_INDICATORS', 0, 0),
    [df.tile_liquid.Magma] = dfhack.screen.findGraphicsTile('MINING_INDICATORS', 1, 0),
    [df.tiletype.RiverSource] = dfhack.screen.findGraphicsTile('LIQUIDS', 0, 0),
}

SpawnLiquid = defclass(SpawnLiquid, widgets.Window)
SpawnLiquid.ATTRS {
    frame_title='Spawn liquid menu',
    frame={b = 4, r = 4, w = 50, h = 12},
}


function SpawnLiquid:preUpdateLayout()
    local level_change_position = 1
    local brush_mode_position = 2

    if self:useBrushSize() then
        level_change_position = level_change_position + 1
        brush_mode_position = brush_mode_position + 1
    end

    for k, v in pairs(self.subviews) do
        if type(k) == "string" then
            if k:startswith("level_increase") or k:startswith("level_decrease") then
                v.frame.b = level_change_position
            elseif k:startswith("brush") then
                v.frame.b = brush_mode_position
            end
        end
    end
end


function SpawnLiquid:init()
    self.type = df.tile_liquid.Water
    self.mode = SpawnLiquidMode.SET
    self.level = 3
    self.paint_mode = SpawnLiquidPaintMode.DRAG
    self.paint_shape = SpawnLiquidPaintShape.SQUARE
    self.brush_radius = 0
    self.tile = SpawnLiquidCursor[self.type]

    self:addviews{
        widgets.Label{
            frame = {l = 0, t = 0},
            text = {{ text = self:callback('getLabel') }}
        },
        widgets.HotkeyLabel{
            view_id = "level_decrease",
            frame = {l = 0, b = 1},
            label = 'Decrease level',
            auto_width = true,
            key = 'KEYBOARD_CURSOR_LEFT',
            on_activate = self:callback('decreaseLiquidLevel'),
            disabled = function() return self.level == 1 end
        },
        widgets.Label{
            view_id = "level_decrease_glyph",
            frame = { l = 0, b = 1, w = 1},
            text_pen=COLOR_LIGHTGREEN,
            text=string.char(27),
        },
        widgets.HotkeyLabel{
            view_id = "level_increase",
            frame = { l = 19, b = 1},
            label = 'Increase level',
            auto_width = true,
            key = 'KEYBOARD_CURSOR_RIGHT',
            on_activate = self:callback('increaseLiquidLevel'),
            disabled = function() return self.level == 7 end
        },
        widgets.Label{
            view_id = "level_increase_glyph",
            frame = { l = 19, b = 1, w = 1},
            text_pen=COLOR_LIGHTGREEN,
            text=string.char(26),
        },
        widgets.HotkeyLabel{
            frame = {l = 0, b = 1},
            label = 'Decrease radius',
            auto_width = true,
            key = 'KEYBOARD_CURSOR_DOWN',
            on_activate = self:callback('decreaseBrushSize'),
            visible = self:callback("useBrushSize"),
            disabled = function() return self.brush_radius <= 0 end
        },
        widgets.Label{
            frame = { l = 0, b = 1, w = 1},
            text_pen=COLOR_LIGHTGREEN,
            text=string.char(25),
            visible = self:callback("useBrushSize"),
        },
        widgets.HotkeyLabel{
            frame = { l = 19, b = 1},
            label = 'Increase radius',
            auto_width = true,
            key = 'KEYBOARD_CURSOR_UP',
            on_activate = self:callback('increaseBrushSize'),
            visible = self:callback("useBrushSize"),
            disabled = function() return self.brush_radius >= 10 end
        },
        widgets.Label{
            frame = { l = 19, b = 1, w = 1},
            text_pen=COLOR_LIGHTGREEN,
            text=string.char(24),
            visible = self:callback("useBrushSize"),
        },
        widgets.CycleHotkeyLabel{
            view_id = "brush",
            frame = {l = 0, b = 3},
            label = 'Brush:',
            auto_width = true,
            key = 'CUSTOM_Q',
            options = {
                { label = "Water", value = df.tile_liquid.Water, pen = COLOR_CYAN },
                { label = "Magma", value = df.tile_liquid.Magma, pen = COLOR_RED },
                { label = "River", value = df.tiletype.RiverSource, pen = COLOR_BLUE },
            },
            initial_option = df.tile_liquid.Water,
            on_change = function(new, _)
                self.type = new
                self.tile = SpawnLiquidCursor[new]
            end,
        },
        widgets.CycleHotkeyLabel{
            frame = {l = 0, b = 0},
            label = 'Paint mode:',
            auto_width = true,
            key = 'CUSTOM_Z',
            options = {
                { label = "Area ", value = SpawnLiquidPaintMode.AREA, pen = COLOR_WHITE },
                { label = "Click", value = SpawnLiquidPaintMode.CLICK, pen = COLOR_WHITE },
                { label = "Drag ", value = SpawnLiquidPaintMode.DRAG, pen = COLOR_WHITE },
            },
            initial_option = SpawnLiquidPaintMode.DRAG,
            on_change = function(new, _)
                self.paint_mode = new
                self:updateLayout()
            end,
        },
        widgets.CycleHotkeyLabel{
            frame = {l = 21, b = 0},
            label = 'Paint Shape:',
            auto_width = true,
            key = 'CUSTOM_V',
            options = {
                { label = "Square", value = SpawnLiquidPaintShape.SQUARE, pen = COLOR_WHITE },
                { label = "Round", value = SpawnLiquidPaintShape.ROUND, pen = COLOR_WHITE },
            },
            initial_option = SpawnLiquidPaintMode.SQUARE,
            visible = self:callback("useBrushSize"),
            on_change = function(new, _)
                self.paint_shape = new
                self:updateLayout()
            end,
        },
        widgets.CycleHotkeyLabel{
            view_id = 'brush_mode1',
            frame = {l = 18, b = 3},
            label = 'Mode:',
            auto_width = true,
            key = 'CUSTOM_X',
            options = {
                { label = "Set   ", value = SpawnLiquidMode.SET, pen = COLOR_WHITE },
                { label = "Add   ", value = SpawnLiquidMode.ADD, pen = COLOR_WHITE },
                { label = "Remove", value = SpawnLiquidMode.REMOVE, pen = COLOR_WHITE },
                { label = "Clean ", value = SpawnLiquidMode.CLEAN, pen = COLOR_WHITE },
            },
            initial_option = SpawnLiquidMode.SET,
            on_change = function(new, _)
                self.mode = new
                self.subviews.brush_mode2:setOption(new)
            end,
            visible = function() return self.type ~= df.tiletype.RiverSource end
        },
        widgets.CycleHotkeyLabel{
            view_id = 'brush_mode2',
            frame = {l = 18, b = 3},
            label = 'Mode:',
            auto_width = true,
            key = 'CUSTOM_X',
            options = {
                { label = "Set   ", value = SpawnLiquidMode.SET, pen = COLOR_WHITE },
                { label = "Remove", value = SpawnLiquidMode.REMOVE, pen = COLOR_WHITE },
            },
            on_change = function(new, _)
                self.mode = new
                self.subviews.brush_mode1:setOption(new)
            end,
            visible = function() return self.type == df.tiletype.RiverSource end
        },
    }
end

-- TODO: More reactive label dependant on options selected.
function SpawnLiquid:getLabel()
    local tile_string = "a tile"
    local liquid_string

    if self.type == 0 then
        liquid_string = "Water"
    elseif self.type == 1 then
        liquid_string = "Magma"
    else
        liquid_string = "River"
    end

    if self:useBrushSize() and self.brush_radius > 0 then
        local brush_size = self.brush_radius*2
        tile_string = string.format("%dx%d tiles", brush_size, brush_size)
    end


    return ([[Click to spawn %s with %s/7 %s]]):format(
        tile_string,
        self.level,
        liquid_string
    )
end

function SpawnLiquid:getLiquidLevel(position)
    local tile = dfhack.maps.getTileFlags(position)

    if self.mode == SpawnLiquidMode.ADD then
        return math.max(0, math.min(tile.flow_size + self.level, 7))
    elseif self.mode == SpawnLiquidMode.REMOVE then
        return math.max(0, math.min(tile.flow_size - self.level, 7))
    end

    return self.level
end

function SpawnLiquid:increaseLiquidLevel()
    self.level = math.min(self.level + 1, 7)
end

function SpawnLiquid:decreaseLiquidLevel()
    self.level = math.max(self.level - 1, 1)
end

function SpawnLiquid:increaseBrushSize()
    self.brush_radius = math.min(self.brush_radius + 1, 10)
end

function SpawnLiquid:decreaseBrushSize()
    self.brush_radius = math.max(self.brush_radius - 1, 0)
end


local function isFlowPassable(pos)
    local tt = dfhack.maps.getTileType(pos)
    local tile = dfhack.maps.getTileFlags(pos)
    return tt and tile and df.tiletype_shape.attrs[df.tiletype.attrs[tt].shape].passable_flow
end

function SpawnLiquid:spawn(pos)
    if not dfhack.maps.isValidTilePos(pos) or not dfhack.maps.isTileVisible(pos) or not isFlowPassable(pos) then
        return
    end

    local map_block = dfhack.maps.getTileBlock(pos)

    if self.mode == SpawnLiquidMode.CLEAN then
        local tile = dfhack.maps.getTileFlags(pos)

        tile.water_salt = false
        tile.water_stagnant = false
    elseif self.type == df.tiletype.RiverSource then
        if self.mode == SpawnLiquidMode.REMOVE then
            local commands = {
                'f', 'any', ';',
                'f', 'sp', 'river_source', ';',
                'p', 'any', ';',
                'p', 's', 'floor', ';',
                'p', 'sp', 'normal', ';',
                'p', 'm', 'stone', ';',
            }
            dfhack.run_command('tiletypes-command', table.unpack(commands))
            dfhack.run_command('tiletypes-here', '--quiet', ('--cursor=%d,%d,%d'):format(pos2xyz(pos)))
            liquids.spawnLiquid(pos, 0, df.tile_liquid.Water)
        else
            map_block.tiletype[pos.x % 16][pos.y % 16] = df.tiletype.RiverSource
            liquids.spawnLiquid(pos, 7, df.tile_liquid.Water)
        end
    else
        liquids.spawnLiquid(pos, self:getLiquidLevel(pos), self.type)
    end
end

function SpawnLiquid:paintLiquid(pos, bounds)
    if not bounds then
        local start_position, end_position = self:getBrushSizeBounds(pos)

        bounds = self:getBounds(start_position, end_position)
    end

    for x = bounds.x1, bounds.x2 do
        for y = bounds.y1, bounds.y2 do
            if self:inBounds(pos, {x=x, y=y}) then
                self:spawn({x=x, y=y, z=pos.z})
            end
        end
    end
end


function SpawnLiquid:getPen()
    return self.type == df.tile_liquid.Water and COLOR_BLUE or COLOR_RED, "X", self.tile
end

function SpawnLiquid:inBounds(mouse_pos, pos)
    if not self:useBrushSize() or self.paint_shape ~= SpawnLiquidPaintShape.ROUND then
        return true
    end

    local diff = {
        x=mouse_pos.x - pos.x,
        y=mouse_pos.y - pos.y
    }
    local dist = diff.x*diff.x+diff.y*diff.y

    return dist <= self.brush_radius*self.brush_radius
end


function SpawnLiquid:getBrushSizeBounds(mouse_pos)
    local start_position = xyz2pos(
            mouse_pos.x - self.brush_radius,
            mouse_pos.y - self.brush_radius,
            mouse_pos.z)

    local end_position = xyz2pos(
            mouse_pos.x + self.brush_radius,
            mouse_pos.y + self.brush_radius,
            mouse_pos.z)

    return start_position, end_position
end


function SpawnLiquid:useBrushSize()
    return self.paint_mode ~= SpawnLiquidPaintMode.AREA
end

function SpawnLiquid:getBounds(start_position, end_position)
    return {
        x1=math.min(start_position.x, end_position.x),
        x2=math.max(start_position.x, end_position.x),
        y1=math.min(start_position.y, end_position.y),
        y2=math.max(start_position.y, end_position.y),
        z1=math.min(start_position.z, end_position.z),
        z2=math.max(start_position.z, end_position.z),
    }
end

function SpawnLiquid:onRenderFrame(dc, rect)
    SpawnLiquid.super.onRenderFrame(self, dc, rect)

    if self.is_dragging and df.global.enabler.mouse_lbut_down == 0 then
        self.is_dragging = false
    end

    local mouse_pos = dfhack.gui.getMousePos()

    if not mouse_pos then
        return
    end

    local start_position = copyall(mouse_pos)
    local end_position = copyall(mouse_pos)

    if self.is_dragging_area then
        start_position = self.area_first_pos or mouse_pos
    end

    if self:useBrushSize() then
        start_position, end_position = self:getBrushSizeBounds(mouse_pos)
    end

    local bounds = self:getBounds(start_position, end_position)

    if self.is_dragging and not self:getMouseFramePos() then
        self:paintLiquid(mouse_pos, bounds)
    end

    guidm.renderMapOverlay(function(pos, _)
        if self:inBounds(mouse_pos, pos) then
            return self:getPen()
        end
    end, bounds)
end

function SpawnLiquid:onInput(keys)
    if SpawnLiquid.super.onInput(self, keys) then return true end

    if keys._MOUSE_L and not self:getMouseFramePos() then
        local mouse_pos = dfhack.gui.getMousePos()

        if self.paint_mode == SpawnLiquidPaintMode.CLICK and mouse_pos then
            self:paintLiquid(mouse_pos)
            return true
        elseif self.paint_mode == SpawnLiquidPaintMode.AREA and mouse_pos then
            if self.is_dragging_area then
                local bounds = self:getBounds(self.area_first_pos, mouse_pos)
                for y = bounds.y1, bounds.y2 do
                    for x = bounds.x1, bounds.x2 do
                        for z = bounds.z1, bounds.z2 do
                            self:spawn(xyz2pos(x, y, z))
                        end
                    end
                end
                self.is_dragging_area = false
                return true
            else
                self.is_dragging_area = true
                self.area_first_pos = mouse_pos
                return true
            end
        elseif self.paint_mode == SpawnLiquidPaintMode.DRAG then
            self.is_dragging = true
            return true
        end
    end

    -- TODO: Holding the mouse down causes event spam.
    if keys._MOUSE_L_DOWN and not self:getMouseFramePos() then
        if self.paint_mode == SpawnLiquidPaintMode.DRAG then
            self.is_dragging = true
            return true
        end
    end
end

SpawnLiquidScreen = defclass(SpawnLiquidScreen, gui.ZScreen)
SpawnLiquidScreen.ATTRS {
    focus_path = 'spawnliquid',
    pass_movement_keys = true,
    pass_mouse_clicks = false,
}

function SpawnLiquidScreen:init()
    self:addviews{SpawnLiquid{}}
end

function SpawnLiquidScreen:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a fortress map to be loaded')
end

view = view and view:raise() or SpawnLiquidScreen{}:show()
