-- Overlay to allow changing track stop and related building settings after construction
--@ module = true

if not dfhack_flags.module then
  qerror('trackstop cannot be called directly')
end

local gui = require('gui')
local widgets = require('gui.widgets')
local overlay = require('plugins.overlay')
local utils = require('utils')

local getBuild = dfhack.gui.getSelectedBuilding

local NORTH = 'North '..string.char(24)
local EAST = 'East '..string.char(26)
local SOUTH = 'South '..string.char(25)
local WEST = 'West '..string.char(27)

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

local FLUID_DEPTHS = {}
for i=1,8 do -- 0 to 7
  FLUID_DEPTHS[i] = {value=i-1, label=tostring(i-1)}
end

local TRACK_WEIGHTS = {}
TRACK_WEIGHTS[1] = {value=1, label=tostring(1)..string.char(226)} -- 1
for i=2,41 do -- 50 to 2000
  TRACK_WEIGHTS[i] = {value=(i-1)*50, label=('%d%s'):format((i-1)*50, string.char(226))}
end
TRACK_WEIGHTS[41].label = TRACK_WEIGHTS[41].label..'/Any' -- 2000 is Any for track_max

local UNIT_WEIGHTS = {}
for i=1,200 do -- 1000 to 200000; actual creature labels would require checking raws
  UNIT_WEIGHTS[i] = {value=i*1000, label=('(%d)'):format(i*1000)}
end

TrackStopOverlay = defclass(TrackStopOverlay, overlay.OverlayWidget)
TrackStopOverlay.ATTRS{
  desc='Adds widgets for reconfiguring trackstops after construction.',
  default_pos={x=-73, y=32},
  version=2,
  default_enabled=true,
  viewscreens='dwarfmode/ViewSheets/BUILDING/Trap/TrackStop',
  frame={w=25, h=4},
  frame_style=gui.MEDIUM_FRAME,
  frame_background=gui.CLEAR_PEN,
}

function TrackStopOverlay:setFriction(friction)
  getBuild().track_stop_info.friction = FRICTION_MAP[friction]
end

function TrackStopOverlay:getDumpDirection()
  local info = getBuild().track_stop_info
  local x = info.dump_x_shift
  local y = info.dump_y_shift

  if not info.track_flags.use_dump then
    return NONE
  else
    if x == 0 and y == -1 then
      return NORTH
    elseif x == 1 and y == 0 then
      return EAST
    elseif x == 0 and y == 1 then
      return SOUTH
    elseif x == -1 and y == 0 then
      return WEST
    end
  end
end

function TrackStopOverlay:setDumpDirection(direction)
  local info = getBuild().track_stop_info

  if direction == NONE then
    info.track_flags.use_dump = false
    info.dump_x_shift = 0
    info.dump_y_shift = 0
  elseif direction == NORTH then
    info.track_flags.use_dump = true
    info.dump_x_shift = 0
    info.dump_y_shift = -1
  elseif direction == EAST then
    info.track_flags.use_dump = true
    info.dump_x_shift = 1
    info.dump_y_shift = 0
  elseif direction == SOUTH then
    info.track_flags.use_dump = true
    info.dump_x_shift = 0
    info.dump_y_shift = 1
  elseif direction == WEST then
    info.track_flags.use_dump = true
    info.dump_x_shift = -1
    info.dump_y_shift = 0
  end
end

function TrackStopOverlay:render(dc)
  local f = getBuild().track_stop_info.friction
  self.subviews.friction:setOption(FRICTION_MAP_REVERSE[f])
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
      on_change=self:callback('setDumpDirection'),
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
      on_change=self:callback('setFriction'),
    },
  }
end

RollerOverlay = defclass(RollerOverlay, overlay.OverlayWidget)
RollerOverlay.ATTRS{
  desc='Adds widgets for reconfiguring rollers after construction.',
  default_pos={x=-71, y=32},
  version=2,
  default_enabled=true,
  viewscreens='dwarfmode/ViewSheets/BUILDING/Rollers',
  frame={w=27, h=4},
  frame_style=gui.MEDIUM_FRAME,
  frame_background=gui.CLEAR_PEN,
}

function RollerOverlay:setDirection(direction)
  getBuild().direction = DIRECTION_MAP[direction]
end

function RollerOverlay:setSpeed(speed)
  getBuild().speed = SPEED_MAP[speed]
end

function RollerOverlay:render(dc)
  local b = getBuild()
  self.subviews.direction:setOption(DIRECTION_MAP_REVERSE[b.direction])
  self.subviews.speed:setOption(SPEED_MAP_REVERSE[b.speed])

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
      on_change=self:callback('setDirection'),
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
      on_change=self:callback('setSpeed'),
    },
  }
end

PlateOverlay = defclass(PlateOverlay, overlay.OverlayWidget)
PlateOverlay.ATTRS{
  desc='Adds widgets for reconfiguring pressure plates after construction.',
  default_pos={x=-54, y=32},
  version=2,
  default_enabled=true,
  viewscreens='dwarfmode/ViewSheets/BUILDING/Trap/PressurePlate',
  frame={w=44, h=7},
  frame_style=gui.MEDIUM_FRAME,
  frame_background=gui.CLEAR_PEN,
}

local function clamp(value, low, high)
  return math.min(high, math.max(low, value))
end

local function testBound(val, old_val, low, high) -- Hotkey cycle ends
  return (val == low and old_val == high) or (val == high and old_val == low)
end

function PlateOverlay:isFluidTab() return self.cur_tab == 1 or self.cur_tab == 2 end

function PlateOverlay:isWaterTab() return self.cur_tab == 1 end

function PlateOverlay:isTrackTab() return self.cur_tab == 3 end

function PlateOverlay:isCreaturesTab() return self.cur_tab == 4 end

function PlateOverlay:hasTextInputTab() return self.cur_tab == 3 or self.cur_tab == 4 end

function PlateOverlay:swapTab(idx)
  self.cur_tab = idx
  self.subviews.min_text:setFocus(false)
  self.subviews.max_text:setFocus(false)
end

function PlateOverlay:changeFluidMin(val, old_val)
  if testBound(val, old_val, 0, 7) then
    return --Don't edge wrap; it would mess with the other setting
  end
  local p = getBuild().plate_info
  if self:isWaterTab() then
    p.water_min = val
    p.water_max = math.max(val, p.water_max)
  else
    p.magma_min = val
    p.magma_max = math.max(val, p.magma_max)
  end
end

function PlateOverlay:changeFluidMax(val, old_val)
  if testBound(val, old_val, 0, 7) then
    return
  end
  local p = getBuild().plate_info
  if self:isWaterTab() then
    p.water_max = val
    p.water_min = math.min(val, p.water_min)
  else
    p.magma_max = val
    p.magma_min = math.min(val, p.magma_min)
  end
end

function PlateOverlay:changeTrackMin(val, old_val)
  if testBound(val, old_val, 1, 2000) then
    return
  end
  local p = getBuild().plate_info
  val = math.min(val, 2000)
  p.track_min = val
  p.track_max = math.max(val, p.track_max)
end

function PlateOverlay:changeTrackMax(val, old_val)
  if testBound(val, old_val, 1, 2000) then
    return
  end
  local p = getBuild().plate_info
  val = math.min(val, 2000)
  p.track_max = val
  p.track_min = math.min(val, p.track_min)
end

function PlateOverlay:changeUnitMin(val, old_val)
  if testBound(val, old_val, 1000, 200000) then
    return
  end
  local p = getBuild().plate_info
  val = math.min(val, 200000)
  p.unit_min = val
  p.unit_max = math.max(val, p.unit_max)
end

function PlateOverlay:changeUnitMax(val, old_val)
  if testBound(val, old_val, 1000, 200000) then
    return
  end
  local p = getBuild().plate_info
  val = math.min(val, 200000)
  p.unit_max = val
  p.unit_min = math.min(val, p.unit_min)
end

function PlateOverlay:inputMin(text)
  local val = math.tointeger(text) or -1
  if val < 0 then
    return -- Bad input
  elseif self:isTrackTab() then
    self:changeTrackMin(val, 0)
  elseif self:isCreaturesTab() then
    self:changeUnitMin(val, 0)
  end
end

function PlateOverlay:inputMax(text)
  local val = math.tointeger(text) or -1
  if val < 0 then
    return
  elseif self:isTrackTab() then
    self:changeTrackMax(val, 0)
  elseif self:isCreaturesTab() then
    self:changeUnitMax(val, 0)
  end
end

function PlateOverlay:render(dc)
  local p = getBuild().plate_info
  local sv = self.subviews

  if self:isFluidTab() then -- Water or Magma
    local f = self:isWaterTab() and 'water' or 'magma'
    sv.fluid_toggle:setOption(p.flags[f])
    sv.fluid_min.option_idx = p[f..'_min']+1
    sv.fluid_max.option_idx = p[f..'_max']+1

  elseif self:isTrackTab() then
    sv.track_toggle:setOption(p.flags.track)
    sv.track_min.option_idx = clamp(p.track_min//50+1, 1, 41)
    sv.track_max.option_idx = clamp(p.track_max//50+1, 1, 41)

    if not sv.min_text.focus then
      sv.min_text:setText(tostring(p.track_min))
    end
    if not sv.max_text.focus then
      sv.max_text:setText(tostring(p.track_max))
    end
  elseif self:isCreaturesTab() then
    sv.unit_toggle:setOption(p.flags.units)
    sv.citizen_toggle:setOption(p.flags.citizens)
    sv.unit_min.option_idx = clamp(p.unit_min//1000, 1, 200)
    sv.unit_max.option_idx = clamp(p.unit_max//1000, 1, 200)

    if not sv.min_text.focus then
      sv.min_text:setText(tostring(p.unit_min))
    end
    if not sv.max_text.focus then
      sv.max_text:setText(tostring(p.unit_max))
    end
  end
  PlateOverlay.super.render(self, dc)
end

function PlateOverlay:init()
  self.cur_tab = 1 -- 1:Water, 2:Magma, 3:Track, 4:Creatures

  self:addviews{
    widgets.TabBar{
      frame={t=0, l=0},
      labels={
        'Water',
        'Magma',
        'Track',
        'Creatures',
      },
      on_select=self:callback('swapTab'),
      get_cur_page=function() return self.cur_tab end,
    },
    -- Water and Magma (shared widgets)
    widgets.ToggleHotkeyLabel{
      view_id='fluid_toggle',
      frame={t=2, l=0, w=13},
      label=function() return self:isWaterTab() and 'Water:' or 'Magma:' end,
      key='CUSTOM_SHIFT_X',
      on_change=function()
        local p = getBuild().plate_info
        local f = self:isWaterTab() and 'water' or 'magma'
        p.flags[f] = not p.flags[f]
      end,
      visible=self:callback('isFluidTab'),
    },
    widgets.CycleHotkeyLabel{
      view_id='fluid_min',
      frame={t=3, l=0, w=16},
      label='Min Depth:',
      key_back='CUSTOM_SHIFT_E',
      key='CUSTOM_SHIFT_R',
      options=FLUID_DEPTHS,
      on_change=self:callback('changeFluidMin'),
      visible=self:callback('isFluidTab'),
    },
    widgets.CycleHotkeyLabel{
      view_id='fluid_max',
      frame={t=3, r=1, w=16},
      label='Max Depth:',
      key_back='CUSTOM_SHIFT_C',
      key='CUSTOM_SHIFT_V',
      options=FLUID_DEPTHS,
      on_change=self:callback('changeFluidMax'),
      visible=self:callback('isFluidTab'),
    },
    widgets.RangeSlider{
      frame={t=4, l=0},
      num_stops=#FLUID_DEPTHS,
      get_left_idx_fn=function() return self.subviews.fluid_min:getOptionValue()+1 end,
      get_right_idx_fn=function() return self.subviews.fluid_max:getOptionValue()+1 end,
      on_left_change=function(idx) self.subviews.fluid_min:setOption(idx-1, true) end,
      on_right_change=function(idx) self.subviews.fluid_max:setOption(idx-1, true) end,
      visible=self:callback('isFluidTab'),
    },
    -- Track
    widgets.ToggleHotkeyLabel{
      view_id='track_toggle',
      frame={t=2, l=0, w=17},
      label='Minecarts:',
      key='CUSTOM_SHIFT_X',
      on_change=function()
        local p = getBuild().plate_info
        p.flags.track = not p.flags.track
      end,
      visible=self:callback('isTrackTab'),
    },
    widgets.CycleHotkeyLabel{
      view_id='track_min',
      frame={t=3, l=0, w=25},
      label='Min Weight:',
      key_back='CUSTOM_SHIFT_E',
      key='CUSTOM_SHIFT_R',
      options=TRACK_WEIGHTS,
      on_change=self:callback('changeTrackMin'),
      visible=self:callback('isTrackTab'),
    },
    widgets.CycleHotkeyLabel{
      view_id='track_max',
      frame={t=4, l=0, w=25},
      label='Max Weight:',
      key_back='CUSTOM_SHIFT_C',
      key='CUSTOM_SHIFT_V',
      options=TRACK_WEIGHTS,
      on_change=self:callback('changeTrackMax'),
      visible=self:callback('isTrackTab'),
    },
    -- Creatures
    widgets.ToggleHotkeyLabel{
      view_id='unit_toggle',
      frame={t=2, l=0, w=17},
      label='Creatures:',
      key='CUSTOM_SHIFT_X',
      on_change=function()
        local p = getBuild().plate_info
        p.flags.units = not p.flags.units
      end,
      visible=self:callback('isCreaturesTab'),
    },
    widgets.ToggleHotkeyLabel{
      view_id='citizen_toggle',
      frame={t=2, r=0, w=16},
      label='Citizens:',
      key='CUSTOM_X',
      on_change=function()
        local p = getBuild().plate_info
        p.flags.citizens = not p.flags.citizens
      end,
      visible=self:callback('isCreaturesTab'),
    },
    widgets.CycleHotkeyLabel{
      view_id='unit_min',
      frame={t=3, l=0, w=24},
      label='Min Weight:',
      key_back='CUSTOM_SHIFT_E',
      key='CUSTOM_SHIFT_R',
      options=UNIT_WEIGHTS,
      on_change=self:callback('changeUnitMin'),
      visible=self:callback('isCreaturesTab'),
    },
    widgets.CycleHotkeyLabel{
      view_id='unit_max',
      frame={t=4, l=0, w=24},
      label='Max Weight:',
      key_back='CUSTOM_SHIFT_C',
      key='CUSTOM_SHIFT_V',
      options=UNIT_WEIGHTS,
      on_change=self:callback('changeUnitMax'),
      visible=self:callback('isCreaturesTab'),
    },
    -- Text input (shared widgets)
    widgets.EditField{
      view_id='min_text',
      frame={t=3, r=0, w=16},
      key='CUSTOM_SHIFT_T',
      on_submit=self:callback('inputMin'),
      visible=self:callback('hasTextInputTab'),
    },
    widgets.EditField{
      view_id='max_text',
      frame={t=4, r=0, w=16},
      key='CUSTOM_SHIFT_B',
      on_submit=self:callback('inputMax'),
      visible=self:callback('hasTextInputTab'),
    },
  }
end

OVERLAY_WIDGETS = {
  trackstop=TrackStopOverlay,
  rollers=RollerOverlay,
  pressureplate=PlateOverlay,
}
