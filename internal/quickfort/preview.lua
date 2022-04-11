-- preview data structure management for the quickfort script
--@ module = true

if not dfhack_flags.module then
    qerror('this script cannot be called directly')
end

local quickfort_common = reqscript('internal/quickfort/common')
local ensure_key = quickfort_common.ensure_key

local utils = require('utils')

-- sets the given preview position to the given value if it is not already set
-- if override is true, ignores whether the tile was previously set
-- returns whether the tile was set
function set_preview_tile(ctx, pos, is_valid_tile, override)
    local preview = ctx.preview
    if not preview then return false end
    local preview_row = ensure_key(ensure_key(ctx.preview.tiles, pos.z), pos.y)
    if not override and preview_row[pos.x] ~= nil then
        return false
    end
    preview_row[pos.x] = is_valid_tile
    if not is_valid_tile then
        preview.invalid_tiles = preview.invalid_tiles + 1
    end
    local bounds = ensure_key(preview.bounds, pos.z,
                              {x_min=pos.x, x_max=pos.x,
                               y_min=pos.y, y_max=pos.y})
    bounds.x_min = math.min(bounds.x_min, pos.x)
    bounds.x_max = math.max(bounds.x_max, pos.x)
    bounds.y_min = math.min(bounds.y_min, pos.y)
    bounds.y_max = math.max(bounds.y_max, pos.y)
    return true
end

-- returns true if the tile is on the blueprint and will be correctly applied
-- returns false if the tile is on the blueprint and is an invalid tile
-- returns nil if the tile is not on the blueprint
function get_preview_tile(tiles, pos)
    return utils.safe_index(tiles, pos.z, pos.y, pos.x)
end
