-- Create a named manual save that won't be overwritten by autosaves.
--[====[
manual-save
===========

Tags: fort | dfhack

Creates a persistent, named save snapshot that will not be overwritten
by future autosaves. The save is created natively by injecting the save
command directly into the game's UI state.

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
local gui = require("gui")

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
    local fort_name = dfhack.df2utf(
        dfhack.translation.translateName(
            df.global.world.world_data.active_site[0].name, true))

    -- Sanitise for filesystem safety
    fort_name = fort_name:gsub("[^%w%s%-]", ""):gsub("%s+", "_")

    local date_str = os.date("%Y-%m-%d_%H-%M-%S")
    local final_folder_name = positional_name or (fort_name .. "-Manual-" .. date_str)

    print("Initiating manual save...")
    print("Saving natively to: " .. final_folder_name)

    -- Inject the text and trigger the save UI natively
    local options = df.global.game.main_interface.options
    options.open = true
    options.entering_manual_folder = true
    options.entering_manual_str = final_folder_name

    -- Simulate pressing Enter to confirm the text box and trigger the save
    gui.simulateInput(dfhack.gui.getCurViewscreen(true), 'SELECT')

    -- The game freezes its simulation loop while saving. These 10 frames
    -- will only tick down after the save is 100% written and the game unfreezes.
    dfhack.timeout(10, 'frames', function()
        print("Manual save completed successfully: " .. final_folder_name)

        if cleanup_count then
            pruneManualSaves(getTrueSaveDir(), cleanup_count)
        end
    end)
end

triggerManualSave()
