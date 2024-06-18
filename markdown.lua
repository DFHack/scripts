-- Save the description of a selected unit or item in Markdown file in UTF-8
-- This script extracts the description of a selected unit or item and saves it
-- as a Markdown file encoded in UTF-8 in the root game directory.

local gui = require('gui')
local argparse = require('argparse')

-- Get world name for default filename
local worldName = dfhack.df2utf(dfhack.TranslateName(df.global.world.world_data.name)):gsub(" ", "_")

local help, overwrite, filenameArg = false, false, nil
local positionals = argparse.processArgsGetopt({ ... }, {
    {'o', 'overwrite', handler=function() overwrite = true end},
    {'h', 'help',      handler=function() help = true end},
})

-- Extract non-option arguments (filename)
filenameArg = positionals[1]

if help then
    print(dfhack.script_help())
    return
end

-- Determine write mode and filename
local writemode = overwrite and 'w' or 'a'
local filename = 'markdown_' .. (filenameArg or worldName) .. '.md'

-- Utility functions
local function getFileHandle()
    local handle, error = io.open(filename, writemode)
    if not handle then
        qerror("Error opening file: " .. filename .. ". " .. error)
    end
    return handle
end

local function closeFileHandle(handle)
    handle:write('\n---\n\n')
    handle:close()
    if writemode == 'a' then
        print('\nData appended to "' .. 'Dwarf Fortress/' .. filename .. '"')
    elseif writemode == 'w' then
        print('\nData overwritten in "' .. 'Dwarf Fortress/' .. filename .. '"')
    end
end

local function reformat(str)
    -- [B] tags seem to indicate a new paragraph
    -- [R] tags seem to indicate a sub-blocks of text.Treat them as paragraphs.
    -- [P] tags seem to be redundant
    -- [C] tags indicate color. Remove all color information
    return str:gsub('%[B%]', '\n\n')
        :gsub('%[R%]', '\n\n')
        :gsub('%[P%]', '')
        :gsub('%[C:%d+:%d+:%d+%]', '')
        :gsub('\n\n+', '\n\n')
end

local function getNameRaceAgeProf(unit)
    --%s is a placeholder for a string, and %d is a placeholder for a number.
    return string.format("%s, %d years old %s.", dfhack.units.getReadableName(unit), df.global.cur_year - unit
        .birth_year, dfhack.units.getProfessionName(unit))
end

-- Main logic for item and unit processing
local item = dfhack.gui.getSelectedItem(true)
local unit = dfhack.gui.getSelectedUnit(true)

if not item and not unit then
    dfhack.printerr([[
Error: No unit or item is currently selected.
- To select a unit, click on it.
- For items that are installed as buildings (like statues or beds),
open the building's interface and click the magnifying glass icon.
Please select a valid target and try running the script again.]])
    -- Early return to avoid proceeding further if no unit or item is selected
    return
end

local log = getFileHandle()

local gps = df.global.gps
local mi = df.global.game.main_interface

if item then
    -- Item processing
    local itemRawName = dfhack.items.getDescription(item, 0, true)
    local itemRawDescription = mi.view_sheets.raw_description
    log:write('### ' ..
        dfhack.df2utf(itemRawName) .. '\n\n#### Description: \n' .. reformat(dfhack.df2utf(itemRawDescription)) .. '\n')
    print('Exporting description of the ' .. itemRawName)
elseif unit then
    -- Unit processing
    -- Simulate UI interactions to load data into memory (click through tabs). Note: Constant might change with DF updates/patches
    local is_adv = dfhack.world.isAdventureMode()
    local screen = dfhack.gui.getDFViewscreen()
    local windowSize = dfhack.screen.getWindowSize()

    -- Click "Personality"
    local personalityWidthConstant = is_adv and 68 or 48
    local personalityHeightConstant = is_adv and 13 or 11

    gps.mouse_x = windowSize - personalityWidthConstant
    gps.mouse_y = personalityHeightConstant

    gui.simulateInput(screen, '_MOUSE_L')

    -- Click "Health"
    local healthWidthConstant = 74
    local healthHeightConstant = is_adv and 15 or 13

    gps.mouse_x = windowSize - healthWidthConstant
    gps.mouse_y = healthHeightConstant

    gui.simulateInput(screen, '_MOUSE_L')

    -- Click "Health/Description"
    local healthDescriptionWidthConstant = is_adv and 74 or 51
    local healthDescriptionHeightConstant = is_adv and 17 or 15

    gps.mouse_x = windowSize - healthDescriptionWidthConstant
    gps.mouse_y = healthDescriptionHeightConstant

    gui.simulateInput(screen, '_MOUSE_L')

    local unit_description_raw = #mi.view_sheets.unit_health_raw_str > 0 and mi.view_sheets.unit_health_raw_str[0].value or ''
    local unit_personality_raw = mi.view_sheets.personality_raw_str

    log:write('### ' ..
        dfhack.df2utf(getNameRaceAgeProf(unit)) ..
        '\n\n#### Description: \n' .. reformat(dfhack.df2utf(unit_description_raw)) .. '\n')
    if #unit_personality_raw > 0 then
        log:write('\n#### Personality: \n')
        for _, unit_personality in ipairs(unit_personality_raw) do
            log:write(reformat(dfhack.df2utf(unit_personality.value)) .. '\n')
        end
    end
    print('Exporting Health/Description & Personality/Traits data for: \n' .. dfhack.df2console(getNameRaceAgeProf(unit)))
end

closeFileHandle(log)
