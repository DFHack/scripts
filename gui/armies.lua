
local gui = require('gui')
local widgets = require('gui.widgets')
local utils = require('utils')
local repeatUtil = require('repeat-util')

local visible_armies = {}

local timerId = 'testoverlay'

local function getMapPortTopLeftXY()
    local player_army = df.army.find(df.global.adventure.player_army_id)
    if not player_army then return 0,0 end

    local main_map_port = df.global.gps.main_map_port
    local screen_center_x, screen_center_y = main_map_port.screen_x, main_map_port.screen_y

    local px, py = player_army.pos.x, player_army.pos.y
    
    local site_level_zoom = df.global.adventure.site_level_zoom
    if site_level_zoom == 0 then
        px, py = math.floor(px/3), math.floor(py/3)
    end
    local top_left_x, top_left_y = px - screen_center_x, py - screen_center_y

    return top_left_x, top_left_y
end

local last_tick = 0
local function onTick()
    last_tick = df.global.cur_year_tick_advmode
    visible_armies = {}

    local site_level_zoom = df.global.adventure.site_level_zoom
    local top_left_x, top_left_y = getMapPortTopLeftXY()

    for _, army in pairs(df.global.world.armies.all) do
        if army.flags.player then goto continue end
        local x, y = army.pos.x, army.pos.y
        if site_level_zoom == 0 then
            x, y = math.floor(x/3), math.floor(y/3)
        end
        local adjusted_x, adjusted_y = x - top_left_x, y - top_left_y
        table.insert(visible_armies, {x=adjusted_x, y=adjusted_y})
        :: continue ::
    end
end

ArmyOverlay = defclass(ArmyOverlay, widgets.Window)
ArmyOverlay.ATTRS {
    frame_title='Army Overlay',
    frame={b = 4, r = 4, w = 50, h = 12},
    visible=true
}

function ArmyOverlay:init()
    self:addviews{
        widgets.HotkeyLabel{
            frame={l=0, t=0},
            label='Force Update',
            key='CUSTOM_U',
            -- auto_width=true,
            on_activate=function()
                onTick()
            end,
        },
        widgets.HotkeyLabel{
            frame={l=0, t=2},
            label='Teleport Self to Cursor',
            key='CUSTOM_T',
            on_activate=function()
                local player_army = df.army.find(df.global.adventure.player_army_id)
                if not player_army then return end
                local mouse_x, mouse_y = math.floor(df.global.gps.precise_mouse_x / 16), math.floor(df.global.gps.precise_mouse_y / 16)
                local site_level_zoom = df.global.adventure.site_level_zoom

                local top_left_x, top_left_y = getMapPortTopLeftXY()
                local x, y = mouse_x + top_left_x, mouse_y + top_left_y
                if site_level_zoom == 0 then
                    x, y = x*3, y*3
                end
                player_army.pos.x = x
                player_army.pos.y = y
                onTick()
            end,
        },
    }
end

local army_pen = {ch='*', fg=COLOR_GRAY, tile=dfhack.screen.findGraphicsTile('WORLD_MAP_ARMIES', 2, 0)}
function ArmyOverlay:onRenderFrame(painter, rect)
    ArmyOverlay.super.onRenderFrame(self, painter, rect)
    if last_tick ~= df.global.cur_year_tick_advmode then
        onTick()
    end
    for _, army in pairs(visible_armies) do
        dfhack.screen.paintTileMapPort(army_pen, army.x, army.y, army_pen.ch, army_pen.tile)
    end
end

ArmyOverlayScreen = defclass(ArmyOverlayScreen, gui.ZScreen)
ArmyOverlayScreen.ATTRS {
    focus_path = 'ArmyOverlay',
    pass_movement_keys = true,
    pass_mouse_clicks = true,
}

function ArmyOverlayScreen:init()
    self:addviews{ArmyOverlay{}}
    onTick()
end

function ArmyOverlayScreen:onDismiss()
    view = nil
end

view = view and view:raise() or ArmyOverlayScreen{}:show()
