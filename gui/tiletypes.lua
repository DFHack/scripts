--@ module = true
local argparse = require('argparse')
local gui = require('gui')
local guidm = require('gui.dwarfmode')
local plugin = require('plugins.tiletypes')
local textures = require('gui.textures')
local utils = require('utils')
local widgets = require('gui.widgets')

local UI_AREA = {r=2, t=18, w=38, h=35}
local POPUP_UI_AREA = {r=41, t=18, w=30, h=22}

local CONFIG_BUTTON = {
    { tile= dfhack.pen.parse{fg=COLOR_CYAN, tile=curry(textures.tp_control_panel, 7) or nil, ch=string.byte('[')} },
    { tile= dfhack.pen.parse{tile=curry(textures.tp_control_panel, 10) or nil, ch=15} }, -- gear/masterwork symbol
    { tile= dfhack.pen.parse{fg=COLOR_CYAN, tile=curry(textures.tp_control_panel, 8) or nil, ch=string.byte(']')} }
}

local OTHER_LABEL_FORMAT = { first= string.char(15).."(", last= ")"}

local UI_COLORS = {
    SELECTED= COLOR_GREEN,
    SELECTED2= COLOR_CYAN,
    SELECTED_BORDER= COLOR_LIGHTGREEN,
    DESELECTED= COLOR_GRAY,
    DESELECTED2= COLOR_DARKGRAY,
    DESELECTED_BORDER= COLOR_GRAY,
    HIGHLIGHTED= COLOR_WHITE,
    HIGHLIGHTED2= COLOR_DARKGRAY,
    HIGHLIGHTED_BORDER= COLOR_YELLOW,
    VALUE_NONE= COLOR_GRAY,
    VALUE= COLOR_YELLOW,
    VALID_OPTION= COLOR_WHITE,
    INVALID_OPTION= COLOR_RED,
}

local TILESET = dfhack.textures.loadTileset('hack/data/art/tiletypes.png', 8, 12, true)
local TILESET_STRIDE = 16

local DEFAULT_OPTIONS = {
    { value= -1, char1= " ", char2= " ", offset=  97, pen = COLOR_GRAY },
    { value=  1, char1= "+", char2= "+", offset= 101, pen = COLOR_LIGHTGREEN },
    { value=  0, char1= "X", char2= "X", offset= 105, pen = COLOR_RED },
}

local MORE_OPTIONS = {
    ["hidden"]       = { label= "Hidden", values= DEFAULT_OPTIONS },
    ["light"]        = { label= "Light", values= DEFAULT_OPTIONS },
    ["subterranean"] = { label= "Subterranean", values= DEFAULT_OPTIONS },
    ["skyview"]      = { label= "Skyview", values= DEFAULT_OPTIONS },
    ["aquifer"]      = { label= "Aquifer", values= {
        { value= -1, char1= " ", char2= " ", offset=  97, pen = COLOR_GRAY },
        { value=  1, char1= 173, char2= 173, offset= 109, pen = COLOR_LIGHTBLUE },
        { value=  2, char1= 247, char2= 247, offset= 157, pen = COLOR_BLUE },
        { value=  0, char1= "X", char2= "X", offset= 105, pen = COLOR_RED },
    } },
    ["surroundings"] = { label= "Surroundings", values= {
        { value=  1, char1= "+", char2= "+", offset= 101, pen = COLOR_LIGHTGREEN },
        { value=  0, char1= "X", char2= "X", offset= 105, pen = COLOR_RED },
    } },
}

local MODE_LIST = {
    { label= "Paint"   , value= "paint"  , pen= COLOR_YELLOW     },
    { label= "Replace" , value= "replace", pen= COLOR_LIGHTGREEN },
    { label= "Fill"    , value= "fill"   , pen= COLOR_GREEN      },
    { label= "Remove"  , value= "remove" , pen= COLOR_RED        },
}

function isEmptyTile(pos)
    if pos and dfhack.maps.isValidTilePos(pos) then
        local tiletype = dfhack.maps.getTileType(pos)
        return tiletype and (
            df.tiletype.attrs[tiletype].shape == df.tiletype_shape.NONE
            or df.tiletype.attrs[tiletype].material == df.tiletype_material.AIR
        )
    end
    return true
end

local MODE_SETTINGS = {
    ["paint"] = {
        idx= 1, config= true , char1= 219, char2= 219, offset=  1, selected_offset = 49,
        description= "Paint tiles",
        validator= function(pos) return true end
    },
    ["replace"] = {
        idx= 2, config= true , char1=   8, char2=   7, offset=  5, selected_offset = 53,
        description= "Replace non-empty tiles",
        validator= function(pos) return not isEmptyTile(pos) end
    },
    ["fill"] = {
        idx= 3, config= true , char1=   7, char2=   8, offset=  9, selected_offset = 57,
        description= "Fill in empty tiles",
        validator= function(pos) return isEmptyTile(pos) end
    },
    ["remove"] = {
        idx= 4, config= false, char1= 177, char2= 177, offset= 13, selected_offset = 61,
        description= "Remove selected tiles",
        validator= function(pos) return true end
    },
}

CYCLE_VALUES = {
    shape = {
        [df.tiletype_shape.NONE] = true,
        [df.tiletype_shape.EMPTY] = true,
        [df.tiletype_shape.FLOOR] = true,
        [df.tiletype_shape.WALL] = true,
        other = df.tiletype_shape.STAIR_UPDOWN
    },
    material = {
        [df.tiletype_material.NONE] = true,
        [df.tiletype_material.AIR] = true,
        [df.tiletype_material.SOIL] = true,
        [df.tiletype_material.STONE] = true,
        other = df.tiletype_material.LAVA_STONE
    },
    special = {
        [df.tiletype_special.NONE] = true,
        [df.tiletype_special.NORMAL] = true,
        [df.tiletype_special.SMOOTH] = true,
        other = df.tiletype_special.WORN_1
    },
}

---@class TileType
---@field shape? df.tiletype_shape
---@field material? df.tiletype_material
---@field special? df.tiletype_special
---@field variant? df.tiletype_variant
---@field dig? integer Only for filters
---@field hidden? integer
---@field light? integer
---@field subterranean? integer
---@field skyview? integer
---@field aquifer? integer
---@field surroundings? integer
---@field stone_material? integer
---@field vein_type? df.inclusion_type

---@param pos df.coord
---@param target TileType
---@return boolean
function setTile(pos, target)
    local toValidEnumValue = function(value, enum, default)
        return value ~= nil and enum[value] and value or default
    end
    local toValidOptionValue = function(value)
        return value == nil and -1 or value
    end

    local tiletype = {
        shape          = toValidEnumValue(target.shape,    df.tiletype_shape,    df.tiletype_shape.NONE),
        material       = toValidEnumValue(target.material, df.tiletype_material, df.tiletype_material.NONE),
        special        = toValidEnumValue(target.special,  df.tiletype_special,  df.tiletype_special.NONE),
        variant        = toValidEnumValue(target.variant,  df.tiletype_variant,  df.tiletype_variant.NONE),
        hidden         = toValidOptionValue(target.hidden),
        light          = toValidOptionValue(target.light),
        subterranean   = toValidOptionValue(target.subterranean),
        skyview        = toValidOptionValue(target.skyview),
        aquifer        = toValidOptionValue(target.aquifer),
        surroundings   = target.surroundings == nil and 0 or target.surroundings,
    }
    tiletype.stone_material = tiletype.material == df.tiletype_material.STONE and target.stone_material or -1
    tiletype.vein_type      = tiletype.material ~= df.tiletype_material.STONE and -1 or toValidEnumValue(target.vein_type,  df.inclusion_type,  df.inclusion_type.CLUSTER)

    return plugin.tiletypes_setTile(pos, tiletype)
end

--#region GUI

--#region UI Utilities

---@type widgets.LabelToken
local EMPTY_TOKEN = { text=' ', hpen=dfhack.pen.make(COLOR_RESET), width=1 }

---@class InlineButtonLabelSpec
---@field left_specs? widgets.ButtonLabelSpec
---@field right_specs? widgets.ButtonLabelSpec
---@field width? integer
---@field height? integer
---@field spacing? integer

---@nodiscard
---@param spec InlineButtonLabelSpec
---@return widgets.LabelToken[]
function makeInlineButtonLabelText(spec)
    spec.left_specs = safe_index(spec, "left_specs", "chars") and spec.left_specs or {chars={}}
    spec.right_specs = safe_index(spec, "right_specs", "chars") and spec.right_specs or {chars={}}
    spec.width = spec.width or -1
    spec.height = spec.height or -1
    spec.spacing = spec.spacing or -1

    local getSpecWidth = function(value)
        local width = 0
        for _,v in pairs(value.chars) do
            width = math.max(width, #v)
        end
        return width
    end

    local left_width = getSpecWidth(spec.left_specs)
    local right_width = getSpecWidth(spec.right_specs)
    spec.width = spec.width >= 0 and spec.width or (left_width + right_width + math.max(spec.spacing, 0))

    local left_height = #spec.left_specs.chars
    local right_height = #spec.right_specs.chars
    spec.height = spec.height >= 0 and spec.height or math.max(left_height, right_height)

    local left_tokens = widgets.makeButtonLabelText(spec.left_specs)
    local right_tokens = widgets.makeButtonLabelText(spec.right_specs)

    local centerHeight = function(tokens, height)
        local height_spacing = (spec.height - height) // 2
        for i=1, height_spacing do
            table.insert(tokens, 1, NEWLINE)
        end
        height_spacing = spec.height - height - height_spacing
        for i=1, height_spacing do
            table.insert(tokens, NEWLINE)
        end
    end

    centerHeight(left_tokens, left_height)
    centerHeight(right_tokens, right_height)

    local right_start = spec.spacing >= 0 and (left_width + spec.spacing + 1) or math.max(left_width, spec.width - right_width)

    local label_tokens = {}
    local left_cursor = 1
    local right_cursor = 1
    for y=1, spec.height do
        for x=1, spec.width do
            local token = nil
            if x <= left_width then
                token = left_tokens[left_cursor]
                token = token ~= NEWLINE and token or nil
                if token then
                    left_cursor = left_cursor + 1
                end
            elseif x >= right_start then
                token = right_tokens[right_cursor]
                token = token ~= NEWLINE and token or nil
                if token then
                    right_cursor = right_cursor + 1
                end
            end
            table.insert(label_tokens, token or EMPTY_TOKEN)
        end

        if y ~= spec.height then
            -- Move the cursors to the token following the next NEWLINE
            while left_tokens[left_cursor - 1] ~= NEWLINE do
                left_cursor = left_cursor + 1
            end
            while right_tokens[right_cursor - 1] ~= NEWLINE do
                right_cursor = right_cursor + 1
            end
        end

        table.insert(label_tokens, NEWLINE)
    end

    return label_tokens
end

-- Rect data class

---@class Rect.attrs
---@field x1 number
---@field y1 number
---@field x2 number
---@field y2 number

---@class Rect.attrs.partial: Rect.attrs

---@class Rect: Rect.attrs
---@field ATTRS Rect.attrs|fun(attributes: Rect.attrs.partial)
---@overload fun(init_table: Rect.attrs.partial): self
Rect = defclass(Rect)
Rect.ATTRS {
    x1 = -1,
    y1 = -1,
    x2 = -1,
    y2 = -1,
}

---@param pos df.coord2d
---@return boolean
function Rect:contains(pos)
    return pos.x <= self.x2
        and pos.x >= self.x1
        and pos.y <= self.y2
        and pos.y >= self.y1
end

---@param overlap_rect Rect
---@return boolean
function Rect:isOverlapping(overlap_rect)
    return overlap_rect.x1 <= self.x2
        and overlap_rect.x2 >= self.x1
        and overlap_rect.y1 <= self.y2
        and overlap_rect.y2 >= self.y1
end

---@param clip_rect Rect
---@return Rect[]
function Rect:clip(clip_rect)
    local output = {}

    -- If there is any overlap with the screen rect
    if self:isOverlapping(clip_rect) then
        local temp_rect = Rect(self)
        -- Get rect to the left of the clip rect
        if temp_rect.x1 <= clip_rect.x1 then
            table.insert(output, Rect{
                x1= temp_rect.x1,
                x2= math.min(temp_rect.x2, clip_rect.x1),
                y1= temp_rect.y1,
                y2= temp_rect.y2
            })
            temp_rect.x1 = clip_rect.x1
        end
        -- Get rect to the right of the clip rect
        if temp_rect.x2 >= clip_rect.x2 then
            table.insert(output, Rect{
                x1= math.max(temp_rect.x1, clip_rect.x2),
                x2= temp_rect.x2,
                y1= temp_rect.y1,
                y2= temp_rect.y2
            })
            temp_rect.x2 = clip_rect.x2
        end
        -- Get rect above the clip rect
        if temp_rect.y1 <= clip_rect.y1 then
            table.insert(output, Rect{
                x1= temp_rect.x1,
                x2= temp_rect.x2,
                y1= temp_rect.y1,
                y2= math.min(temp_rect.y2, clip_rect.y1)
            })
            temp_rect.y1 = clip_rect.y1
        end
        -- Get rect below the clip rect
        if temp_rect.y2 >= clip_rect.y2 then
            table.insert(output, Rect{
                x1= temp_rect.x1,
                x2= temp_rect.x2,
                y1= math.max(temp_rect.y1, clip_rect.y2),
                y2= temp_rect.y2
            })
            temp_rect.y2 = clip_rect.y2
        end
    else
        -- No overlap
        table.insert(output, self)
    end

    return output
end

---@return Rect
function Rect:screenToTile()
    local view_dims = dfhack.gui.getDwarfmodeViewDims()
    local tile_view_size = xy2pos(view_dims.map_x2 - view_dims.map_x1 + 1, view_dims.map_y2 - view_dims.map_y1 + 1)
    local display_view_size = xy2pos(df.global.init.display.grid_x, df.global.init.display.grid_y)
    local display_to_tile_ratio = xy2pos(tile_view_size.x / display_view_size.x, tile_view_size.y / display_view_size.y)

    return Rect{
        x1= self.x1 * display_to_tile_ratio.x - 1,
        x2= self.x2 * display_to_tile_ratio.x + 1,
        y1= self.y1 * display_to_tile_ratio.y - 1,
        y2= self.y2 * display_to_tile_ratio.y + 1
    }
end

---@return Rect
function Rect:tileToScreen()
    local view_dims = dfhack.gui.getDwarfmodeViewDims()
    local tile_view_size = xy2pos(view_dims.map_x2 - view_dims.map_x1 + 1, view_dims.map_y2 - view_dims.map_y1 + 1)
    local display_view_size = xy2pos(df.global.init.display.grid_x, df.global.init.display.grid_y)
    local display_to_tile_ratio = xy2pos(tile_view_size.x / display_view_size.x, tile_view_size.y / display_view_size.y)

    return Rect{
        x1= (self.x1 + 1) / display_to_tile_ratio.x,
        x2= (self.x2 - 1) / display_to_tile_ratio.x,
        y1= (self.y1 + 1) / display_to_tile_ratio.y,
        y2= (self.y2 - 1) / display_to_tile_ratio.y
    }
end

-- Draws a list of rects with associated pens, without overlapping any of the given screen rects
---@param draw_queue { pen: dfhack.pen, rect: Rect }[]
---@param screen_rect_list Rect[]
function drawOutsideOfScreenRectList(draw_queue, screen_rect_list)
    local cur_draw_queue = draw_queue
    for _,screen_rect in pairs(screen_rect_list) do
        local screen_tile_rect = screen_rect:screenToTile()
        local new_draw_queue = {}
        for _,draw_rect in pairs(cur_draw_queue) do
            for _,clipped in pairs(draw_rect.rect:clip(screen_tile_rect)) do
                table.insert(new_draw_queue, { pen= draw_rect.pen, rect= clipped })
            end
        end
        cur_draw_queue = new_draw_queue
    end

    for _,draw_rect in pairs(cur_draw_queue) do
        dfhack.screen.fillRect(draw_rect.pen, draw_rect.rect.x1, draw_rect.rect.y1, draw_rect.rect.x2, draw_rect.rect.y2, true)
    end
end

-- Box data class

---@class Box.attrs

---@class Box.attrs.partial: Box.attrs

---@class Box: Box.attrs
---@field ATTRS Box.attrs|fun(attributes: Box.attrs.partial)
---@field valid boolean
---@field min df.coord
---@field max df.coord
---@overload fun(init_table: Box.attrs.partial): self
Box = defclass(Box)
Box.ATTRS {}

function Box:init(points)
    self.valid = true
    self.min = nil
    self.max = nil
    for _,value in pairs(points) do
        if dfhack.maps.isValidTilePos(value) then
            self.min = xyz2pos(
                self.min and math.min(self.min.x, value.x) or value.x,
                self.min and math.min(self.min.y, value.y) or value.y,
                self.min and math.min(self.min.z, value.z) or value.z
            )
            self.max = xyz2pos(
                self.max and math.max(self.max.x, value.x) or value.x,
                self.max and math.max(self.max.y, value.y) or value.y,
                self.max and math.max(self.max.z, value.z) or value.z
            )
        else
            self.valid = false
            break
        end
    end

    self.valid = self.valid and self.min and self.max
        and dfhack.maps.isValidTilePos(self.min.x, self.min.y, self.min.z)
        and dfhack.maps.isValidTilePos(self.max.x, self.max.y, self.max.z)

    if not self.valid then
        self.min = xyz2pos(-1, -1, -1)
        self.max = xyz2pos(-1, -1, -1)
    end
end

function Box:iterate(callback)
    if not self.valid then return end
    for z = self.min.z, self.max.z do
        for y = self.min.y, self.max.y do
            for x = self.min.x, self.max.x do
                callback(xyz2pos(x, y, z))
            end
        end
    end
end

function Box:draw(tile_map, avoid_rect, ascii_fill)
    if not self.valid or df.global.window_z < self.min.z or df.global.window_z > self.max.z then return end
    local screen_min = xy2pos(
        self.min.x - df.global.window_x,
        self.min.y - df.global.window_y
    )
    local screen_max = xy2pos(
        self.max.x - df.global.window_x,
        self.max.y - df.global.window_y
    )

    local draw_queue = {}

    if self.min.x == self.max.x and self.min.y == self.max.y then
        -- Single point
        draw_queue = {
            {
                pen= tile_map.pens[tile_map.getPenKey{n=true, e=true, s=true, w=true}],
                rect= Rect{ x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_min.y }
            }
        }

    elseif self.min.x == self.max.x then
        -- Vertical line
        draw_queue = {
            -- Line
            {
                pen= tile_map.pens[tile_map.getPenKey{n=false, e=true, s=false, w=true}],
                rect= Rect{ x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_max.y }
            },
            -- Top nub
            {
                pen= tile_map.pens[tile_map.getPenKey{n=true, e=true, s=false, w=true}],
                rect= Rect{ x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_min.y }
            },
            -- Bottom nub
            {
                pen= tile_map.pens[tile_map.getPenKey{n=false, e=true, s=true, w=true}],
                rect= Rect{ x1= screen_min.x, x2= screen_min.x, y1= screen_max.y, y2= screen_max.y }
            }
        }
    elseif self.min.y == self.max.y then
        -- Horizontal line
        draw_queue = {
            -- Line
            {
                pen= tile_map.pens[tile_map.getPenKey{n=true, e=false, s=true, w=false}],
                rect= Rect{ x1= screen_min.x, x2= screen_max.x, y1= screen_min.y, y2= screen_min.y }
            },
            -- Left nub
            {
                pen= tile_map.pens[tile_map.getPenKey{n=true, e=false, s=true, w=true}],
                rect= Rect{ x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_min.y }
            },
            -- Right nub
            {
                pen= tile_map.pens[tile_map.getPenKey{n=true, e=true, s=true, w=false}],
                rect= Rect{ x1= screen_max.x, x2= screen_max.x, y1= screen_min.y, y2= screen_min.y }
            }
        }
    else
        -- Rectangle
        draw_queue = {
            -- North Edge
            {
                pen= tile_map.pens[tile_map.getPenKey{n=true, e=false, s=false, w=false}],
                rect= Rect{ x1= screen_min.x, x2= screen_max.x, y1= screen_min.y, y2= screen_min.y }
            },
            -- East Edge
            {
                pen= tile_map.pens[tile_map.getPenKey{n=false, e=true, s=false, w=false}],
                rect= Rect{ x1= screen_max.x, x2= screen_max.x, y1= screen_min.y, y2= screen_max.y }
            },
            -- South Edge
            {
                pen= tile_map.pens[tile_map.getPenKey{n=false, e=false, s=true, w=false}],
                rect= Rect{ x1= screen_min.x, x2= screen_max.x, y1= screen_max.y, y2= screen_max.y }
            },
            -- West Edge
            {
                pen= tile_map.pens[tile_map.getPenKey{n=false, e=false, s=false, w=true}],
                rect= Rect{ x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_max.y }
            },
            -- NW Corner
            {
                pen= tile_map.pens[tile_map.getPenKey{n=true, e=false, s=false, w=true}],
                rect= Rect{ x1= screen_min.x, x2= screen_min.x, y1= screen_min.y, y2= screen_min.y }
            },
            -- NE Corner
            {
                pen= tile_map.pens[tile_map.getPenKey{n=true, e=true, s=false, w=false}],
                rect= Rect{ x1= screen_max.x, x2= screen_max.x, y1= screen_min.y, y2= screen_min.y }
            },
            -- SE Corner
            {
                pen= tile_map.pens[tile_map.getPenKey{n=false, e=true, s=true, w=false}],
                rect= Rect{ x1= screen_max.x, x2= screen_max.x, y1= screen_max.y, y2= screen_max.y }
            },
            -- SW Corner
            {
                pen= tile_map.pens[tile_map.getPenKey{n=false, e=false, s=true, w=true}],
                rect= Rect{ x1= screen_min.x, x2= screen_min.x, y1= screen_max.y, y2= screen_max.y }
            },
        }

        if dfhack.screen.inGraphicsMode() or ascii_fill then
            -- Fill inside
            table.insert(draw_queue, 1, {
                pen= tile_map.pens[tile_map.getPenKey{n=false, e=false, s=false, w=false}],
                rect= Rect{ x1= screen_min.x + 1, x2= screen_max.x - 1, y1= screen_min.y + 1, y2= screen_max.y - 1 }
            })
        end
    end

    if avoid_rect and not dfhack.screen.inGraphicsMode() then
        -- If in ASCII and an avoid_rect was specified
        -- Draw the queue, avoiding the avoid_rect
        drawOutsideOfScreenRectList(draw_queue, { avoid_rect })
    else
        -- Draw the queue
        for _,draw_rect in pairs(draw_queue) do
            dfhack.screen.fillRect(draw_rect.pen, math.floor(draw_rect.rect.x1), math.floor(draw_rect.rect.y1), math.floor(draw_rect.rect.x2), math.floor(draw_rect.rect.y2), true)
        end
    end
end

--================================--
--||        BoxSelection        ||--
--================================--
-- Allows for selecting a box

---@class BoxTileMap
---@field getPenKey fun(nesw: { n: boolean, e: boolean, s: boolean, w: boolean }): any
---@field createPens? fun(): { key: dfhack.pen }
---@field pens? { key: dfhack.pen }
local TILE_MAP = {
    getPenKey= function(nesw)
        local out = 0
        for _,v in ipairs({nesw.n, nesw.e, nesw.s, nesw.w}) do
            out = (out << 1) | (v and 1 or 0)
        end
        return out
    end
}
TILE_MAP.createPens= function()
    return {
        [TILE_MAP.getPenKey{ n=false, e=false, s=false, w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 1,  2), fg=COLOR_GREEN, ch='X'}, -- INSIDE
        [TILE_MAP.getPenKey{ n=true,  e=false, s=false, w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 0,  1), fg=COLOR_GREEN, ch='X'}, -- NW
        [TILE_MAP.getPenKey{ n=true,  e=false, s=false, w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 1,  1), fg=COLOR_GREEN, ch='X'}, -- NORTH
        [TILE_MAP.getPenKey{ n=true,  e=true,  s=false, w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 2,  1), fg=COLOR_GREEN, ch='X'}, -- NE
        [TILE_MAP.getPenKey{ n=false, e=false, s=false, w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 0,  2), fg=COLOR_GREEN, ch='X'}, -- WEST
        [TILE_MAP.getPenKey{ n=false, e=true,  s=false, w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 2,  2), fg=COLOR_GREEN, ch='X'}, -- EAST
        [TILE_MAP.getPenKey{ n=false, e=false, s=true,  w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 0,  3), fg=COLOR_GREEN, ch='X'}, -- SW
        [TILE_MAP.getPenKey{ n=false, e=false, s=true,  w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 1,  3), fg=COLOR_GREEN, ch='X'}, -- SOUTH
        [TILE_MAP.getPenKey{ n=false, e=true,  s=true,  w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 2,  3), fg=COLOR_GREEN, ch='X'}, -- SE
        [TILE_MAP.getPenKey{ n=true,  e=true,  s=false, w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 3,  2), fg=COLOR_GREEN, ch='X'}, -- N_NUB
        [TILE_MAP.getPenKey{ n=true,  e=true,  s=true,  w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 5,  1), fg=COLOR_GREEN, ch='X'}, -- E_NUB
        [TILE_MAP.getPenKey{ n=true,  e=false, s=true,  w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 3,  1), fg=COLOR_GREEN, ch='X'}, -- W_NUB
        [TILE_MAP.getPenKey{ n=false, e=true,  s=true,  w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 4,  2), fg=COLOR_GREEN, ch='X'}, -- S_NUB
        [TILE_MAP.getPenKey{ n=false, e=true,  s=false, w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 3,  3), fg=COLOR_GREEN, ch='X'}, -- VERT_NS
        [TILE_MAP.getPenKey{ n=true,  e=false, s=true,  w=false }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 4,  1), fg=COLOR_GREEN, ch='X'}, -- VERT_EW
        [TILE_MAP.getPenKey{ n=true,  e=true,  s=true,  w=true  }] = dfhack.pen.parse{tile=dfhack.screen.findGraphicsTile("CURSORS", 4,  3), fg=COLOR_GREEN, ch='X'}, -- POINT
    }
end

---@class BoxSelection.attrs: widgets.Window.attrs
---@field tooltip_enabled? boolean,
---@field screen? gui.Screen
---@field tile_map? BoxTileMap
---@field avoid_view? gui.View|fun():gui.View
---@field on_confirm? fun(box: Box)
---@field flat boolean
---@field ascii_fill boolean

---@class BoxSelection.attrs.partial: BoxSelection.attrs

---@class BoxSelection: widgets.Window, BoxSelection.attrs
---@field box? Box
---@field first_point? df.coord
---@field last_point? df.coord
BoxSelection = defclass(BoxSelection, widgets.Window)
BoxSelection.ATTRS {
    tooltip_enabled=true,
    screen=DEFAULT_NIL,
    tile_map=TILE_MAP,
    avoid_view=DEFAULT_NIL,
    on_confirm=DEFAULT_NIL,
    flat=false,
    ascii_fill=false,
}

function BoxSelection:init()
    self.frame = { w=0, h=0 }
    self.box=nil
    self.first_point=nil
    self.last_point=nil

    if self.tile_map then
        if self.tile_map.createPens then
            self.tile_map.pens = self.tile_map.createPens()
        end
    else
        error("No tile map provided")
    end

    -- Set the cursor to the center of the screen
    guidm.setCursorPos(guidm.Viewport.get():getCenter())

    -- Show cursor
    df.global.game.main_interface.main_designation_selected = df.main_designation_type.TOGGLE_ENGRAVING

    if self.tooltip_enabled then
        if self.screen then
            self.dimensions_tooltip = widgets.DimensionsTooltip{
                get_anchor_pos_fn=function()
                    if self.first_point and self.flat then
                        return xyz2pos(self.first_point.x, self.first_point.y, df.global.window_z)
                    end
                    return self.first_point
                end,
            }
            self.screen:addviews{
                self.dimensions_tooltip
            }
        else
            error("No screen provided to BoxSelection, unable to display DimensionsTooltip")
        end
    end
end

function BoxSelection:confirm()
    if self.first_point and self.last_point
        and dfhack.maps.isValidTilePos(self.first_point)
        and dfhack.maps.isValidTilePos(self.last_point)
    then
        self.box = Box{
            self.first_point,
            self.last_point
        }
        if self.on_confirm then
            self.on_confirm(self.box)
        end
    end
end

function BoxSelection:clear()
    self.box = nil
    self.first_point = nil
    self.last_point = nil
end

function BoxSelection:onInput(keys)
    if BoxSelection.super.onInput(self, keys) then
        return true
    end
    if keys.LEAVESCREEN or keys._MOUSE_R then
        if self.last_point then
            self.box = nil
            self.last_point = nil
            return true
        elseif self.first_point then
            self.first_point = nil
            return true
        end
        return false
    end

    local mousePos = dfhack.gui.getMousePos(true)
    local cursorPos = copyall(df.global.cursor)
    cursorPos.x = math.max(math.min(cursorPos.x, df.global.world.map.x_count - 1), 0)
    cursorPos.y = math.max(math.min(cursorPos.y, df.global.world.map.y_count - 1), 0)

    if cursorPos and keys.SELECT then
        if self.first_point and not self.last_point then
            if not self.flat or cursorPos.z == self.first_point.z then
                self.last_point = cursorPos
                self:confirm()
            end
        elseif dfhack.maps.isValidTilePos(cursorPos) then
            self.first_point = self.first_point or cursorPos
        end

        return true
    end

    local avoid_view = utils.getval(self.avoid_view)

    -- Get the position of the mouse in coordinates local to avoid_view, if it's specified
    local mouseFramePos = avoid_view and avoid_view:getMouseFramePos()

    if keys._MOUSE_L and not mouseFramePos then
        -- If left click and the mouse is not in the avoid_view
        self.useCursor = false
        if self.first_point and not self.last_point then
            if not self.flat or mousePos.z == self.first_point.z then
                local inBoundsMouse = xyz2pos(
                    math.max(math.min(mousePos.x, df.global.world.map.x_count - 1), 0),
                    math.max(math.min(mousePos.y, df.global.world.map.y_count - 1), 0),
                    mousePos.z
                )
                self.last_point = inBoundsMouse
                self:confirm()
            end
        elseif dfhack.maps.isValidTilePos(mousePos) then
            self.first_point = self.first_point or mousePos
        end

        return true
    end

    -- Switch to the cursor if the cursor was moved (Excluding up and down a Z level)
    local filteredKeys = utils.clone(keys)
    filteredKeys["CURSOR_DOWN_Z"] = nil
    filteredKeys["CURSOR_UP_Z"] = nil
    self.useCursor = (self.useCursor or guidm.getMapKey(filteredKeys)) and df.global.d_init.feature.flags.KEYBOARD_CURSOR

    return false
end

function BoxSelection:onRenderFrame(dc, rect)
    -- Switch to cursor if the mouse is offscreen, or if it hasn't moved
    self.useCursor = (self.useCursor or (self.lastMousePos and (self.lastMousePos.x < 0 or self.lastMousePos.y < 0)))
        and self.lastMousePos.x == df.global.gps.mouse_x and self.lastMousePos.y == df.global.gps.mouse_y
    self.lastMousePos = xy2pos(df.global.gps.mouse_x, df.global.gps.mouse_y)

    if self.tooltip_enabled and self.screen and self.dimensions_tooltip then
        self.dimensions_tooltip.visible = not self.useCursor
    end

    if not self.tile_map then return end

    local box = self.box
    if not box then
        local selectedPos = dfhack.gui.getMousePos(true)
        if self.useCursor or not selectedPos then
            selectedPos = copyall(df.global.cursor)
            selectedPos.x = math.max(math.min(selectedPos.x, df.global.world.map.x_count - 1), 0)
            selectedPos.y = math.max(math.min(selectedPos.y, df.global.world.map.y_count - 1), 0)
        end

        if self.flat and self.first_point then
            selectedPos.z = self.first_point.z
        end

        local inBoundsMouse = xyz2pos(
            math.max(math.min(selectedPos.x, df.global.world.map.x_count - 1), 0),
            math.max(math.min(selectedPos.y, df.global.world.map.y_count - 1), 0),
            selectedPos.z
        )

        box = Box {
            self.first_point or selectedPos,
            self.last_point or (self.first_point and inBoundsMouse or selectedPos)
        }
    end

    if box then
        local avoid_view = utils.getval(self.avoid_view)
        box:draw(self.tile_map, avoid_view and Rect(avoid_view.frame_rect), self.ascii_fill)
    end

    -- Don't call super.onRenderFrame, since this widget should not be drawn
end

function BoxSelection:hideCursor()
    -- Hide cursor
    df.global.game.main_interface.main_designation_selected = df.main_designation_type.NONE
end

--================================--
--||        SelectDialog        ||--
--================================--
-- Popup for selecting an item from a list, with a search bar

---@class CategoryChoice
---@field text string|widgets.LabelToken[]
---@field category string?
---@field key string?
---@field item_list (widgets.ListChoice|CategoryChoice)[]

local ARROW = string.char(26)

SelectDialogWindow = defclass(SelectDialogWindow, widgets.Window)

SelectDialogWindow.ATTRS{
    prompt = "Type or select a item from this list",
    base_category = "Any item",
    frame={w=40, h=28},
    frame_style = gui.FRAME_PANEL,
    frame_inset = 1,
    frame_title = "Select Item",
    item_list = DEFAULT_NIL, ---@type (widgets.ListChoice|CategoryChoice)[]
    on_select = DEFAULT_NIL,
    on_cancel = DEFAULT_NIL,
    on_close = DEFAULT_NIL,
}

function SelectDialogWindow:init()
    self.back = widgets.HotkeyLabel{
        frame = { r = 0, b = 0 },
        auto_width = true,
        visible = false,
        label = "Back",
        key="LEAVESCREEN",
        on_activate = self:callback('onGoBack')
    }
    self.list = widgets.FilteredList{
        not_found_label = 'No matching items',
        frame = { l = 0, r = 0, t = 4, b = 2 },
        icon_width = 2,
        on_submit = self:callback('onSubmitItem'),
    }
    self:addviews{
        widgets.Label{
            text = {
                self.prompt, '\n\n',
                'Category: ', { text = self:cb_getfield('category_str'), pen = COLOR_CYAN }
            },
            text_pen = COLOR_WHITE,
            frame = { l = 0, t = 0 },
        },
        self.back,
        self.list,
        widgets.HotkeyLabel{
            frame = { l = 0, b = 0 },
            auto_width = true,
            label = "Select",
            key="SELECT",
            disabled = function() return not self.list:canSubmit() end,
            on_activate = function() self.list:submit() end
        }
    }

    self:initCategory(self.base_category, self.item_list)
end

function SelectDialogWindow:onDismiss()
    if self.on_close then
        self.on_close()
    end
end

function SelectDialogWindow:initCategory(name, item_list)
    local choices = {}

    for _,value in pairs(item_list) do
        self:addItem(choices, value)
    end

    self:pushCategory(name, choices)
end

function SelectDialogWindow:addItem(choices, item)
    if not item or not item.text then return end

    if item.item_list then
        table.insert(choices, {
            icon = ARROW, text = item.text, key = item.key,
            cb = function() self:initCategory(item.category or item.text, item.item_list) end
        })
    else
        table.insert(choices, {
            text = item.text,
            value = item.value or item.text
        })
    end
end

function SelectDialogWindow:pushCategory(name, choices)
    if not self.back_stack then
        self.back_stack = {}
        self.back.visible = false
    else
        table.insert(self.back_stack, {
            category_str = self.category_str,
            all_choices = self.list:getChoices(),
            edit_text = self.list:getFilter(),
            selected = self.list:getSelected(),
        })
        self.back.visible = true
    end

    self.category_str = name
    self.list:setChoices(choices, 1)
end

function SelectDialogWindow:onGoBack()
    local save = table.remove(self.back_stack)
    self.back.visible = (#self.back_stack > 0)

    self.category_str = save.category_str
    self.list:setChoices(save.all_choices)
    self.list:setFilter(save.edit_text, save.selected)
end

function SelectDialogWindow:submitItem(value)
    self.parent_view:dismiss()

    if self.on_select then
        self.on_select(value)
    end
end

function SelectDialogWindow:onSubmitItem(idx, item)
    if item.cb then
        item:cb(idx)
    else
        self:submitItem(item.value)
    end
end

function SelectDialogWindow:onInput(keys)
    if SelectDialogWindow.super.onInput(self, keys) then
        return true
    end
    if keys.LEAVESCREEN or keys._MOUSE_R then
        self.parent_view:dismiss()
        if self.on_cancel then
            self.on_cancel()
        end
    end
    return true
end

-- Screen for the popup
SelectDialog = defclass(SelectDialog, gui.ZScreenModal)
SelectDialog.ATTRS{
    focus_path='selectdialog'
}

function SelectDialog:init(attrs)
    self.window = SelectDialogWindow(attrs)
    self:addviews{
        self.window
    }
end

function SelectDialog:onDismiss()
    self.window:onDismiss()
end

--#endregion


--================================--
--||         CycleLabel         ||--
--================================--
-- More customizable CycleHotkeyLabel

CycleLabel = defclass(CycleLabel, widgets.CycleHotkeyLabel)
CycleLabel.ATTRS{
    base_label=DEFAULT_NIL,
    key_pen=DEFAULT_NIL
}

function CycleLabel:init()
    self:setOption(self.initial_option)
    self:updateOptionLabel()

    local on_change_fn = self.on_change
    self.on_change = function(value)
        self:updateOptionLabel()
        if on_change_fn then
            on_change_fn(value)
        end
    end
end

function CycleLabel:updateOptionLabel()
    local label = self:getOptionLabel()
    if type(label) ~= "table" then
        label = {{ text= label }}
    else
        label = copyall(label)
    end
    if self.base_label then
        if label[1] then
            label[1].gap=self.option_gap
        end
        table.insert(label, 1, type(self.base_label) == "string" and { text= self.base_label } or self.base_label)
    end
    table.insert(label, 1, self.key ~= nil and {key=self.key, key_pen=self.key_pen, key_sep=self.key_sep, on_activate=self:callback('cycle')} or {})
    table.insert(label, 1, self.key_back ~= nil and {key=self.key_back, key_sep='', width=0, on_activate=self:callback('cycle', true)} or {})
    self:setText(label)
end

--================================--
--||        OptionsPopup        ||--
--================================--
-- Popup for more detailed options

OptionsPopup = defclass(OptionsPopup, widgets.Window)
OptionsPopup.ATTRS {
    name = "options_popup",
    frame_title = 'More Options',
    frame = POPUP_UI_AREA,
    frame_inset={b=1, t=1},
}

function OptionsPopup:init()
    local optionViews = {}
    local width = self.frame.w - 3

    local makeUIChars = function(center_char1, center_char2)
        return {
            {218, 196,          196,          191},
            {179, center_char1, center_char2, 179},
            {192, 196,          196,          217},
        }
    end
    local makeUIPen = function(border_pen, center_pen)
        return {
            border_pen,
            {border_pen, center_pen, center_pen, border_pen},
            border_pen,
        }
    end

    self.values = {}
    local height_offset = 0
    for key,option in pairs(MORE_OPTIONS) do
        self.values[key] = option.values[1].value
        local options = {}

        local addOption = function(value, pen, char1, char2, offset)
            table.insert(options, {
                value=value,
                label= makeInlineButtonLabelText{
                    left_specs={
                        chars={option.label},
                        pens=pen,
                        pens_hover=UI_COLORS.HIGHLIGHTED,
                    },
                    right_specs= {
                        chars=makeUIChars(char1, char2),
                        pens=makeUIPen(UI_COLORS.DESELECTED, pen),
                        pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, pen),
                        tileset=TILESET,
                        tileset_offset=offset,
                        tileset_stride=TILESET_STRIDE,
                    },
                    width=width
                },
            })
        end

        for _, value in pairs(option.values) do
            addOption(value.value, value.pen, value.char1, value.char2, value.offset)
        end

        table.insert(optionViews,
            CycleLabel {
                frame={l=1,t=height_offset},
                initial_option=option.values[1].value,
                options=options,
                on_change=function(value) self.values[key] = value end
            }
        )
        height_offset = height_offset + 3
    end

    self:addviews(optionViews)
end

--================================--
--||         TileConfig         ||--
--================================--
-- Tile config options

TileConfig = defclass(TileConfig, widgets.Widget)
TileConfig.ATTRS {
    data_lists=DEFAULT_NIL,
    on_change_shape=DEFAULT_NIL,
    on_change_mat=DEFAULT_NIL,
    on_change_stone=DEFAULT_NIL,
    on_change_vein_type=DEFAULT_NIL,
    on_change_special=DEFAULT_NIL,
    on_change_variant=DEFAULT_NIL,
}

function TileConfig:init()
    self.stone_enabled = false
    self.valid_combination = true

    local function getTextPen()
        return self.valid_combination and UI_COLORS.VALID_OPTION or UI_COLORS.INVALID_OPTION
    end

    local function getListOther(short_list)
        for i=1, #short_list do
            if short_list[i].value == short_list.other.value then
                return short_list.other
            end
        end
        table.insert(short_list, short_list.other)
        short_list.other.label = OTHER_LABEL_FORMAT.first..short_list.other.label..OTHER_LABEL_FORMAT.last
        return short_list.other
    end

    self.other_shape = getListOther(self.data_lists.short_shape_list)
    self.other_mat = getListOther(self.data_lists.short_mat_list)
    self.other_special = getListOther(self.data_lists.short_special_list)

    local config_btn_width = #CONFIG_BUTTON
    local config_btn_l = UI_AREA.w - 2 - config_btn_width

    self:addviews {
        widgets.CycleHotkeyLabel {
            view_id="shape_cycle",
            frame={l=1, r=config_btn_width, t=0},
            key_back='CUSTOM_SHIFT_H',
            key='CUSTOM_H',
            label='Shape:',
            options=self.data_lists.short_shape_list,
            initial_option=-1,
            on_change=function(value)
                self:updateValidity()
                if self.on_change_shape then
                    self.on_change_shape(value)
                end
            end,
            text_pen=getTextPen
        },
        widgets.Divider { frame={t=2}, frame_style_l=false, frame_style_r=false, },
        widgets.CycleHotkeyLabel {
            view_id="mat_cycle",
            frame={l=1, r=config_btn_width, t=4},
            key_back='CUSTOM_SHIFT_J',
            key='CUSTOM_J',
            label='Material:',
            options=self.data_lists.short_mat_list,
            initial_option=-1,
            on_change=function(value)
                self:updateValidity()
                if self.on_change_mat then
                    self.on_change_mat(value)
                end
            end,
            text_pen=getTextPen
        },
        widgets.HotkeyLabel {
            view_id="stone_label",
            frame={l=3, t=6},
            key='CUSTOM_N',
            label={ text= "Stone:", pen=function() return self.stone_enabled and UI_COLORS.HIGHLIGHTED or UI_COLORS.DESELECTED end },
            enabled=function() return self.stone_enabled end,
            on_activate=function() self:openStonePopup() end
        },
        CycleLabel {
            view_id="vein_type_label",
            frame={l=3, t=8},
            key='CUSTOM_I',
            base_label={ text= "Vein Type:", pen=function() return self.stone_enabled and UI_COLORS.HIGHLIGHTED or UI_COLORS.DESELECTED end },
            enabled=function() return self.stone_enabled end,
            initial_option=-1,
            options=self.data_lists.vein_type_list,
            on_change=self.on_change_vein_type,
        },
        widgets.Divider { frame={t=10}, frame_style_l=false, frame_style_r=false, },
        widgets.CycleHotkeyLabel {
            view_id="special_cycle",
            frame={l=1, r=config_btn_width, t=12},
            key_back='CUSTOM_SHIFT_K',
            key='CUSTOM_K',
            label='Special:',
            options=self.data_lists.short_special_list,
            initial_option=-1,
            on_change=function(value)
                self:updateValidity()
                if self.on_change_special then
                    self.on_change_special(value)
                end
            end,
            text_pen=getTextPen
        },
        widgets.Divider { frame={t=14}, frame_style_l=false, frame_style_r=false, },
        widgets.CycleHotkeyLabel {
            view_id="variant_cycle",
            frame={l=1, t=16},
            key_back='CUSTOM_SHIFT_L',
            key='CUSTOM_L',
            label='Variant:',
            options=self.data_lists.variant_list,
            initial_option=-1,
            on_change=function(value)
                self:updateValidity()
                if self.on_change_variant then
                    self.on_change_variant(value)
                end
            end,
            text_pen=getTextPen
        },
        widgets.Divider { frame={t=18}, frame_style_l=false, frame_style_r=false, },
    }

    -- Advanced config buttons
    self:addviews {
        -- Shape
        widgets.Label {
            frame={l=config_btn_l, t=0},
            text=CONFIG_BUTTON,
            on_click=function() self:openShapePopup() end,
        },
        -- Material
        widgets.Label {
            frame={l=config_btn_l, t=4},
            text=CONFIG_BUTTON,
            on_click=function() self:openMaterialPopup() end,
        },
        -- Special
        widgets.Label {
            frame={l=config_btn_l, t=12},
            text=CONFIG_BUTTON,
            on_click=function() self:openSpecialPopup() end,
        },
    }

    self:changeStone(-1)
    self:setVisibility(self.visible)
end

function TileConfig:openShapePopup()
    SelectDialog {
        frame_title = "Shape Values",
        base_category = "Shape",
        item_list = self.data_lists.shape_list,
        on_select = function(item)
            self.other_shape.label = OTHER_LABEL_FORMAT.first..item.label..OTHER_LABEL_FORMAT.last
            self.other_shape.value = item.value
            self.subviews.shape_cycle.option_idx=#self.subviews.shape_cycle.options
            self:updateValidity()
            self.on_change_shape(item.value)
        end,
    }:show()
end

function TileConfig:openMaterialPopup()
    SelectDialog {
        frame_title = "Material Values",
        base_category = "Material",
        item_list = self.data_lists.mat_list,
        on_select = function(item)
            self.other_mat.label = OTHER_LABEL_FORMAT.first..item.label..OTHER_LABEL_FORMAT.last
            self.other_mat.value = item.value
            self.subviews.mat_cycle.option_idx=#self.subviews.mat_cycle.options
            self:updateValidity()
            self.on_change_mat(item.value)
        end,
    }:show()
end

function TileConfig:openSpecialPopup()
    SelectDialog {
        frame_title = "Special Values",
        base_category = "Special",
        item_list = self.data_lists.special_list,
        on_select = function(item)
            self.other_special.label = OTHER_LABEL_FORMAT.first..item.label..OTHER_LABEL_FORMAT.last
            self.other_special.value = item.value
            self.subviews.special_cycle.option_idx=#self.subviews.special_cycle.options
            self:updateValidity()
            self.on_change_special(item.value)
        end,
    }:show()
end

function TileConfig:openStonePopup()
    SelectDialog {
        frame_title = "Stone Types",
        base_category = "Stone",
        item_list = self.data_lists.stone_list,
        on_select = function(value) self:changeStone(value) end,
    }:show()
end

function TileConfig:changeStone(stone_index)
    local stone_option = self.data_lists.stone_dict[-1]
    if stone_index then
        stone_option = self.data_lists.stone_dict[stone_index]
        self.on_change_stone(stone_option.value)
    end

    local label = self.subviews.stone_label
    local base_label = copyall(label.label)
    base_label.key = label.key
    base_label.key_sep = label.key_sep
    base_label.on_activate = label.on_activate
    label:setText({
        base_label,
        { gap=1, text=stone_option.label, pen=stone_option.pen }
    })
end

function TileConfig:setStoneEnabled(bool)
    self.stone_enabled = bool
    if not bool then
        self.subviews.vein_type_label:setOption(self.subviews.vein_type_label.initial_option)
        self:changeStone(nil)
    end
    self.subviews.vein_type_label:updateOptionLabel()
end

function TileConfig:setVisibility(visibility)
    self.frame = visibility and { h=19 } or { h=0 }
    self.visible = visibility
end

function TileConfig:updateValidity()
    local variant_value = self.subviews.variant_cycle:getOptionValue(self.subviews.variant_cycle.option_idx)
    local special_value = self.subviews.special_cycle:getOptionValue(self.subviews.special_cycle.option_idx)
    local mat_value = self.subviews.mat_cycle:getOptionValue(self.subviews.mat_cycle.option_idx)
    local shape_value = self.subviews.shape_cycle:getOptionValue(self.subviews.shape_cycle.option_idx)

    self.valid_combination = false
    for i=df.tiletype._first_item, df.tiletype._last_item do
        local name = df.tiletype[i]
        if name then
            local tile_attrs = df.tiletype.attrs[name]
            if (shape_value == df.tiletype_shape.NONE or tile_attrs.shape == shape_value)
                and (mat_value == df.tiletype_material.NONE or tile_attrs.material == mat_value)
                and (special_value == df.tiletype_special.NONE or tile_attrs.special == special_value or tile_attrs.special == df.tiletype_special.NONE)
                and (variant_value == df.tiletype_variant.NONE or tile_attrs.variant == variant_value or tile_attrs.variant == df.tiletype_variant.NONE)
            then
                self.valid_combination = true
                break
            end
        end
    end
end

--================================--
--||       TiletypeWindow       ||--
--================================--
-- Interface for editing tiles

TiletypeWindow = defclass(TiletypeWindow, widgets.Window)
TiletypeWindow.ATTRS {
    name = "tiletype_window",
    frame_title="Tiletypes",
    frame=UI_AREA,
    frame_inset={b=1, t=1},
    screen=DEFAULT_NIL,
    options_popup=DEFAULT_NIL,
    data_lists=DEFAULT_NIL,
}

function TiletypeWindow:init()
    self.cur_mode="paint"
    self.mode_description = ""
    self.cur_shape=-1
    self.cur_mat=-1
    self.cur_special=-1
    self.cur_variant=-1
    self.first_point=nil ---@type df.coord
    self.last_point=nil ---@type df.coord

    local makeUIChars = function(center_char1, center_char2)
        return {
            {218, 196,          196,          191},
            {179, center_char1, center_char2, 179},
            {192, 196,          196,          217},
        }
    end
    local makeUIPen = function(border_pen, center_pen)
        return {
            border_pen,
            {border_pen, center_pen, center_pen, border_pen},
            border_pen
        }
    end

    self:addviews {
        BoxSelection {
            view_id="box_selection",
            screen=self.screen,
            avoid_view=self,
            on_confirm=function() self:confirm() end,
        },
        widgets.ResizingPanel {
            frame={t=0},
            autoarrange_subviews=true,
            autoarrange_gap=1,
            subviews={
                widgets.ButtonGroup {
                    frame={l=1},
                    button_specs={
                        {
                            chars=makeUIChars(MODE_SETTINGS["paint"].char1, MODE_SETTINGS["paint"].char2),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, UI_COLORS.DESELECTED),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.HIGHLIGHTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["paint"].offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["replace"].char1, MODE_SETTINGS["replace"].char2),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, UI_COLORS.DESELECTED),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.HIGHLIGHTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["replace"].offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["fill"].char1, MODE_SETTINGS["fill"].char2),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, {fg=UI_COLORS.DESELECTED,bg=UI_COLORS.DESELECTED2}),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, {fg=UI_COLORS.HIGHLIGHTED,bg=UI_COLORS.HIGHLIGHTED2}),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["fill"].offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["remove"].char1, MODE_SETTINGS["remove"].char2),
                            pens=makeUIPen(UI_COLORS.DESELECTED_BORDER, UI_COLORS.DESELECTED),
                            pens_hover=makeUIPen(UI_COLORS.HIGHLIGHTED_BORDER, UI_COLORS.HIGHLIGHTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["remove"].offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                    },
                    button_specs_selected={
                        {
                            chars=makeUIChars(MODE_SETTINGS["paint"].char1, MODE_SETTINGS["paint"].char2),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, UI_COLORS.SELECTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["paint"].selected_offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["replace"].char1, MODE_SETTINGS["replace"].char2),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, UI_COLORS.SELECTED),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["replace"].selected_offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["fill"].char1, MODE_SETTINGS["fill"].char2),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, {fg=UI_COLORS.SELECTED,bg=UI_COLORS.SELECTED2}),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["fill"].selected_offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                        {
                            chars=makeUIChars(MODE_SETTINGS["remove"].char1, MODE_SETTINGS["remove"].char2),
                            pens=makeUIPen(UI_COLORS.SELECTED_BORDER, UI_COLORS.SELECTED2),
                            tileset=TILESET,
                            tileset_offset=MODE_SETTINGS["remove"].selected_offset,
                            tileset_stride=TILESET_STRIDE,
                        },
                    },
                    key_back='CUSTOM_SHIFT_M',
                    key='CUSTOM_M',
                    label='Mode:',
                    options=MODE_LIST,
                    initial_option=MODE_SETTINGS[self.cur_mode].idx,
                    on_change=function(value)
                        self:setMode(value)
                    end,
                },
                widgets.WrappedLabel {
                    frame={l=1},
                    text_to_wrap=function() return self.mode_description end
                },
                widgets.Divider { frame={h=1}, frame_style_l=false, frame_style_r=false, },
                TileConfig {
                    view_id="tile_config",
                    data_lists=self.data_lists,
                    on_change_shape=function(value)
                        self.cur_shape = value
                    end,
                    on_change_mat=function(value)
                        if value == df.tiletype_material.STONE then
                            self.subviews.tile_config:setStoneEnabled(true)
                            self.subviews.tile_config:changeStone(self.cur_stone)
                        else
                            self.subviews.tile_config:setStoneEnabled(false)
                        end
                        self.cur_mat = value
                    end,
                    on_change_stone=function(value)
                        self.cur_stone = value
                    end,
                    on_change_vein_type=function(value)
                        self.cur_vein_type = value
                    end,
                    on_change_special=function(value)
                        self.cur_special = value
                    end,
                    on_change_variant=function(value)
                        self.cur_variant = value
                    end
                },
                widgets.HotkeyLabel {
                    frame={l=1},
                    key='STRING_A059',
                    label='More Options',
                    on_activate=function()
                        self.options_popup.visible = not self.options_popup.visible
                    end
                }
            }
        },
    }

    self:setMode(self.cur_mode)
end

function TiletypeWindow:setMode(mode)
    self.cur_mode = mode
    local settings = MODE_SETTINGS[mode]
    self.mode_description = settings.description
    self.subviews.tile_config:setVisibility(settings.config)
    if self.frame_parent_rect then
        self:updateLayout()
    end
end

function TiletypeWindow:confirm()
    local box = self.subviews.box_selection.box

    if box then
        local settings = MODE_SETTINGS[self.cur_mode]
        local option_values = self.options_popup.values

        if self.cur_mode == "remove" then
            ---@type TileType
            local emptyTiletype = {
                shape          = df.tiletype_shape.EMPTY,
                material       = df.tiletype_material.AIR,
                special        = df.tiletype_special.NORMAL,
                hidden         = option_values.hidden,
                light          = option_values.light,
                subterranean   = option_values.subterranean,
                skyview        = option_values.skyview,
                aquifer        = option_values.aquifer,
                surroundings   = option_values.surroundings,
            }
            box:iterate(function(pos)
                if settings.validator(pos) then
                    setTile(pos, emptyTiletype)
                end
            end)
        else

            ---@type TileType
            local tiletype = {
                shape          = self.cur_shape,
                material       = self.cur_mat,
                special        = self.cur_special,
                variant        = self.cur_variant,
                hidden         = option_values.hidden,
                light          = option_values.light,
                subterranean   = option_values.subterranean,
                skyview        = option_values.skyview,
                aquifer        = option_values.aquifer,
                surroundings   = option_values.surroundings,
                stone_material = self.cur_stone,
                vein_type      = self.cur_vein_type,
            }
            box:iterate(function(pos)
                if settings.validator(pos) then
                    setTile(pos, tiletype)
                end
            end)
        end

        self.subviews.box_selection:clear()
    end
end

function TiletypeWindow:onInput(keys)
    if TiletypeWindow.super.onInput(self, keys) then
        return true
    end
    if keys.LEAVESCREEN or keys._MOUSE_R then
        if self.options_popup.visible then
            self.options_popup.visible = false
            return true
        end
        return false
    end

    -- send movement and pause keys through
    return not (keys.D_PAUSE or guidm.getMapKey(keys))
end

function TiletypeWindow:onDismiss()
    self.subviews.box_selection:hideCursor()
end

--================================--
--||       TiletypeScreen       ||--
--================================--
-- The base UI element that contains the visual widgets

TiletypeScreen = defclass(TiletypeScreen, gui.ZScreen)
TiletypeScreen.ATTRS {
    focus_path = "tiletypes",
    pass_pause = true,
    pass_movement_keys = true,
    unrestricted = false
}

function TiletypeScreen:init()
    self.data_lists = self:generateDataLists()

    local options_popup = OptionsPopup{
        view_id="options_popup",
        visible=false
    }
    self:addviews {
        TiletypeWindow {
            view_id="main_window",
            screen=self,
            options_popup=options_popup,
            data_lists = self.data_lists
        },
        options_popup
    }
end

function TiletypeScreen:generateDataLists()
    local function itemColor(name)
        return name == "NONE" and UI_COLORS.VALUE_NONE or UI_COLORS.VALUE
    end

    local function getEnumLists(enum, short_dict)
        list = {}
        short_list = {}

        for i=enum._first_item, enum._last_item do
            local name = enum[i]
            if name then
                local item = { label= name, value= i, pen= itemColor(name) }
                table.insert(list, { text=name, value=item })
                if short_dict then
                    if short_dict.all or short_dict[i] then
                        table.insert(short_list, item)
                    elseif short_dict.other == i then
                        short_list.other = copyall(item)
                    end
                end
            end
        end

        return list, short_list
    end

    local data_lists = {}
    data_lists.shape_list, data_lists.short_shape_list = getEnumLists(df.tiletype_shape, CYCLE_VALUES.shape)
    data_lists.mat_list, data_lists.short_mat_list = getEnumLists(df.tiletype_material, CYCLE_VALUES.material)
    data_lists.special_list, data_lists.short_special_list = getEnumLists(df.tiletype_special, CYCLE_VALUES.special)
    _, data_lists.variant_list = getEnumLists(df.tiletype_variant, { all = true})

    data_lists.stone_list = { { text = "none", value = -1 } }
    data_lists.stone_dict = { [-1] = { label= "NONE", value= -1, pen= itemColor("NONE") } }
    for i,mat in ipairs(df.global.world.raws.inorganics) do
        if mat and mat.material
            and not mat.flags[df.inorganic_flags.SOIL_ANY]
            and not mat.material.flags[df.material_flags.IS_METAL]
            and (self.unrestricted or not mat.flags[df.inorganic_flags.GENERATED])
        then
            local state = mat.material.heat.melting_point <= 10015 and 1 or 0
            local name = mat.material.state_name[state]:gsub('^frozen ',''):gsub('^molten ',''):gsub('^condensed ','')
            if mat.flags[df.inorganic_flags.GENERATED] then
                -- Position 2 so that it is located immediately after "none"
                if not data_lists.stone_list[2].item_list then
                    table.insert(data_lists.stone_list, 2, { text = "generated materials", category = "Generated", item_list = {} })
                end
                table.insert(data_lists.stone_list[2].item_list, { text = name, value = i })
            else
                table.insert(data_lists.stone_list, { text = name, value = i })
            end
            data_lists.stone_dict[i] = { label= mat.id, value= i, pen= itemColor(mat.id) }
        end
    end

    _, data_lists.vein_type_list = getEnumLists(df.inclusion_type, { all = true})
    table.insert(data_lists.vein_type_list, 1, { label= "NONE", value= -1, pen= itemColor("NONE") }) -- Equivalent to CLUSTER
    for _, value in pairs(data_lists.vein_type_list) do
        value.label = {{ text= value.label, pen= value.pen }}
    end

    return data_lists
end

function TiletypeScreen:onDismiss()
    view = nil
    for _,value in pairs(self.subviews) do
        if value.onDismiss then
            value:onDismiss()
        end
    end
end

--#endregion

function main(...)
    local args = {...}
    local positionals = argparse.processArgsGetopt(args, {
        { 'f', 'unrestricted', handler = function() args.unrestricted = true end },
    })

    if not dfhack.isMapLoaded() then
        qerror("This script requires a fortress map to be loaded")
    end

    view = view and view:raise() or TiletypeScreen{ unrestricted = args.unrestricted }:show()
end

if not dfhack_flags.module then
    main(...)
end
