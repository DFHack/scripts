-- Overlay to allow changing track stop friction and dump direction after construction
--@ module = true

if not dfhack_flags.module then
  qerror('trackstop cannot be called directly')
end

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')
local utils = require('utils')

local NORTH = 'North ^'
local EAST = 'East >'
local SOUTH = 'South v'
local WEST = 'West <'

local LOW = 'Low'
local MEDIUM = 'Medium'
local HIGH = 'High'
local HIGHER = 'Higher'
local MAX = 'Max'

local NONE = 'None'

local FRICTION_MAP = {
  [NONE] = 10,
  [LOW] = 50,
  [MEDIUM] = 500,
  [HIGH] = 10000,
  [MAX] = 50000,
}

local FRICTION_MAP_REVERSE = utils.invert(FRICTION_MAP)

local SPEED_MAP = {
  [LOW] = 10000,
  [MEDIUM] = 20000,
  [HIGH] = 30000,
  [HIGHER] = 40000,
  [MAX] = 50000,
}

local SPEED_MAP_REVERSE = utils.invert(SPEED_MAP)

local DIRECTION_MAP = {
  [NORTH] = df.screw_pump_direction.FromSouth,
  [EAST] = df.screw_pump_direction.FromWest,
  [SOUTH] = df.screw_pump_direction.FromNorth,
  [WEST] = df.screw_pump_direction.FromEast,
}

local DIRECTION_MAP_REVERSE = utils.invert(DIRECTION_MAP)

local function swapElements(tbl, index1, index2)
  tbl[index1], tbl[index2] = tbl[index2], tbl[index1]
  return tbl
end

local function reset_guide_paths(conditions)
  for _, condition in ipairs(conditions) do
    local gpath = condition.guide_path

    if gpath then
      gpath.x:resize(0)
      gpath.y:resize(0)
      gpath.z:resize(0)
    end
  end
end

TrackStopOverlay = defclass(TrackStopOverlay, overlay.OverlayWidget)
TrackStopOverlay.ATTRS{
  default_pos={x=-73, y=29},
  default_enabled=true,
  viewscreens='dwarfmode/ViewSheets/BUILDING/Trap/TrackStop',
  frame={w=25, h=4},
  frame_style=gui.MEDIUM_FRAME,
  frame_background=gui.CLEAR_PEN,
}

function TrackStopOverlay:getFriction()
  return dfhack.gui.getSelectedBuilding().friction
end

function TrackStopOverlay:setFriction(friction)
  local building = dfhack.gui.getSelectedBuilding()

  building.friction = FRICTION_MAP[friction]
end

function TrackStopOverlay:getDumpDirection()
  local building = dfhack.gui.getSelectedBuilding()
  local use_dump = building.use_dump
  local dump_x_shift = building.dump_x_shift
  local dump_y_shift = building.dump_y_shift

  if use_dump == 0 then
    return NONE
  else
    if dump_x_shift == 0 and dump_y_shift == -1 then
      return NORTH
    elseif dump_x_shift == 1 and dump_y_shift == 0 then
      return EAST
    elseif dump_x_shift == 0 and dump_y_shift == 1 then
      return SOUTH
    elseif dump_x_shift == -1 and dump_y_shift == 0 then
      return WEST
    end
  end
end

function TrackStopOverlay:setDumpDirection(direction)
  local building = dfhack.gui.getSelectedBuilding()

  if direction == NONE then
    building.use_dump = 0
    building.dump_x_shift = 0
    building.dump_y_shift = 0
  elseif direction == NORTH then
    building.use_dump = 1
    building.dump_x_shift = 0
    building.dump_y_shift = -1
  elseif direction == EAST then
    building.use_dump = 1
    building.dump_x_shift = 1
    building.dump_y_shift = 0
  elseif direction == SOUTH then
    building.use_dump = 1
    building.dump_x_shift = 0
    building.dump_y_shift = 1
  elseif direction == WEST then
    building.use_dump = 1
    building.dump_x_shift = -1
    building.dump_y_shift = 0
  end
end

function TrackStopOverlay:render(dc)
  local building = dfhack.gui.getSelectedBuilding(true)
  if not building then
    return
  end

  local friction = building.friction
  local friction_cycle = self.subviews.friction

  friction_cycle:setOption(FRICTION_MAP_REVERSE[friction])

  self.subviews.dump_direction:setOption(self:getDumpDirection())

  TrackStopOverlay.super.render(self, dc)
end

function TrackStopOverlay:init()
  self:addviews{
    widgets.CycleHotkeyLabel{
      frame={t=0, l=0},
      label='Dump',
      key='CUSTOM_CTRL_X',
      options={
        {label=NONE, value=NONE, pen=COLOR_BLUE},
        NORTH,
        EAST,
        SOUTH,
        WEST,
      },
      view_id='dump_direction',
      on_change=function(val) self:setDumpDirection(val) end,
    },
    widgets.CycleHotkeyLabel{
      label='Friction',
      frame={t=1, l=0},
      key='CUSTOM_CTRL_F',
      options={
        {label=NONE, value=NONE, pen=COLOR_BLUE},
        {label=LOW, value=LOW, pen=COLOR_GREEN},
        {label=MEDIUM, value=MEDIUM, pen=COLOR_YELLOW},
        {label=HIGH, value=HIGH, pen=COLOR_LIGHTRED},
        {label=MAX, value=MAX, pen=COLOR_RED},
      },
      view_id='friction',
      on_change=function(val) self:setFriction(val) end,
    },
  }
end

RollerOverlay = defclass(RollerOverlay, overlay.OverlayWidget)
RollerOverlay.ATTRS{
  default_pos={x=-71, y=29},
  default_enabled=true,
  viewscreens='dwarfmode/ViewSheets/BUILDING/Rollers',
  frame={w=27, h=4},
  frame_style=gui.MEDIUM_FRAME,
  frame_background=gui.CLEAR_PEN,
}

function RollerOverlay:getDirection()
  local building = dfhack.gui.getSelectedBuilding()
  local direction = building.direction

  return DIRECTION_MAP_REVERSE[direction]
end

function RollerOverlay:setDirection(direction)
  local building = dfhack.gui.getSelectedBuilding()

  building.direction = DIRECTION_MAP[direction]
end

function RollerOverlay:getSpeed()
  local building = dfhack.gui.getSelectedBuilding()
  local speed = building.speed

  return SPEED_MAP_REVERSE[speed]
end

function RollerOverlay:setSpeed(speed)
  local building = dfhack.gui.getSelectedBuilding()

  building.speed = SPEED_MAP[speed]
end

function RollerOverlay:render(dc)
  local building = dfhack.gui.getSelectedBuilding(true)
  if not building then
    return
  end

  self.subviews.direction:setOption(DIRECTION_MAP_REVERSE[building.direction])
  self.subviews.speed:setOption(SPEED_MAP_REVERSE[building.speed])

  TrackStopOverlay.super.render(self, dc)
end

function RollerOverlay:init()
  self:addviews{
    widgets.CycleHotkeyLabel{
      label='Direction',
      frame={t=0, l=0},
      key='CUSTOM_CTRL_X',
      options={NORTH, EAST, SOUTH, WEST},
      view_id='direction',
      on_change=function(val) self:setDirection(val) end,
    },
    widgets.CycleHotkeyLabel{
      label='Speed',
      frame={t=1, l=0},
      key='CUSTOM_CTRL_F',
      options={
        {label=LOW, value=LOW, pen=COLOR_BLUE},
        {label=MEDIUM, value=MEDIUM, pen=COLOR_GREEN},
        {label=HIGH, value=HIGH, pen=COLOR_YELLOW},
        {label=HIGHER, value=HIGHER, pen=COLOR_LIGHTRED},
        {label=MAX, value=MAX, pen=COLOR_RED},
      },
      view_id='speed',
      on_change=function(val) self:setSpeed(val) end,
    },
  }
end

ReorderStopsWindow = defclass(ReorderStopsWindow, widgets.Window)
ReorderStopsWindow.ATTRS {
  frame={t=4,l=60,w=45, h=28},
  frame_title='Reorder Stops',
  resizable=true,
}

local SELECT_STOP_HINT = 'Select a stop to move'
local SELECT_ANOTHER_STOP_HINT = 'Select another stop on the same route'

function ReorderStopsWindow:init()
  self.selected_stop = nil
  self:addviews{
    widgets.Label{
      frame={t=0,l=0},
      view_id='hint',
      text=SELECT_STOP_HINT,
    },
    widgets.List{
      view_id='routes',
      frame={t=1,l=1},
      choices={},
      on_select=function(_, item)
        if not item then return end
        if item.type == 'stop' then
          local item_pos = df.global.plotinfo.hauling.routes[item.route_index].stops[item.stop_index].pos
          dfhack.gui.revealInDwarfmodeMap(item_pos, true, true)
        end
      end,
      on_submit=function(index, item)
        if self.selected_stop then
          local hauling = df.global.plotinfo.hauling
          local routes = hauling.routes
          local view_stops = hauling.view_stops
          local route = routes[item.route_index]

          -- rearrange stops
          if item.type == 'stop' then
            local stop_index = item.stop_index

            -- don't allow moving stops to a different route for now. TODO: investigate this
            if self.selected_stop.route_index ~= item.route_index then
              return
            end

            swapElements(route.stops, stop_index, self.selected_stop.stop_index)
            swapElements(view_stops, self.selected_stop.list_position, index - 1)

            -- loop over each stop in the route, make the ids sequental and reset guide paths
            -- TODO: figure out if changing the ids here breaks anything else
            for i, stop in ipairs(route.stops) do
              stop.id = i + 1
              reset_guide_paths(stop.conditions)
            end

            self.selected_stop = nil
          end
        else
          if item.stop_index then
            self.selected_stop = item
          end
        end

        self:updateList()
      end,
    },
  }

  self:updateList()
end

function ReorderStopsWindow:updateList()
  local routes = df.global.plotinfo.hauling.routes
  local choices = {}
  local list_position = 0

  if self.selected_stop then
    self.subviews.hint:setText(SELECT_ANOTHER_STOP_HINT)
  else
    self.subviews.hint:setText(SELECT_STOP_HINT)
  end

  for i, route in ipairs(routes) do
    local stops = route.stops
    local route_name = route.name

    if route_name == '' then
      route_name = 'Route ' .. route.id
    end

    table.insert(choices, {text=route_name, type='route', route_index=i, list_position=list_position})
    list_position = list_position + 1

    for j, stop in ipairs(stops) do
      local stop_name = stop.name

      if stop_name == '' then
        stop_name = 'Stop ' .. stop.id
      end

      if self.selected_stop and self.selected_stop.list_position == list_position then
        stop_name = '=> ' .. stop_name
      end

      stop_name = '  ' .. stop_name

      table.insert(choices, {text=stop_name, type='stop', stop_index=j, route_index=i, list_position=list_position})
      list_position = list_position + 1
    end
  end

  self.subviews.routes:setChoices(choices)
end

ReorderStopsModal = defclass(ReorderStopsModal, gui.ZScreenModal)

ReorderStopsModal.ATTRS = {
  focus_path = 'ReorderStops',
}

function ReorderStopsModal:init()
  self:addviews{ReorderStopsWindow{}}
end

function ReorderStopsModal:onDismiss()
  df.global.game.main_interface.recenter_indicator_m.x = -30000
  df.global.game.main_interface.recenter_indicator_m.y = -30000
  df.global.game.main_interface.recenter_indicator_m.z = -30000
end

ReorderStopsOverlay = defclass(ReorderStopsOverlay, overlay.OverlayWidget)
ReorderStopsOverlay.ATTRS{
  default_pos={x=6, y=6},
  default_enabled=true,
  viewscreens='dwarfmode/Hauling',
  frame={w=30, h=1},
  frame_background=gui.CLEAR_PEN,
}

function ReorderStopsOverlay:init()
  self:addviews{
    widgets.TextButton{
      frame={t=0, l=0},
      label='DFHack reorder stops',
      key='CUSTOM_CTRL_E',
      on_activate=function() ReorderStopsModal{}:show() end,
    },
  }
end

OVERLAY_WIDGETS = {
  trackstop=TrackStopOverlay,
  rollers=RollerOverlay,
  reorderstops=ReorderStopsOverlay,
}
