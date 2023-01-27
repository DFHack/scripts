-- Interface for spawning liquids on tiles.

local liquids = reqscript('modtools/spawn-liquid')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local widgets = require('gui.widgets')

local SpawnLiquidMode = {
    DRAG = 1,
    CLICK = 2,
    AREA = 3,
}

local SpawnLiquidCursor = {
    [df.tile_liquid.Water] = dfhack.screen.findGraphicsTile('MINING_INDICATORS', 0, 0),
    [df.tile_liquid.Magma] = dfhack.screen.findGraphicsTile('MINING_INDICATORS', 1, 0),
}

SpawnLiquid = defclass(SpawnLiquid, widgets.Window)
SpawnLiquid.ATTRS {
    frame_title='Spawn liquid menu',
    frame={b = 4, r = 4, w = 50, h = 12},
}

function SpawnLiquid:init()
    self.type = df.tile_liquid.Water
    self.level = 3
    self.mode = SpawnLiquidMode.DRAG
    self.tile = SpawnLiquidCursor[self.type]

    self:addviews{
        widgets.Label{
            frame = {l = 0, t = 0},
            text = {{ text = self:callback('getLabel') }}
        },
        widgets.HotkeyLabel{
            frame = {l = 0, b = 2},
            label = 'Decrease level',
            auto_width = true,
            key = 'KEYBOARD_CURSOR_LEFT',
            on_activate = self:callback('decreaseLiquidLevel'),
            disabled = function() return self.level == 1 end
        },
        widgets.HotkeyLabel{
            frame = { l = 18, b = 2},
            label = 'Increase level',
            auto_width = true,
            key = 'KEYBOARD_CURSOR_RIGHT',
            on_activate = self:callback('increaseLiquidLevel'),
            disabled = function() return self.level == 7 end
        },
        widgets.CycleHotkeyLabel{
            frame = {l = 0, b = 1},
            label = 'Liquid type:',
            auto_width = true,
            key = 'KEYBOARD_CURSOR_UP',
            options = {
                { label = "Water", value = df.tile_liquid.Water, pen = COLOR_CYAN },
                { label = "Magma", value = df.tile_liquid.Magma, pen = COLOR_RED },
            },
            initial_option = 0,
            on_change = function(new, _)
                self.type = new
                self.tile = SpawnLiquidCursor[self.type]
            end,
        },
        widgets.CycleHotkeyLabel{
            frame = {l = 0, b = 0},
            label = 'Mode:',
            auto_width = true,
            key = 'KEYBOARD_CURSOR_DOWN',
            options = {
                { label = "Drag ", value = SpawnLiquidMode.DRAG, pen = COLOR_WHITE },
                { label = "Click", value = SpawnLiquidMode.CLICK, pen = COLOR_WHITE },
                { label = "Area ", value = SpawnLiquidMode.AREA, pen = COLOR_WHITE },
            },
            initial_option = 1,
            on_change = function(new, old) self.mode = new end,
        },
    }
end

function SpawnLiquid:getLabel()
    return ([[Cick on a tile to spawn a %s/7 level of %s]]):format(self.level, self.type and "Water" or "Magma")
end

function SpawnLiquid:increaseLiquidLevel()
    if self.level < 7 then
        self.level = self.level + 1
    end
end

function SpawnLiquid:decreaseLiquidLevel()
    if self.level > 1 then
        self.level = self.level - 1
    end
end

function SpawnLiquid:spawn(pos)
    if dfhack.maps.isValidTilePos(pos) and dfhack.maps.isTileVisible(pos) then
        liquids.spawnLiquid(pos, self.level, self.type)
    end
end

function SpawnLiquid:getPen()
    return self.type == df.tile_liquid.Water and COLOR_BLUE or COLOR_RED, "X", self.tile
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

    local mouse_pos = dfhack.gui.getMousePos()

    if self.is_dragging then
        if df.global.enabler.mouse_lbut == 0 then
            self.is_dragging = false
        elseif mouse_pos and not self:getMouseFramePos() then
            self:spawn(mouse_pos)
        end
    end

    if mouse_pos then
        guidm.renderMapOverlay(self:callback('getPen'), self:getBounds(
            self.is_dragging_area and self.area_first_pos or mouse_pos,
            mouse_pos
        ))
    end
end

function SpawnLiquid:onInput(keys)
    if SpawnLiquid.super.onInput(self, keys) then return true end

    if keys._MOUSE_L_DOWN and not self:getMouseFramePos() then
        local mouse_pos = dfhack.gui.getMousePos()

        if self.mode == SpawnLiquidMode.CLICK and mouse_pos then
            self:spawn(mouse_pos)
        elseif self.mode == SpawnLiquidMode.AREA and mouse_pos then
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
            end
        elseif self.mode == SpawnLiquidMode.DRAG then
            self.is_dragging = true
        end
    end

    if keys._MOUSE_L and not self:getMouseFramePos() then
        if self.mode == SpawnLiquidMode.DRAG then
            self.is_dragging = true
            return true
        end
    end
end

SpawnLiquidScreen = defclass(SpawnLiquidScreen, gui.ZScreen)
SpawnLiquidScreen.ATTRS {
    focus_path='spawnliquid',
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
