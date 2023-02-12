-- Workaround for the v50.x bug where Dwarf Fortress doesn't set the has_name flag properly when setting/clearing nicknames.
--
--@enable = true
--@module = true

local eventful = require('plugins.eventful')
local persist = require('persist-table')
local json = require('json')
local repeatUtil = require('repeat-util')

local GLOBAL_KEY = 'fix/nicknames'
local DEFAULT_TICKS = 100

g_fixNicknamesEnabled = g_fixNicknamesEnabled or false
g_fixNicknamesTicks = g_fixNicknamesTicks or DEFAULT_TICKS

local function usage()
  print [====[
Periodically checks unit's in-game nicknames, and fixes any unnamed units with a nickname that do not have the 'has_name' flag set correctly so that their nicknames are properly saved/reloaded.

Usage:
  enable fix/nicknames:  Begin monitoring
  disable fix/nicknames: End monitoring

  fix/nicknames ticks <num>:  set frequency of checking for faulty nicknames (default: 100, 1 day = 1200)
  fix/nicknames help:         display this help text

]====]
end

function isEnabled()
  return g_fixNicknamesEnabled
end

local function getTicks()
  return g_fixNicknamesTicks or DEFAULT_TICKS
end

local function persistState()
  local data = {}
  data['enabled'] = isEnabled()
  data['ticks'] = getTicks()
  persist.GlobalTable[GLOBAL_KEY] = json.encode(data)
end

local function parsePersistedState(persistedData)
  local data = json.decode(persistedData)
  g_fixNicknamesEnabled = data['enabled'] or false
  g_fixNicknamesTicks = data['ticks'] or DEFAULT_TICKS
end

local function fixNicknames()
  if not isEnabled() then
    return
  end
  for _, unit in ipairs(df.global.world.units.all) do
    local vname = dfhack.units.getVisibleName(unit)
    local first_name = vname.first_name
    -- nickname fixing only matters for units that belong to the fort and
    -- do not have a name
    if dfhack.units.isFortControlled(unit) and (not first_name or first_name == '') then
      local nickname = vname.nickname
      local has_name = vname.has_name or false
      local has_nickname = nickname and nickname ~= ''
      if not has_name and has_nickname then
        print('Setting nickname: "' .. nickname .. '" for ' .. dfhack.units.getProfessionName(unit))
        dfhack.units.setNickname(unit, nickname)
      elseif has_name and not has_nickname then
        print('Clearing nickname for ' .. dfhack.units.getProfessionName(unit))
        dfhack.units.setNickname(unit, '')
      end
    end
  end
end

local function start()
  repeatUtil.scheduleEvery(GLOBAL_KEY, getTicks(), 'ticks', fixNicknames)
end

local function stop()
  repeatUtil.cancel(GLOBAL_KEY)
end

dfhack.onStateChange[GLOBAL_KEY] = function(sc)
  if sc ~= SC_MAP_LOADED or df.global.gamemode ~= df.game_mode.DWARF then
    return
  end

  local persistedData = persist.GlobalTable[GLOBAL_KEY] or '{}'
  parsePersistedState(persistedData)
  if isEnabled() then
    start()
  else
    stop()
  end
end

local function setEnabled(enabled)
  if enabled == isEnabled() then
    return
  end
  g_fixNicknamesEnabled = enabled
  persistState()
  if enabled then
    start()
  else
    stop()
  end
end

local function setTicks(ticks)
  if ticks == getTicks() then
    return
  end
  g_fixNicknamesTicks = ticks
  persistState()
  if isEnabled() then
    stop()
    start()
  end
end

local function is_int(val)
  return val and val == math.floor(val)
end

local function is_positive_int(val)
  return is_int(val) and val > 0
end

local function check_nonnegative_int(str)
  local val = tonumber(str)
  if is_positive_int(val) or val == 0 then
    return val
  end
  qerror('expecting a non-negative integer, but got: ' .. tostring(str))
end

local args = {...}
if dfhack_flags and dfhack_flags.enable then
  table.insert(args, dfhack_flags.enable_state and 'enable' or 'disable')
  setEnabled(dfhack_flags.enable_state)
elseif #args >= 1 then
  if args[1] == 'help' then
    usage()
  elseif args[1] == 'ticks' then
    if #args == 2 then
      local numTicks = check_nonnegative_int(args[2])
      if (numTicks) then
        setTicks(numTicks)
      else
        dfhack.printerr('Invalid number of ticks specified: "' .. args[2] .. '", expecting a positive integer value')
        print()
        usage()
      end
    else
      dfhack.printerr('Need to specify the number of ticks - see usage below')
      print()
      usage()
    end
  else
    usage()
  end
end
