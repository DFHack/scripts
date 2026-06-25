-- Designate wall tiles on the current z-level for smoothing.

local argparse = require('argparse')
local utils = require('utils')

local options = { help = false }

local positionals = argparse.processArgsGetopt({...}, {
    { 'h', 'help', handler = function() options.help = true end },
})

if positionals[1] == 'help' or options.help then
    print(dfhack.script_help())
    return
end

if not dfhack.isMapLoaded() or not dfhack.world.isFortressMode() then
    qerror('This script can only be used in Fortress mode with a loaded map.')
end

local tile_attrs = df.tiletype.attrs
local hard_natural_materials = utils.invert({
    df.tiletype_material.STONE,
    df.tiletype_material.FEATURE,
    df.tiletype_material.LAVA_STONE,
    df.tiletype_material.MINERAL,
    df.tiletype_material.FROZEN_LIQUID,
})

local function is_hard(tileattrs)
    return hard_natural_materials[tileattrs.material]
end

local function is_wall(tileattrs)
    return tileattrs.shape == df.tiletype_shape.WALL
end

local function is_smooth(tileattrs)
    return tileattrs.special == df.tiletype_special.SMOOTH
end

local function has_designation(flags, occupancy)
    return flags.dig ~= df.tile_dig_designation.No or
            flags.smooth > 0 or
            occupancy.carve_track_north or
            occupancy.carve_track_east or
            occupancy.carve_track_south or
            occupancy.carve_track_west
end

local function get_smooth_job_map(z)
    local job_map = {}
    for _, job in utils.listpairs(df.global.world.jobs.list) do
        if job.job_type == df.job_type.SmoothWall and job.pos.z == z then
            if not job_map[job.pos.y] then
                job_map[job.pos.y] = {}
            end
            job_map[job.pos.y][job.pos.x] = job
        end
    end
    return job_map
end

local function designate_smoothing_on_zlevel(z, mode)
    local count = 0
    local job_map = mode == 'undo' and get_smooth_job_map(z) or nil
    for _, block in ipairs(df.global.world.map.map_blocks) do
        if block.map_pos.z == z then
            for y = 0, 15 do
                for x = 0, 15 do
                    local tiletype = block.tiletype[x][y]
                    if tiletype then
                        local tileattrs = tile_attrs[tiletype]
                        local flags = block.designation[x][y]
                        local occupancy = block.occupancy[x][y]
                        if not flags.hidden and is_wall(tileattrs) then
                            if mode == 'undo' then
                                local world_x = block.map_pos.x + x
                                local world_y = block.map_pos.y + y
                                local job = job_map and job_map[world_y] and job_map[world_y][world_x]
                                if flags.smooth > 0 then
                                    flags.smooth = 0
                                    block.flags.designated = true
                                    count = count + 1
                                end
                                if job then
                                    dfhack.job.removeJob(job)
                                end
                            elseif is_hard(tileattrs) and
                                    not is_smooth(tileattrs) and
                                    not has_designation(flags, occupancy) then
                                flags.smooth = 1
                                block.flags.designated = true
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
    end
    return count
end

local mode = positionals[1]
if mode == nil or mode == '' then
    mode = 'smooth'
end

if mode ~= 'smooth' and mode ~= 'undo' then
    qerror('Usage: smooth-walls [smooth|undo]')
end

local z = df.global.window_z
local count = designate_smoothing_on_zlevel(z, mode)
if mode == 'undo' then
    print(('Cleared smoothing designation on %d wall tile(s) for z-level %d.'):format(count, z))
else
    print(('Designated %d wall tile(s) for smoothing on z-level %d.'):format(count, z))
end
