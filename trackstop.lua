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

--[[
  - swap 2 elements between different indexes in the same table like:
    swap_elements({1, 2, 3}, 1, nil, 3) => {3, 2, 1}
  - swap 2 elements at the specified indexes between 2 tables like:
    swap_elements({1, 2, 3}, 1, {4, 5, 6}, 3) => {6, 2, 3} {4, 5, 1}
]]--
local function swap_elements(tbl1, index1, tbl2, index2)
  tbl2 = tbl2 or tbl1
  index2 = index2 or index1
  tbl1[index1], tbl2[index2] = tbl2[index2], tbl1[index1]
  return tbl1, tbl2
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
  frame={t=4,l=60,w=49, h=26},
  frame_title='Reorder Stops',
  resizable=true,
}

local SELECT_STOP_HINT = 'Select a stop to move'
local SELECT_ANOTHER_STOP_HINT = 'Select another stop to swap or same to cancel'


function ReorderStopsWindow:handleStopSelection(index, item)
  -- Skip routes
  if item.type == 'route' then return end

  -- Select stop if none selected
  if not self.first_selected_stop then
    self:toggleStopSelection(item)
    return
  end

  -- Swap stops
  self:swapStops(index, item)

  -- Reset stop properties
  self:resetStopProperties(item)

  self.first_selected_stop = nil
  self:updateList()
end

function ReorderStopsWindow:toggleStopSelection(item)
  if not self.first_selected_stop then
    self.first_selected_stop = item
  else
    self.first_selected_stop = nil
  end

  self:updateList()
end

function ReorderStopsWindow:swapStops(index, second_selected_stop)
  local hauling = df.global.plotinfo.hauling
  local routes = hauling.routes
  local view_stops = hauling.view_stops
  local second_selected_stop_route = routes[second_selected_stop.route_index]
  local second_selected_stop_index = second_selected_stop.stop_index
  local same_route = self.first_selected_stop.route_index == second_selected_stop.route_index

  if same_route then
    swap_elements(second_selected_stop_route.stops, second_selected_stop_index, nil, self.first_selected_stop.stop_index)

    -- find out what index the vehicle is currently at for this route, if there is one
    local vehicle_index = nil
    local hauling_route = df.hauling_route.get_vector()[second_selected_stop.route_index]

    -- this vector will have 0 elements if there is no vehicle or 1 element if there is a vehicle
    -- the element will be the index of the vehicle stop
    for _, v in ipairs(hauling_route.vehicle_stops) do
      vehicle_index = v
    end

    if vehicle_index == self.first_selected_stop.stop_index then
      hauling_route.vehicle_stops[0] = second_selected_stop_index
    elseif vehicle_index == second_selected_stop_index then
      hauling_route.vehicle_stops[0] = self.first_selected_stop.stop_index
    end
  else
    swap_elements(
      routes[self.first_selected_stop.route_index].stops,
      self.first_selected_stop.stop_index,
      second_selected_stop_route.stops,
      second_selected_stop_index
    )
  end

  swap_elements(view_stops, self.first_selected_stop.list_position, nil, index - 1)
end

function ReorderStopsWindow:resetStopProperties(item)
  local hauling = df.global.plotinfo.hauling
  local routes = hauling.routes
  local item_route = routes[item.route_index]
  local same_route = self.first_selected_stop.route_index == item.route_index

  for i, stop in ipairs(item_route.stops) do
    stop.id = i + 1
    reset_guide_paths(stop.conditions)
  end

  if not same_route and self.first_selected_stop then
    for i, stop in ipairs(routes[self.first_selected_stop.route_index].stops) do
      stop.id = i + 1
      reset_guide_paths(stop.conditions)
    end
  end
end

function ReorderStopsWindow:init()
  self.first_selected_stop = nil
  self:addviews{
    widgets.Label{
      frame={t=0,l=0},
      view_id='hint',
      text=SELECT_STOP_HINT,
    },
    widgets.List{
      view_id='routes',
      frame={t=2,l=1},
      choices={},
      on_select=function(_, item)
        if not item then return end
        if item.type == 'stop' then
          local item_pos = df.global.plotinfo.hauling.routes[item.route_index].stops[item.stop_index].pos
          dfhack.gui.revealInDwarfmodeMap(item_pos, true, true)
        end
      end,
      on_submit=function(index, item)
        self:handleStopSelection(index, item)
      end,
    },
  }

  self:updateList()
end

function ReorderStopsWindow:updateList()
  local routes = df.global.plotinfo.hauling.routes
  local choices = {}
  local list_position = 0

  if self.first_selected_stop then
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

      if self.first_selected_stop and self.first_selected_stop.list_position == list_position then
        stop_name = '=> ' .. stop_name
      end

      stop_name = '  ' .. stop_name

      table.insert(choices, {text=stop_name, type='stop', stop_index=j, route_index=i, list_position=list_position})
      list_position = list_position + 1
    end
  end

  self.subviews.routes:setChoices(choices)
end

function ReorderStopsWindow:onInput(keys)
  if keys.LEAVESCREEN or keys._MOUSE_R then
    if self.first_selected_stop then
      self.first_selected_stop = nil
      self:updateList()
      return true
    end
  end

  return ReorderStopsWindow.super.onInput(self, keys)
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
