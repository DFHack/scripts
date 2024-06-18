-- Visualize and inspect biome regions on the map.

local RELOAD = false -- set to true when actively working on this script

local gui = require('gui')
local widgets = require('gui.widgets')
local guidm = require('gui.dwarfmode')

local INITIAL_LIST_HEIGHT = 5
local INITIAL_INFO_HEIGHT = 15

local texturesOnOff8x12 = dfhack.textures.loadTileset('hack/data/art/on-off.png', 8, 12, true)
local LIST_ITEM_HIGHLIGHTED = dfhack.textures.getTexposByHandle(texturesOnOff8x12[1]) -- yellow-ish indicator

local texturesOnOff = dfhack.textures.loadTileset('hack/data/art/on-off_top-left.png', 32, 32, true)
local TILE_HIGHLIGHTED = dfhack.textures.getTexposByHandle(texturesOnOff[1]) -- yellow-ish indicator
if TILE_HIGHLIGHTED < 0 then -- use a fallback
    TILE_HIGHLIGHTED = 88 -- `X`
end

local texturesSmallLetters = dfhack.textures.loadTileset('hack/data/art/curses-small-letters_top-left.png', 32, 32, true)
local TILE_STARTING_SYMBOL = dfhack.textures.getTexposByHandle(texturesSmallLetters[1])
if TILE_STARTING_SYMBOL < 0 then -- use a fallback
    TILE_STARTING_SYMBOL = 97 -- `a`
end

local function find(t, predicate)
    for k, item in pairs(t) do
        if predicate(k, item) then
            return k, item
        end
    end
    return nil
end

local regionBiomeMap = {}
local biomesMap = {}
local biomeList = {}
local function gatherBiomeInfo(z)
    local maxX, maxY, maxZ = dfhack.maps.getTileSize()
    maxX = maxX - 1; maxY = maxY - 1; maxZ = maxZ - 1

    z = z or df.global.window_z

    --for z = 0, maxZ do
    for y = 0, maxY do
        for x = 0, maxX do
            local rgnX, rgnY = dfhack.maps.getTileBiomeRgn(x,y,z)
            if rgnX == nil then goto continue end

            local regionBiomesX = regionBiomeMap[rgnX]
            if not regionBiomesX then
                regionBiomesX = {}
                regionBiomeMap[rgnX] = regionBiomesX
            end
            local regionBiomesXY = regionBiomesX[rgnY]
            if not regionBiomesXY then
                regionBiomesXY = {
                    biomeTypeId = dfhack.maps.getBiomeType(rgnX, rgnY),
                    biome = dfhack.maps.getRegionBiome(rgnX, rgnY),
                }
                regionBiomesX[rgnY] = regionBiomesXY
            end

            local biomeTypeId = regionBiomesXY.biomeTypeId
            local biome = regionBiomesXY.biome

            local biomesZ = biomesMap[z]
            if not biomesZ then
                biomesZ = {}
                biomesMap[z] = biomesZ
            end
            local biomesZY = biomesZ[y]
            if not biomesZY then
                biomesZY = {}
                biomesZ[y] = biomesZY
            end

            local function currentBiome(_, item)
                return item.biome == biome
            end
            local ix = find(biomeList, currentBiome)
            if not ix then
                local ch = string.char(string.byte('a') + #biomeList)
                table.insert(biomeList, {biome = biome, char = ch, typeId = biomeTypeId})
                ix = #biomeList
            end

            biomesZY[x] = ix

            ::continue::
        end
    end
    --end
end

-- always gather info at the very bottom first: this ensures the important biomes are
-- always in the same order (high up in the air strange things happen)
gatherBiomeInfo(0)

--------------------------------------------------------------------------------

local TITLE = "Biomes"

if RELOAD then BiomeVisualizerLegend = nil end
BiomeVisualizerLegend = defclass(BiomeVisualizerLegend, widgets.Window)
BiomeVisualizerLegend.ATTRS {
    frame_title=TITLE,
    frame_inset=0,
    resizable=true,
    resize_min={w=25},
    frame = {
        w = 47,
        h = INITIAL_LIST_HEIGHT + 2 + INITIAL_INFO_HEIGHT,
        -- just under the minimap:
        r = 2,
        t = 18,
    },
}

local function GetBiomeName(biome, biomeTypeId)
    -- based on probe.cpp
    local sav = biome.savagery
    local evi = biome.evilness;
    local sindex = sav > 65 and 2 or sav < 33 and 0 or 1
    local eindex = evi > 65 and 2 or evi < 33 and 0 or 1
    local surr = sindex + eindex * 3 +1; --in Lua arrays are 1-based

    local surroundings = {
        "Serene", "Mirthful", "Joyous Wilds",
        "Calm", "Wilderness", "Untamed Wilds",
        "Sinister", "Haunted", "Terrifying"
    }

    return ([[%s %s]]):format(surroundings[surr], df.biome_type.attrs[biomeTypeId].caption)
end

function BiomeVisualizerLegend:init()
    local list = widgets.List{
        view_id = 'list',
        frame = { t = 1, b = INITIAL_INFO_HEIGHT + 1 },
        icon_width = 1,
        text_pen = { fg = COLOR_GREY, bg = COLOR_BLACK }, -- this makes selection stand out more
        on_select = self:callback('onSelectEntry'),
    }
    local tooltip_panel = widgets.Panel{
        view_id='tooltip_panel',
        autoarrange_subviews=true,
        frame = { b = 0, h = INITIAL_INFO_HEIGHT },
        frame_style=gui.INTERIOR_FRAME,
        frame_background=gui.CLEAR_PEN,
        subviews={
            widgets.Label{
                view_id='label',
                auto_height=false,
                scroll_keys={},
            },
        },
    }
    self:addviews{
        list,
        tooltip_panel,
    }

    self.list = list
    self.tooltip_panel = tooltip_panel

    self:UpdateChoices()
end

local PEN_ACTIVE_ICON = dfhack.pen.parse{tile=LIST_ITEM_HIGHLIGHTED}
local PEN_NO_ICON = nil

function BiomeVisualizerLegend:get_icon_pen_callback(ix)
    return function ()
        if self.SelectedIndex == ix then
            return PEN_ACTIVE_ICON
        else
            return PEN_NO_ICON
        end
    end
end

function BiomeVisualizerLegend:get_text_pen_callback(ix)
    return function ()
        if self.MapHoverIndex == ix then
            return self.SelectedIndex == ix
                and { fg = COLOR_BLACK, bg = COLOR_LIGHTCYAN }
                 or { fg = COLOR_BLACK, bg = COLOR_GREY }
        else
            return nil
        end
    end
end

function BiomeVisualizerLegend:onSelectEntry(idx, option)
    self.SelectedIndex = idx
    self.SelectedOption = option

    self:ShowTooltip(option)
end

function BiomeVisualizerLegend:UpdateChoices()
    local choices = self.list:getChoices() or {}
    for i = #choices + 1, #biomeList do
        local biomeExt = biomeList[i]
        table.insert(choices, {
            text = {{
                pen = self:get_text_pen_callback(#choices+1),
                text = ([[%s: %s]]):format(biomeExt.char, GetBiomeName(biomeExt.biome, biomeExt.typeId)),
            }},
            icon = self:get_icon_pen_callback(#choices+1),
            biomeTypeId = biomeExt.typeId,
            biome = biomeExt.biome,
        })
    end
    self.list:setChoices(choices)
end

function BiomeVisualizerLegend:onRenderFrame(dc, rect)
    BiomeVisualizerLegend.super.onRenderFrame(self, dc, rect)

    local list = self.list
    local currentHoverIx = list:getIdxUnderMouse()
    local oldIx = self.HoverIndex
    if currentHoverIx ~= oldIx then
        self.HoverIndex = currentHoverIx
        if self.onMouseHoverEntry then
            local choices = list:getChoices()
            self:onMouseHoverEntry(currentHoverIx, choices[currentHoverIx])
        end
    end
end

local function add_field_text(lines, biome, field_name)
    lines[#lines+1] = ("%s: %s"):format(field_name, biome[field_name])
    lines[#lines+1] = NEWLINE
end

local function get_tooltip_text(option)
    if not option then
        return ""
    end

    local text = {}
    text[#text+1] = ("type: %s"):format(df.biome_type[option.biomeTypeId])
    text[#text+1] = NEWLINE

    local biome = option.biome

    add_field_text(text, biome, "savagery")
    add_field_text(text, biome, "evilness")
    table.insert(text, NEWLINE)

    add_field_text(text, biome, "elevation")
    add_field_text(text, biome, "rainfall")
    add_field_text(text, biome, "drainage")
    add_field_text(text, biome, "vegetation")
    add_field_text(text, biome, "temperature")
    add_field_text(text, biome, "volcanism")
    table.insert(text, NEWLINE)

    local flags = biome.flags
    if flags.is_lake then
        text[#text+1] = "lake"
        text[#text+1] = NEWLINE
    end
    if flags.is_brook then
        text[#text+1] = "brook"
        text[#text+1] = NEWLINE
    end

    return text
end

function BiomeVisualizerLegend:onMouseHoverEntry(idx, option)
    self:ShowTooltip(option or self.SelectedOption)
end

function BiomeVisualizerLegend:ShowTooltip(option)
    local text = get_tooltip_text(option)

    local tooltip_panel = self.tooltip_panel
    local lbl = tooltip_panel.subviews.label

    lbl:setText(text)
end

function BiomeVisualizerLegend:onRenderBody(painter)
    local thisPos = self:getMouseFramePos()
    local pos = dfhack.gui.getMousePos()

    if not thisPos and pos then
        local N = safe_index(biomesMap, pos.z, pos.y, pos.x)
        if N then
            local choices = self.list:getChoices()
            local option = choices[N]

            self.MapHoverIndex = N
            self:ShowTooltip(option)
        end
    else
        self.MapHoverIndex = nil
    end

    BiomeVisualizerLegend.super.onRenderBody(self, painter)
end

--------------------------------------------------------------------------------

if RELOAD then BiomeVisualizer = nil end
BiomeVisualizer = defclass(BiomeVisualizer, gui.ZScreen)
BiomeVisualizer.ATTRS{
    focus_path='BiomeVisualizer',
    pass_movement_keys=true,
}

function BiomeVisualizer:init()
    local legend = BiomeVisualizerLegend{view_id = 'legend'}
    self:addviews{legend}
end

function BiomeVisualizer:onRenderFrame(dc, rect)
    BiomeVisualizer.super.onRenderFrame(self, dc, rect)

    if not dfhack.screen.inGraphicsMode() and not gui.blink_visible(500) then
        return
    end

    local z = df.global.window_z
    if not biomesMap[z] then
        gatherBiomeInfo(z)
        self.subviews.legend:UpdateChoices()
    end

    local function get_overlay_pen(pos)
        local self = self
        local safe_index = safe_index
        local biomes = biomesMap

        local N = safe_index(biomes, pos.z, pos.y, pos.x)
        if not N then return end

        local idxSelected = self.subviews.legend.SelectedIndex
        local idxTile = (N == idxSelected)
                    and TILE_HIGHLIGHTED
                    or TILE_STARTING_SYMBOL + (N-1)
        local color = (N == idxSelected)
                    and COLOR_CYAN
                    or COLOR_GREY
        local ch = string.char(string.byte('a') + (N-1))
        return color, ch, idxTile
    end

    guidm.renderMapOverlay(get_overlay_pen, nil) -- nil for bounds means entire viewport
end

function BiomeVisualizer:onDismiss()
    view = nil
end

if not dfhack.isMapLoaded() then
    qerror('gui/biomes requires a map to be loaded')
end

if RELOAD and view then
    view:dismiss()
    -- view is nil now
end

view = view and view:raise() or BiomeVisualizer{}:show()
