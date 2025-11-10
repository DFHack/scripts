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
  MAX_FILL_TILES = 4000,  -- safety limit
  ALLOW_DIAGONALS = false -- can be overridden by parameter
}

-------------------------
-- Utilities and guards
-------------------------
local function err(msg) qerror('AutoCeiling: ' .. tostring(msg)) end

local function try_require(modname)
  local ok, mod = pcall(require, modname)
  if ok and mod then return mod end
  return nil
end

-------------------------
-- World and map helpers
-------------------------
local W = df.global.world
local XMAX, YMAX, ZMAX = W.map.x_count, W.map.y_count, W.map.z_count

local function in_bounds(x, y, z)
  return x >= 0 and y >= 0 and z >= 0 and x < XMAX and y < YMAX and z < ZMAX
end

local function get_block(x, y, z)
  return dfhack.maps.getTileBlock(x, y, z)
end

local function get_tiletype(x, y, z)
  local b = get_block(x, y, z)
  if not b then return nil end
  return b.tiletype[x % 16][y % 16]
end

local function tile_shape(tt)
  if not tt then return nil end
  local a = df.tiletype.attrs[tt]
  return a and a.shape or nil
end

local function tile_material(tt)
  if not tt then return nil end
  local a = df.tiletype.attrs[tt]
  return a and a.material or nil
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
  local tt = get_tiletype(x, y, z)
  local mat = tile_material(tt)
  return mat == df.tiletype_material.CONSTRUCTION
end

local function has_any_building(x, y, z)
  -- Also detects in-progress constructions as buildings
  return dfhack.buildings.findAtTile({ x = x, y = y, z = z }) ~= nil
end

-------------------------
-- Flood fill
-------------------------
local function push_if_ok(q, visited, x, y, z)
  if not in_bounds(x, y, z) then return end
  local key = x .. ',' .. y
  if visited[key] then return end
  local tt = get_tiletype(x, y, z)
  if is_walkable_dug(tt) then
    visited[key] = true
    q[#q + 1] = { x, y }
  end
end

local function flood_fill_footprint(seed_x, seed_y, z0)
  local footprint = {}
  local visited = {}
  local q = { { seed_x, seed_y } }
  visited[seed_x .. ',' .. seed_y] = true
  local head = 1
  while head <= #q and #footprint < CONFIG.MAX_FILL_TILES do
    local x, y = table.unpack(q[head]); head = head + 1
    footprint[#footprint + 1] = { x = x, y = y }
    if CONFIG.ALLOW_DIAGONALS then
      push_if_ok(q, visited, x + 1, y, z0)
      push_if_ok(q, visited, x - 1, y, z0)
      push_if_ok(q, visited, x, y + 1, z0)
      push_if_ok(q, visited, x, y - 1, z0)
      push_if_ok(q, visited, x + 1, y + 1, z0)
      push_if_ok(q, visited, x + 1, y - 1, z0)
      push_if_ok(q, visited, x - 1, y + 1, z0)
      push_if_ok(q, visited, x - 1, y - 1, z0)
    else
      push_if_ok(q, visited, x + 1, y, z0)
      push_if_ok(q, visited, x - 1, y, z0)
      push_if_ok(q, visited, x, y + 1, z0)
      push_if_ok(q, visited, x, y - 1, z0)
    end
  end

  if #q > CONFIG.MAX_FILL_TILES then
    dfhack.printerr(('AutoCeiling: flood fill truncated at %d tiles'):format(CONFIG.MAX_FILL_TILES))
  end
  return footprint
end

-------------------------
-- Placement strategies
-------------------------
local function place_planned(bp, x, y, z)
  local ok, bld = pcall(function()
    return dfhack.buildings.constructBuilding{
      type    = df.building_type.Construction,
      subtype = df.construction_type.Floor,
      pos     = { x = x, y = y, z = z }
    }
  end)
  if not ok or not bld then return false, 'construct-error' end
  pcall(function() bp.addPlannedBuilding(bld) end)
  return true
end

local function place_native(cons, x, y, z)
  if not cons or not cons.designate then return false, 'no-constructions-api' end
  local ok, derr = pcall(function()
    cons.designate{ pos = { x = x, y = y, z = z }, type = df.construction_type.Floor }
  end)
  if not ok then return false, 'designate-error' end
  return true
end

-------------------------
-- Main
-------------------------
local function main(...)
  local args = {...}
  -- Allow user to set diagonals with parameter 't' or 'true'
  if #args > 0 and (args[1] == 't' or args[1] == 'true') then
    CONFIG.ALLOW_DIAGONALS = true
  end

  -- Validate cursor and tile
  local cur = df.global.cursor
  if cur.x == -30000 then err('cursor not set. Move to a dug tile and run again.') end
  local z0 = cur.z
  local seed_tt = get_tiletype(cur.x, cur.y, z0)
  if not is_walkable_dug(seed_tt) then err('cursor tile is not dug/open interior') end

  -- Discover footprint and target surface level
  local footprint = flood_fill_footprint(cur.x, cur.y, z0)
  local z_surface = z0 + 1

  -- Load optional DFHack helpers
  local bp = try_require('plugins.buildingplan')
  if bp and (not bp.isEnabled or not bp.isEnabled()) then bp = nil end
  local cons = try_require('dfhack.constructions')

  local placed, skipped = 0, 0
  local reasons = {}
  local function skip(reason)
    skipped = skipped + 1
    reasons[reason] = (reasons[reason] or 0) + 1
  end

  -- Process each tile
  for i = 1, #footprint do
    local x, y = footprint[i].x, footprint[i].y
    if not in_bounds(x, y, z_surface) then
      skip('oob')
    elseif is_constructed_tile(x, y, z_surface) then
      skip('constructed')
    elseif has_any_building(x, y, z_surface) then
      skip('building')
    else
      local ok, why
      if bp then
        ok, why = place_planned(bp, x, y, z_surface)
      else
        ok, why = place_native(cons, x, y, z_surface)
      end
      if ok then placed = placed + 1 else skip(why or 'unknown') end
    end
  end

  if bp and bp.doCycle then pcall(function() bp.doCycle() end) end

  print(('AutoCeiling: placed %d floor construction(s); skipped %d'):format(placed, skipped))
  if bp then
    print('buildingplan active: created planned floors that will auto-assign materials')
  elseif cons and cons.designate then
    print('used native construction designations')
  else
    print('no buildingplan and no constructions API available')
  end
  for k, v in pairs(reasons) do
    print(('  skipped %-18s %d'):format(k, v))
  end
end

main(...)
