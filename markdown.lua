-- Save selected unit/item' description in markdown (e.g., for reddit)
-- This script extracts descriptions of selected units or items and saves them in markdown format.
-- This is a derivatiwe work based upon scripts/forum-dwarves.lua by Caldfir and expwnent
-- Adapted for markdown by Mchl https://github.com/Mchl
-- Updated to work with Steam version by Glotov4 https://github.com/glotov4 

local utils = require('utils')
local gui = require('gui')
local worldName = dfhack.df2utf(dfhack.TranslateName(df.global.world.world_data.name)):gsub(" ", "_")

-- Argument processing
local args = {...}
if args[1] ~= nil then
    local userProvidedName = table.remove(args, 1)
    userProvidedName = string.gsub(userProvidedName, " ", "_")
    filename = 'markdown_' .. userProvidedName .. '.md'
else
    filename = 'markdown_' .. worldName .. '_export.md'
end

-- Determine file write mode and filename
local writemode = 'a' -- append (default)
local filename

if args[1] == '-o' or args[1] == '/n' then
    writemode = 'w' -- overwrite
    table.remove(args, 1)
end

if args[1] ~= nil then
    filename = 'markdown_' .. table.remove(args, 1) .. '.md'
else
    filename = 'markdown_' .. worldName .. '_export.md'
end

-- Utility functions
local function getFileHandle()
    return assert(io.open(filename, writemode), "Error opening file: " .. filename)
end

local function closeFileHandle(handle)
    handle:write('\n---\n\n')
    handle:close()
    print ('\nData exported to "' .. filename .. '"')
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
    return string.format("%s, %d years old %s.", dfhack.units.getReadableName(unit), df.global.cur_year - unit.birth_year, dfhack.units.getProfessionName(unit))
end

-- Main logic for item and unit processing
local item = dfhack.gui.getSelectedItem(true)
local unit = dfhack.gui.getSelectedUnit(true)

if not item and not unit then
    print([[
Error: No unit or item is currently selected.
- To select a unit, click on it.
- For items that are installed as buildings (like statues or beds), 
open the building's interface in the game and click the magnifying glass icon.

Please select a valid target in the game and try running the script again.]])
    -- Early return to avoid proceeding further if no unit or item is selected
    return
end

local log = getFileHandle()

if item then
    -- Item processing
    local itemRawName = dfhack.items.getDescription(item, 0, true)
    local itemRawDescription = df.global.game.main_interface.view_sheets.raw_description
    log:write('### ' .. dfhack.df2utf(itemRawName) .. '\n\n#### Description: \n' .. reformat(dfhack.df2utf(itemRawDescription)) .. '\n')
    print('Exporting description of the ' .. itemRawName)

elseif unit then   
    -- Unit processing
    -- Simulate UI interactions to load data into memory (click through tabs). Note: Constant might change with DF updates/patches
    local screen = dfhack.gui.getDFViewscreen()
    local windowSize = dfhack.screen.getWindowSize()

    -- Click "Personality"
    local personalityWidthConstant = 48
    local personalityHeightConstant = 11

    df.global.gps.mouse_x = windowSize - personalityWidthConstant
    df.global.gps.mouse_y = personalityHeightConstant

    gui.simulateInput(screen, '_MOUSE_L')

    -- Click "Health"
    local healthWidthConstant = 74
    local healthHeightConstant = 13

    df.global.gps.mouse_x = windowSize - healthWidthConstant
    df.global.gps.mouse_y = healthHeightConstant

    gui.simulateInput(screen, '_MOUSE_L')

    -- Click "Health/Description"
    local healthDescriptionWidthConstant = 51
    local healthDescriptionHeightConstant = 15

    df.global.gps.mouse_x = windowSize - healthDescriptionWidthConstant
    df.global.gps.mouse_y = healthDescriptionHeightConstant

    gui.simulateInput(screen, '_MOUSE_L')

    local unit_description_raw = df.global.game.main_interface.view_sheets.unit_health_raw_str[0].value
    local unit_personality_raw = df.global.game.main_interface.view_sheets.personality_raw_str

    log:write('### ' .. dfhack.df2utf(getNameRaceAgeProf(unit)) .. '\n\n#### Description: \n' .. reformat(dfhack.df2utf(unit_description_raw)) .. '\n\n#### Personality: \n')
    for _, unit_personality in ipairs(unit_personality_raw) do
        log:write(reformat(dfhack.df2utf(unit_personality.value)) .. '\n')
    end
    print('Exporting Health/Description & Personality/Traits data for: \n' .. dfhack.df2console(getNameRaceAgeProf(unit)))
else end
closeFileHandle(log)