-- Create a named manual save that won't be overwritten by autosaves.
--[====[
manual-save
===========

Tags: fort | dfhack

Creates a persistent, named save snapshot that will not be overwritten
by future autosaves. The save is created by triggering a native
autosave and then duplicating the result into a timestamped folder.

Usage
-----

    manual-save [<name>] [<options>]

If no name is given, the save is named after your fortress with a
timestamp, e.g. ``Floorroasts-Manual-2026-04-25_09-19-22``.

Examples
--------

manual-save
    Create a snapshot named after your fortress and the current time.

manual-save MyProject
    Create a snapshot named ``MyProject``.

manual-save --cleanup 5
    Create a snapshot, then prune old manual saves, keeping only the
    5 most recent.

repeat -name rolling-saves -time 1 -timeUnits months -command [ manual-save --cleanup 10 ]
    Automatically create a rolling manual save every in-game month,
    keeping only the 10 most recent snapshots.

Options
-------

-c, --cleanup <num>
    After saving, delete the oldest manual save snapshots so that
    only <num> remain. Only folders whose names contain "-Manual-"
    are considered; native autosaves and region folders are never
    touched.
]====]

local utils = require("utils")

-- ---------------------------------------------------------------------------
-- Argument parsing
-- ---------------------------------------------------------------------------
local positional_name = nil
local cleanup_count = nil

local args = {...}
local i = 1
while i <= #args do
    if args[i] == '-c' or args[i] == '--cleanup' then
        i = i + 1
        cleanup_count = tonumber(args[i])
        if not cleanup_count or cleanup_count < 1 then
            qerror('--cleanup requires a positive number')
        end
    elseif not args[i]:startswith('-') then
        positional_name = positional_name and (positional_name .. '-' .. args[i]) or args[i]
    else
        qerror('Unknown option: ' .. args[i])
    end
    i = i + 1
end

-- ---------------------------------------------------------------------------
-- Guards
-- ---------------------------------------------------------------------------
if not dfhack.isMapLoaded() then
    qerror("World and map aren't loaded.")
end

if not dfhack.world.isFortressMode() then
    qerror('This script can only be used in fortress mode')
end

-- ---------------------------------------------------------------------------
-- File helpers
-- ---------------------------------------------------------------------------

-- Safely copy a single file using 4 MB chunks to avoid memory spikes.
local function copyFile(src, dst)
    local infile = io.open(src, "rb")
    if not infile then return false end
    local outfile = io.open(dst, "wb")
    if not outfile then
        infile:close()
        return false
    end

    while true do
        local chunk = infile:read(4096 * 1024)
        if not chunk then break end
        outfile:write(chunk)
    end

    infile:close()
    outfile:close()
    return true
end

-- Recursively copy a directory tree.
local function copyDir(src, dst)
    if not dfhack.filesystem.exists(dst) then
        dfhack.filesystem.mkdir(dst)
    end

    local items = dfhack.filesystem.listdir(src)
    for _, item in ipairs(items or {}) do
        local name = type(item) == "table" and item.name or item
        local isdir = type(item) == "table" and item.isdir
                      or dfhack.filesystem.isdir(src .. "/" .. name)
        if name ~= "." and name ~= ".." then
            local src_path = src .. "/" .. name
            local dst_path = dst .. "/" .. name
            if isdir then
                copyDir(src_path, dst_path)
            else
                copyFile(src_path, dst_path)
            end
        end
    end
end

-- Recursively delete a directory tree. Returns true on success.
local function deleteDir(path)
    local items = dfhack.filesystem.listdir(path)
    for _, item in ipairs(items or {}) do
        local name = type(item) == "table" and item.name or item
        local isdir = type(item) == "table" and item.isdir
                      or dfhack.filesystem.isdir(path .. "/" .. name)
        if name ~= "." and name ~= ".." then
            local child = path .. "/" .. name
            if isdir then
                deleteDir(child)
            else
                os.remove(child)
            end
        end
    end
    return dfhack.filesystem.rmdir(path)
end

-- ---------------------------------------------------------------------------
-- Save-directory resolution
-- ---------------------------------------------------------------------------

-- DF Premium stores saves under %APPDATA%/Bay 12 Games/Dwarf Fortress/save.
-- Classic/portable installs keep them next to the executable.
local function getTrueSaveDir()
    local appdata = os.getenv("APPDATA")
    if appdata then
        local appdata_save = appdata .. "/Bay 12 Games/Dwarf Fortress/save"
        if dfhack.filesystem.exists(appdata_save .. "/current") then
            return appdata_save
        end
    end
    return dfhack.getDFPath() .. "/save"
end

-- Return the name of the most-recently-modified save folder.
local function getNewestSaveFolder(save_dir)
    local items = dfhack.filesystem.listdir(save_dir)
    local newest_time = 0
    local newest_folder = nil

    for _, item in ipairs(items or {}) do
        local name = type(item) == "table" and item.name or item
        local isdir = type(item) == "table" and item.isdir
                      or dfhack.filesystem.isdir(save_dir .. "/" .. name)

        if isdir and name ~= "." and name ~= ".." and name ~= "current" then
            local wpath = save_dir .. "/" .. name .. "/world.sav"
            if dfhack.filesystem.exists(wpath) then
                local mtime = dfhack.filesystem.mtime(wpath)
                if mtime > newest_time then
                    newest_time = mtime
                    newest_folder = name
                end
            end
        end
    end
    return newest_folder
end

-- ---------------------------------------------------------------------------
-- Cleanup logic
-- ---------------------------------------------------------------------------

-- Prune old manual-save snapshots, keeping only `keep` most recent.
local function pruneManualSaves(save_dir, keep)
    local items = dfhack.filesystem.listdir(save_dir)
    local manual_saves = {}

    for _, item in ipairs(items or {}) do
        local name = type(item) == "table" and item.name or item
        local isdir = type(item) == "table" and item.isdir
                      or dfhack.filesystem.isdir(save_dir .. "/" .. name)

        -- Only touch directories whose name contains "-Manual-"
        if isdir and name:find("-Manual-") then
            local wpath = save_dir .. "/" .. name .. "/world.sav"
            local mtime = 0
            if dfhack.filesystem.exists(wpath) then
                mtime = dfhack.filesystem.mtime(wpath)
            end
            table.insert(manual_saves, {name = name, mtime = mtime})
        end
    end

    -- Sort newest first
    table.sort(manual_saves, function(a, b) return a.mtime > b.mtime end)

    -- Delete everything past the keep threshold
    for idx = keep + 1, #manual_saves do
        local target = save_dir .. "/" .. manual_saves[idx].name
        print("Pruning old snapshot: " .. manual_saves[idx].name)
        deleteDir(target)
    end

    if #manual_saves > keep then
        print(("Pruned %d old snapshot(s), %d remaining."):format(
            #manual_saves - keep, keep))
    end
end

-- ---------------------------------------------------------------------------
-- Main
-- ---------------------------------------------------------------------------

local function triggerManualSave()
    local ui_main = df.global.plotinfo.main
    local fort_name = dfhack.df2utf(
        dfhack.translation.translateName(
            df.global.world.world_data.active_site[0].name, true))

    -- Sanitise for filesystem safety
    fort_name = fort_name:gsub("[^%w%s%-]", ""):gsub("%s+", "_")

    local date_str = os.date("%Y-%m-%d_%H-%M-%S")
    local final_folder_name = positional_name or (fort_name .. "-Manual-" .. date_str)

    print("Initiating autosave snapshot process...")
    print("Will create manual save at: " .. final_folder_name)

    -- Request the native autosave (same mechanism as quicksave)
    ui_main.autosave_request = true
    ui_main.autosave_timer = 5
    ui_main.save_progress.substage = 0
    ui_main.save_progress.stage = 0
    ui_main.save_progress.info.nemesis_save_file_id:resize(0)
    ui_main.save_progress.info.nemesis_member_idx:resize(0)
    ui_main.save_progress.info.units:resize(0)
    ui_main.save_progress.info.cur_unit_chunk = nil
    ui_main.save_progress.info.cur_unit_chunk_num = -1
    ui_main.save_progress.info.units_offloaded = -1

    -- The game freezes its simulation loop while saving. These 10 frames
    -- will only tick down after the save is 100% written and the game
    -- unfreezes, guaranteeing a clean copy source.
    dfhack.timeout(10, 'frames', function()
        local true_save_dir = getTrueSaveDir()
        local newest_folder = getNewestSaveFolder(true_save_dir)
        if newest_folder then
            local src_dir = true_save_dir .. "/" .. newest_folder
            local dst_dir = true_save_dir .. "/" .. final_folder_name

            print("Autosave complete. Duplicating '" .. newest_folder .. "' to snapshot...")
            copyDir(src_dir, dst_dir)
            print("Manual save completed successfully: " .. final_folder_name)

            if cleanup_count then
                pruneManualSaves(true_save_dir, cleanup_count)
            end
        else
            dfhack.printerr("Error: Could not locate the freshly saved folder.")
        end
    end)
end

triggerManualSave()
