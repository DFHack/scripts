---@diagnostic disable: missing-fields

local gui = require('gui')
local widgets = require('gui.widgets')

local roads = reqscript('internal/export-world-map/export-roads')
local layers = reqscript('internal/export-world-map/export-layers')
local pops = reqscript('internal/export-world-map/export-pops')

---@type df.viewscreen_choose_start_sitest
local viewscreen = dfhack.gui.getDFViewscreen(true)

if not df.viewscreen_choose_start_sitest:is_instance(viewscreen) then
    qerror("Tool must be used while choosing an embark location.")
    return
end

ExportMap = defclass(ExportMap, widgets.Window)
ExportMap.ATTRS {
    frame_title='Export World Map',
    frame={w=58, h=25},
    resizable=false,
}

local function getLoadedTileRatio()
    return #df.global.world.world_data.midmap_data.region_details,
            df.global.world.world_data.world_width * df.global.world.world_data.world_height
end

function ExportMap:updateRatio()
    cur,max = getLoadedTileRatio()
    self.subviews.midmap_ratio:setText(
        ("%d out of %d region tiles loaded"):format(cur,max)
    )
end

function ExportMap:initializeMapScan()
    local pixel_x = df.global.gps.screen_pixel_x
    local pixel_y = df.global.gps.screen_pixel_y
    local tile_x = dfhack.screen.inGraphicsMode() and 16 or df.global.gps.tile_pixel_x
    local tile_y = dfhack.screen.inGraphicsMode() and 16 or df.global.gps.tile_pixel_y

    -- conservative approximation of screen dimensions in tiles
    self.screen_w = (pixel_x // tile_x) - 2
    self.screen_h = (pixel_y // tile_y) - 2

    -- ensure that we are zoomed in
    viewscreen.zoomed_in = true

    viewscreen.zoom_cent_x = self.screen_w // 2
    viewscreen.zoom_cent_y = self.screen_h // 2

    self.done = false
end



-- keep scrolling around, until the entire world has been covered
function ExportMap:onRenderBody(painter)
    self:updateRatio()
    if self.done then
        return
    end
    if viewscreen.zoom_cent_x + self.screen_w // 2 < df.global.world.world_data.world_width * 16 then
        viewscreen.zoom_cent_x = viewscreen.zoom_cent_x + self.screen_w
    elseif viewscreen.zoom_cent_y + self.screen_h // 2 < df.global.world.world_data.world_height * 16 then
        viewscreen.zoom_cent_x = self.screen_w // 2
        viewscreen.zoom_cent_y = viewscreen.zoom_cent_y + self.screen_h
    else
        self.done = true
    end
end

---@param by_world boolean
---@param by_date boolean
---@param fn fun(boolean,boolean):(string|fun():nil)
local function invokeExport(by_world, by_date, fn)
    local command = fn(by_world, by_date)
    if type(command) == "string" then
        dfhack.run_command(command)
    else
        command()
    end
end

function ExportMap:startExports()
    local by_date = self.subviews.by_date:getOptionValue()
    local by_world = by_date or self.subviews.by_world:getOptionValue()

    for _, export in ipairs(exports) do
        if export.enabled then
            invokeExport(by_world, by_date, export.command)
        end
    end
end

---generate wrapper for invoking the C++ plugin
---@param export string
---@return fun(boolean,boolean):string
local function pluginCommand(export)
    return function(by_world, by_date)
        -- grouping by date implies grouping by world
        return ('export-world-map %s %s'):format(by_date and '--group-by-date' or (by_world and '--group-by-world' or ''), export)
    end
end

exports = {
    { id = 1, key = 'regions', desc = 'Region Map Export (regions.csv)' , enabled = true, command = pluginCommand("regions") },
    { id = 2, key = 'rivers', desc = 'River Export (rivers.csv)' , enabled = true, command = pluginCommand("rivers") },
    { id = 3, key = 'sites', desc = 'Site Export (sites.csv)' , enabled = true, command = pluginCommand("sites") },
    { id = 4, key = 'elevation', desc = 'Elevation Grid Export (elevation.dat, elevation.vrt)' , enabled = true, command = pluginCommand("elevation") },
    { id = 5, key = 'roads', desc = 'Road Export (roads.geojson)' , enabled = true, command = roads.export },
    { id = 6, key = 'layers', desc = 'Export Geological Layers (layers.csv)' , enabled = true, command = layers.export },
    { id = 7, key = 'pops', desc = 'Export Plant and Animal Populations (*_pops.csv)' , enabled = true, command = pops.export }
}

local SELECTED_ICON = dfhack.pen.parse{ch=string.char(251), fg=COLOR_LIGHTGREEN}
local DISABLED_ICON = dfhack.pen.parse{ch='x', fg=COLOR_RED}

function ExportMap:getChoices()
    print("getChoices")
    local choices = {}
    for _, export in ipairs(exports) do
        table.insert(choices, {
            icon = function()
                return export.enabled and SELECTED_ICON or DISABLED_ICON
            end,
            text = export.desc,
            id = export.id
        })
    end
    return choices
end

function ExportMap:toggleExport(_, choice)
    exports[choice.id].enabled = not exports[choice.id].enabled
    self:updateLayout()
end

function ExportMap:init()
    self.done = true
    self:addviews{
        widgets.Label{
            frame = { t = 1 },
            view_id = 'midmap_ratio',
            text = "counting..."
        },
        widgets.TextButton{
            frame = { w = 22, h = 1 , t = 3 },
            label = "Load Region Details!",
            on_click = self:callback('initializeMapScan')
        },
        widgets.Divider{
            frame = { t = 5, h = 1 },
            frame_style_l = false,
            frame_style_r = false
        },
        widgets.Label{
            frame={ t = 7 , h = 1 },
            text = "Select exports to place in dfhack-config/map-export:",
        },
        widgets.List{
            frame={t=9, h = #exports},
            view_id = "export_list",
            on_submit=self:callback("toggleExport"),
            icon_width = 2,
            choices = self:getChoices(),
        },
        widgets.CycleHotkeyLabel{
            view_id = 'by_world',
            key = 'CUSTOM_W',
            frame = { w = 40, h = 1 , t = #exports + 10, l = 0 },
            options = { { label = 'Yes' , value = true, pen = COLOR_LIGHTGREEN}, { label = 'No' , value = false} },
            initial_option = false,
            label = "Create folder for world name",
            on_change = function(new, _)
                if not new then
                    self.subviews.by_date:setOption(false)
                end
            end
        },
        widgets.CycleHotkeyLabel{
            view_id = 'by_date',
            key = 'CUSTOM_D',
            frame = { w = 40, h = 1 , t = #exports + 11, l = 0 },
            options = { { label = 'Yes' , value = true, pen = COLOR_LIGHTGREEN}, { label = 'No' , value = false} },
            initial_option = false,
            label = "Create subfolder for world date",
            on_change = function(new, _)
                if new then
                    self.subviews.by_world:setOption(true)
                end
            end
        },
        widgets.TextButton{
            frame = { w = 18, h = 1 , t = #exports + 13 },
            label = "Run Map Exports!",
            on_click = self:callback('startExports'),
            enabled = function()
                local cur,max = getLoadedTileRatio()
                return cur == max
            end
        }
    }
    self:updateRatio()
end

ExportMapScreen = defclass(ExportMapScreen, gui.ZScreen)
ExportMapScreen.ATTRS {
    focus_path='PopulateMidmap',
}

function ExportMapScreen:init()
    self:addviews{ExportMap{}}
end

function ExportMapScreen:onDismiss()
    view = nil
end

view = view and view:raise() or ExportMapScreen{}:show()
