-- Color schemes manager.

--[[
Copyright (c) 2016, 2020 Milo Christiansen, Nicolas Ayala `https://github.com/nicolasayala`, with modifications (c) 2026 by Susan et al.

This software is provided 'as-is', without any express or implied
warranty. In no event will the authors be held liable for any damages
arising from the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not
   claim that you wrote the original software. If you use this software
   in a product, an acknowledgment in the product documentation would be
   appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be
   misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
]]

--@ module = true

local INITIAL_DEFAULT_COLOR_SCHEME_LOCATION = dfhack.getDFPath() .. "/data/init/colors.txt"
local DEFAULT_COLOR_SCHEME_LOCATION = dfhack.getDFPath() .. "/prefs/colors.txt"

--use the new api, if we have it
local CONFIG_PATH = (dfhack.getConfigPath ~= nil) and dfhack.getConfigPath() or (dfhack.getDFPath() .. "/dfhack-config/")

--- Directory to search for color schemes in.
COLOR_SCHEME_DIR = CONFIG_PATH .. "color-schemes/"

--- The location of the initial color scheme; prefs/color.txt if it exists, or the dwarf fortress default if not.
local function initial_color_scheme_location()
    if dfhack.filesystem.isfile(DEFAULT_COLOR_SCHEME_LOCATION) then
        return DEFAULT_COLOR_SCHEME_LOCATION
    else
        -- fallback to dwarf fortress default
        return INITIAL_DEFAULT_COLOR_SCHEME_LOCATION
    end
end

--- The location of the currently active color scheme. read only; to set the active color scheme, use load_color_scheme_from_path.
current_color_scheme_location = current_color_scheme_location or initial_color_scheme_location()

local SCHEME_COLORS = {
    ["BLACK"] = 0,
    ["BLUE"] = 1,
    ["GREEN"] = 2,
    ["CYAN"] = 3,
    ["RED"] = 4,
    ["MAGENTA"] = 5,
    ["BROWN"] = 6,
    ["LGRAY"] = 7,
    ["DGRAY"] = 8,
    ["LBLUE"] = 9,
    ["LGREEN"] = 10,
    ["LCYAN"] = 11,
    ["LRED"] = 12,
    ["LMAGENTA"] = 13,
    ["YELLOW"] = 14,
    ["WHITE"] = 15,
}

local SCHEME_CHANNELS = {
    ["R"] = 0,
    ["G"] = 1,
    ["B"] = 2,
}

--- Get a file handle, looking in COLOR_SCHEME_DIR first, and appending .txt if needed
local function get_file_from_path(path, suppress_errors)
    if path:endswith(".txt") == false then
        -- color schemes always have the .txt extension, so append it if it's not there already.
        path = path .. ".txt"
    end

    local file, _ = io.open(COLOR_SCHEME_DIR .. path, "rb")
    if file ~= nil then
        return file
    end

    local file, err = io.open(path, "rb")
    if file ~= nil then
        return file
    end

    if suppress_errors == false then
        dfhack.printerr("color-schemes: could not load " .. err)
    end

    return nil
end

--- Parse the file at the specified path to a color scheme. returns nil on errors.
local function parse_color_scheme(path, quiet, suppress_errors)
    local file = get_file_from_path(path, suppress_errors)
    if file == nil then
        return nil
    end

    -- NOTE: why is this "*a" and not "a"?
    local contents = file:read("*a")
    file:close()

    -- initalise result
    local result = {}
    for color, index in pairs(SCHEME_COLORS) do
        result[color] = {R = -1, G = -1, B = -1}
    end

    local count = 0

    for color, channel, v in string.gmatch(contents, "%[([A-Z]+)_([RGB]):([0-9]+)%]") do
        local color_index, channel_index, v = SCHEME_COLORS[color], SCHEME_CHANNELS[channel], tonumber(v)
        if color_index == nil or channel_index == nil or v == nil then
            -- Parse error.
            if suppress_errors == false then
                dfhack.printerr("color-schemes: " .. path .. " is not a valid color scheme!")
            end
            return nil
        end

        -- clamp values
        if v > 255 then
            v = 255
            if quiet ~= true then
                dfhack.println("color-schemes: Warning: The " .. channel .. " component for color " .. color .. " is out of range! Adjusting...")
            end
        end

        result[color][channel] = v
        count = count + 1
    end

    -- check count
    local VALID_COUNT = 48 -- #SCHEME_COLORS * #SCHEME_CHANNELS = 16 * 3 = 48
    if count ~= VALID_COUNT then
        if suppress_errors == false then
            dfhack.printerr("color-schemes: " .. path .. " is not a valid color scheme! (are there missing entries?)")
        end
        return nil
    end

    return result
end

--- List color schemes found in the COLOR_SCHEME_DIR directory.
function available_color_schemes()
    local list = dfhack.filesystem.listdir_recursive(COLOR_SCHEME_DIR) or {}

    local result = {}
    for _, entry in ipairs(list) do
        if entry.isdir == false then
            if string.match (entry.path, ".txt") then
                -- parsing every file to see if it's valid is wasteful, but it's either this or registration...
                local scheme = parse_color_scheme(entry.path, true, true)
                if scheme ~= nil then
                    -- remove the COLOR_SCHEME_DIR prefix
                    local stripped_path = entry.path:sub(#COLOR_SCHEME_DIR + 1)
                    -- remove the .txt extension
                    stripped_path = stripped_path:sub(0, -5) -- lua indexing is wacky...
                    dfhack.println(entry.path, COLOR_SCHEME_DIR)
                    result[#result + 1] = stripped_path
                end
            end
        end
    end

    return result
end

--- Set the active color scheme.
local function load_color_scheme(scheme)
    for color, color_index in pairs(SCHEME_COLORS) do
        for channel, channel_index in pairs(SCHEME_CHANNELS) do
            local value = scheme[color][channel]
            df.global.gps.uccolor[color_index][channel_index] = value
        end
    end
    -- NOTE i'm not sure why this is here, it doesn't seem to be required. possibly a leftover from when ccolor was used?
    df.global.gps.force_full_display_count = 1
end

--- Load a color scheme from the specified path.
function load_color_scheme_from_path(path, quiet)
    local scheme = parse_color_scheme(path, quiet, false)
    if scheme ~= nil then
        load_color_scheme(scheme)
        current_color_scheme_location = path
        if quiet ~= true then
            dfhack.println("color-schemes: loaded " .. path .. ".")
        end
    end
end

--- Load the default color scheme from prefs/color.txt if it exists, or the dwarf fortress default if not.
function load_default_color_scheme(quiet)
    load_color_scheme_from_path(initial_color_scheme_location(), quiet)
end

--- Overwrite the default color scheme with the specified file. Assumes that this is a valid scheme.
function set_default_color_scheme(path, quiet)
    local scheme_file, err = io.open(path, "rb")
    if scheme_file == nil then
        dfhack.printerr("color-schemes: could not read " .. path .. ": " .. err)
        return
    end

    local scheme_file_contents = scheme_file:read("a")
    scheme_file:close()

    local default_file, err = io.open(DEFAULT_COLOR_SCHEME_LOCATION, "w")
    if default_file == nil then
        dfhack.printerr("color-schemes: could not open " .. DEFAULT_COLOR_SCHEME_LOCATION .. ": " .. err)
        return
    end

    default_file:write(scheme_file_contents)
    default_file:close()

    if quiet ~= true then
        dfhack.println("color-schemes: set default scheme to" .. path .. ".")
    end
end

--- Reset the default color scheme to the one that comes with dwarf fortress.
function reset_default_color_scheme()
    set_default_color_scheme(INITIAL_DEFAULT_COLOR_SCHEME_LOCATION)
end

if dfhack_flags.module then
    return
end

local options = {}

local argparse = require('argparse')
local commands = argparse.processArgsGetopt({...}, {
    {'h', 'help', handler=function() options.help = true end},
    {'q', 'quiet', handler=function() options.quiet = true end},
})

if options.help == true then
    dfhack.println(dfhack.script_help())
    return
end

if commands[1] == "load" and #commands == 2 then
    local path = commands[2]
    load_color_scheme_from_path(path, options.quiet)
    return
end

if commands[1] == "list" and #commands == 1  then
    local list = available_color_schemes()
    for _, entry in ipairs(list) do
        dfhack.println(entry)
    end
    return
end

if commands[1] == "default" then
    if commands[2] == "load" and #commands == 2 then
        load_default_color_scheme(options.quiet)
        return
    end

    if commands[2] == "set" then
        if #commands == 2 then
            set_default_color_scheme(current_color_scheme_location, options.quiet)
            return
        end

        if #commands == 3 then
            local path = commands[3]
            set_default_color_scheme(path, options.quiet)
            return
        end
    end

    if commands[2] == "reset" and #commands == 2 then
        reset_default_color_scheme(options.quiet)
        return
    end
end

dfhack.println(dfhack.script_help())
