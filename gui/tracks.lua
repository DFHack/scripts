local repeatUtil = require('repeat-util')

local utils = require('utils')
local gui = require('gui')
local widgets = require('gui.widgets')
local guidm = require('gui.dwarfmode')
local world_map = df.global.world.map
local adventure = df.global.adventure

local to_pen = dfhack.pen.parse
local others_track = to_pen{
    ch='+',
    fg=COLOR_YELLOW,
    tile=dfhack.screen.findGraphicsTile('CURSORS', 5, 23),
}

local yours_track = to_pen{
    ch='+',
    fg=COLOR_CYAN,
    tile=dfhack.screen.findGraphicsTile('CURSORS', 5, 22),
}

--tile=dfhack.screen.findGraphicsTile('INTERFACE_BITS_BUILDING_PLACEMENT', 1, 0)
local pen_direction = {
    to_pen{ch='v',fg=COLOR_YELLOW,}, -- tile=dfhack.screen.findGraphicsTile('ROLLERS', 8, 2),},     -- 0 South
    to_pen{ch='>',fg=COLOR_YELLOW,}, -- tile=dfhack.screen.findGraphicsTile('ROLLERS', 7, 2),},     -- 1 East
    to_pen{ch='\xbf',fg=COLOR_YELLOW,}, -- tile=dfhack.screen.findGraphicsTile('ROLLERS', 5, 2),},  -- 2 NorthWest
    to_pen{ch='<',fg=COLOR_YELLOW,}, -- tile=dfhack.screen.findGraphicsTile('ROLLERS', 6, 2),},     -- 3 West
    to_pen{ch='\xda',fg=COLOR_YELLOW,}, -- tile=dfhack.screen.findGraphicsTile('ROLLERS', 4, 2),},  -- 4 NorthEast
    to_pen{ch='\xd9',fg=COLOR_YELLOW,}, -- tile=dfhack.screen.findGraphicsTile('ROLLERS', 2, 2),},  -- 5 SouthEast
    to_pen{ch='\xc0',fg=COLOR_YELLOW,}, -- tile=dfhack.screen.findGraphicsTile('ROLLERS', 3, 2),},  -- 6 SouthWest
    to_pen{ch='^',fg=COLOR_YELLOW,}, -- tile=dfhack.screen.findGraphicsTile('ROLLERS', 9, 2),},     -- 7 North
}
local function get_directional_pen(dir)
    return pen_direction[dir] or pen_direction[8]
end

local visible_tracks = {}

local timerId = 'testoverlay'
local function onTimer()
    visible_tracks = {}
    for i=0, adventure.tracks_next_idx do
        local x = (adventure.tracks_x[i] - world_map.region_x*48)
        local y = (adventure.tracks_y[i] - world_map.region_y*48)
        local z = (adventure.tracks_z[i] - world_map.region_z)
        if dfhack.maps.isTileVisible(x,y,z) then
            local block = dfhack.maps.getTileBlock(x,y,z)
            -- "pile" = "lit" and "dig=1" = "visible" in adventure mode
            if block.designation[x%16][y%16].pile then
                for _, event in pairs(block.block_events) do
                    if getmetatable(event) == "block_square_event_spoorst" then
                        local flags = event.flags[x%16][y%16]
                        if flags.present then
                            table.insert(visible_tracks, {x=x, y=y, z=z, flags=flags})
                        end
                    end
                end
            end
        end
    end
end

TestOverlay = defclass(TestOverlay, widgets.Window)
TestOverlay.ATTRS {
    default_pos={x=20, y=0},
    default_enabled=true,
    frame_title='Test Overlay',
    frame={b = 4, r = 4, w = 50, h = 12},
    viewscreens= {
        'dungeonmode/Default',
    },
}

function TestOverlay:getLabel()
    local pos = dfhack.world.getAdventurer().pos
    local adv_x, adv_y, adv_z = pos.x, pos.y, pos.z
    return ("Your position: %s, %s, %s"):format(
        adv_x, adv_y, adv_z
    )
end

function TestOverlay:init()
    self.directional = false
    self.show_yours = true
    self.show_others = true
    self:addviews{
        widgets.Label{
            frame = {l = 0, t = 0},
            text = {{ text = self:callback('getLabel') }}
        },
        widgets.ToggleHotkeyLabel{
            frame={l = 0, t = 2},
            label='Show Directions',
            key='CUSTOM_CTRL_D',
            options={{value=true, label="Enabled"},
                     {value=false, label="Disabled"}},
            initial_option = self.directional,
            on_change=function(option) self.directional = option end
        },
        widgets.ToggleHotkeyLabel{
            frame={l = 0, t = 3},
            label='Show Your Tracks',
            key='CUSTOM_CTRL_Y',
            options={{value=true, label="Enabled"},
                     {value=false, label="Disabled"}},
            initial_option = self.show_yours,
            on_change=function(option) self.show_yours = option end
        },
        widgets.ToggleHotkeyLabel{
            frame={l = 0, t = 4},
            label='Show Other Tracks',
            key='CUSTOM_CTRL_O',
            options={{value=true, label="Enabled"},
                     {value=false, label="Disabled"}},
            initial_option = self.show_others,
            on_change=function(option) self.show_others = option end
        },
    }
end

function TestOverlay:onRenderFrame(dc, rect)
    TestOverlay.super.onRenderFrame(self, dc, rect)

    for i, track in pairs(visible_tracks) do
        if track.z ~= df.global.window_z then goto continue end
        local track_xyz = {
            x1 = track.x, x2 = track.x,
            y1 = track.y, y2 = track.y,
            z1 = track.z, z2 = track.z
        }
        local pen = others_track
        if track.flags.yours then
            if not self.show_yours then goto continue end
            pen = yours_track
        else
            if not self.show_others then goto continue end
        end
        if track.flags.has_direction and self.directional then
            pen = get_directional_pen(track.flags.direction)
        end
        guidm.renderMapOverlay(function() return pen end, track_xyz)
        ::continue::
    end
end

TestScreen = defclass(TestScreen, gui.ZScreen)
TestScreen.ATTRS {
    focus_path='testscreen',
    pass_movement_keys=true,
    pass_mouse_clicks=true,
}

function TestScreen:init()
    local window = TestOverlay{}
    self:addviews{
        window,
    }
    onTimer()
    repeatUtil.scheduleEvery(timerId, 1, 'ticks', onTimer)
    df.global.adventure.view_tracks_odors.DISPLAY_LATEST = true
    df.global.adventure.view_tracks_odors.DISPLAY_ODOR = true
end

function TestScreen:onDismiss()
    view = nil
    repeatUtil.cancel(timerId)
    df.global.adventure.view_tracks_odors.DISPLAY_LATEST = false
    df.global.adventure.view_tracks_odors.DISPLAY_ODOR = false
end

if dfhack_flags.module then
    return
end

if not dfhack.isMapLoaded() then
    qerror('This script requires a map to be loaded')
end

view = view and view:raise() or TestScreen{}:show()