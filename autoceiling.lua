-- AutoCeiling.lua
-- Purpose: flood-fill the connected dug area on the cursor z-level (z0)
-- and place constructed floors directly above (z0+1). When the buildingplan
-- plugin is enabled, planned constructions are created. Otherwise we fall back
-- to native construction designations so dwarves get immediate jobs.
-- The script skips tiles that already have a player-made construction or
-- any existing building at the target tile on z0+1.

-------------------------
-- Configuration defaults
-------------------------
local CONFIG = {
  MAX_FILL_TILES = 2000,   -- positive integer; safety limit
  ALLOW_DIAGONALS = false, -- set true to allow 8-way fill
  MAX_LIMIT_HARD = 4000,  -- hard clamp to avoid runaway fills
}

-------------------------
-- Utilities and guards
-------------------------
local function err(msg) qerror('AutoCeiling: ' .. tostring(msg)) end

local function xyz2pos(x, y, z)
  return { x = x, y = y, z = z }
end

-- Cache frequently used modules/tables for readability
local maps          = dfhack.maps
local constructions = dfhack.constructions
local buildings     = dfhack.buildings
local tattrs        = df.tiletype.attrs

-------------------------
-- World and map helpers
-------------------------
local function in_bounds(x, y, z)
  return maps.isValidTilePos(x, y, z)
end

local function get_tiletype(x, y, z)
  return maps.getTileType(x, y, z)
end

local function tile_shape(tt)
  if not tt then return nil end
  local a = tattrs[tt]
  return (a and a.shape ~= df.tiletype_shape.NONE) and a.shape or nil
end

-------------------------
-- Predicates
-------------------------
local function is_walkable_dug(tt)
  local s = tile_shape(tt)
  if not s then return false end
  return s == df.tiletype_shape.FLOOR
      or s == df.tiletype_shape.RAMP
      or s == df.tiletype_shape.STAIR_UP
      or s == df.tiletype_shape.STAIR_DOWN
      or s == df.tiletype_shape.STAIR_UPDOWN
      or s == df.tiletype_shape.EMPTY
end

local function is_constructed_tile(x, y, z)
  return constructions.findAtTile(x, y, z) ~= nil
end

local function has_any_building(x, y, z)
  return buildings.findAtTile(xyz2pos(x, y, z)) ~= nil
end

-------------------------
-- Flood fill
-------------------------
local function flood_fill_footprint(seed_x, seed_y, z0)
  local footprint = {}
  local visited = {}
  local queue = { { seed_x, seed_y } }
  visited[seed_x .. ',' .. seed_y] = true
  local queue_pos = 1

  local function push_if_ok(x, y)
    if not in_bounds(x, y, z0) then return end
    local key = x .. ',' .. y
    if visited[key] then return end
    local tt = get_tiletype(x, y, z0)
    if is_walkable_dug(tt) then
      visited[key] = true
      table.insert(queue, { x, y })
    end
  end

  while queue_pos <= #queue and #footprint < CONFIG.MAX_FILL_TILES do
    local x, y = table.unpack(queue[queue_pos])
    queue_pos = queue_pos + 1
    table.insert(footprint, { x = x, y = y })
    push_if_ok(x + 1, y)
    push_if_ok(x - 1, y)
    push_if_ok(x, y + 1)
    push_if_ok(x, y - 1)
    if CONFIG.ALLOW_DIAGONALS then
      push_if_ok(x + 1, y + 1)
      push_if_ok(x + 1, y - 1)
      push_if_ok(x - 1, y + 1)
      push_if_ok(x - 1, y - 1)
    end
  end

  if #queue > CONFIG.MAX_FILL_TILES then
    dfhack.printerr(('AutoCeiling: flood fill truncated at %d tiles'):format(CONFIG.MAX_FILL_TILES))
  end
  return footprint
end

-------------------------
-- Placement strategies
-------------------------
local function place_planned(bp, pos)
  local ok, bld = pcall(function()
    return dfhack.buildings.constructBuilding{
      type    = df.building_type.Construction,
      subtype = df.construction_type.Floor,
      pos     = pos
    }
  end)
  if not ok or not bld then return false, 'construct-error' end
  pcall(function() bp.addPlannedBuilding(bld) end)
  return true
end

local function place_native(cons, pos)
  if not cons or not cons.designateNew then return false, 'no-constructions-api' end

  local ok, res = pcall(function()
    return cons.designateNew(pos, df.construction_type.Floor, -1, -1)
  end)
  if ok and res then return true end

  local ok2, res2 = pcall(function()
    return cons.designateNew(pos, df.construction_type.Floor, df.item_type.BOULDER, -1)
  end)
  if ok2 and res2 then return true end

  return false, 'designate-error'
end

-------------------------
-- Main
-------------------------
local utils = require('utils')

local function main(...)
  local args = {...}

  for _, raw in ipairs(args) do
    local s = tostring(raw):lower()
    local num = tonumber(s)
    if num then
      if num < 1 then err('MAX_FILL_TILES must be >= 1') end
      if num > CONFIG.MAX_LIMIT_HARD then
        dfhack.printerr(('clamping MAX_FILL_TILES from %d to %d'):format(num, CONFIG.MAX_LIMIT_HARD))
        num = CONFIG.MAX_LIMIT_HARD
      end
      CONFIG.MAX_FILL_TILES = math.floor(num)
    elseif s == 't' or s == 'true' then
      CONFIG.ALLOW_DIAGONALS = true
    elseif s == 'h' or s == 'help' then
      print('Usage: autoceiling [t] [<max_fill_tiles>]')
      print('  t: enable diagonal flood fill')
      print(('  <max_fill_tiles>: positive integer, default %d, max %d')
        :format(CONFIG.MAX_FILL_TILES, CONFIG.MAX_LIMIT_HARD))
      return
    elseif s ~= '' then
      err('unknown argument: ' .. tostring(raw))
    end
  end

  local cur = utils.clone(df.global.cursor)
  if cur.x == -30000 then err('cursor not set. Move to a dug tile and run again.') end
  local z0 = cur.z
  local seed_tt = get_tiletype(cur.x, cur.y, z0)
  if not is_walkable_dug(seed_tt) then err('cursor tile is not dug/open interior') end

  local footprint = flood_fill_footprint(cur.x, cur.y, z0)
  if #footprint == 0 then
    print('AutoCeiling: nothing to do — no connected dug tiles found at cursor')
    return
  end
  local z_surface = z0 + 1

  local ok, bp = pcall(require, 'plugins.buildingplan')
  if not ok then
    bp = nil
  elseif bp and (not bp.isEnabled or not bp.isEnabled()) then
    bp = nil
  end
  local cons = dfhack.constructions

  local placed, skipped = 0, 0
  local reasons = {}
  local function skip(reason)
    skipped = skipped + 1
    reasons[reason] = (reasons[reason] or 0) + 1
  end

  for i, foot in ipairs(footprint) do
    local x, y = foot.x, foot.y
    local pos = xyz2pos(x, y, z_surface)
    if not in_bounds(x, y, z_surface) then
      skip('oob')
    elseif is_constructed_tile(x, y, z_surface) then
      skip('constructed')
    elseif has_any_building(x, y, z_surface) then
      skip('building')
    else
      local ok_place, why
      if bp then
        ok_place, why = place_planned(bp, pos)
      else
        ok_place, why = place_native(cons, pos)
      end
      if ok_place then placed = placed + 1 else skip(why or 'unknown') end
    end
  end

  if bp and bp.doCycle then pcall(function() bp.doCycle() end) end

  print(('AutoCeiling: placed %d floor construction(s); skipped %d'):format(placed, skipped))
  if bp then
    print('buildingplan active: created planned floors that will auto-assign materials')
  elseif cons and cons.designateNew then
    print('used native construction designations')
  else
    print('no buildingplan and no constructions API available')
  end
  for k, v in pairs(reasons) do
    print(('  skipped %-18s %d'):format(k, v))
  end
end

main(...)
