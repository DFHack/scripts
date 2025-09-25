-- Save the data of a selected unit or item in JSON file in UTF-8
-- This script extracts the data of a selected unit or item and saves it
-- as a JSON file encoded in UTF-8 in the root game directory.

local gui = require('gui')
local argparse = require('argparse')
local json = require('json')

local help = false
local positionals = argparse.processArgsGetopt({ ... }, {
    {'h', 'help',      handler=function() help = true end},
})

if help then
    print(dfhack.script_help())
    return
end

-- Variables for clicking and gathering data
local gps = df.global.gps
local mi = df.global.game.main_interface
local screen = dfhack.gui.getDFViewscreen()
local windowSize = dfhack.screen.getWindowSize()
local filename = ''

local data = {}

local base_offsets = {
    status = { x_offset = 74, y = 15 }, -- health page
    wounds = { x_offset = 84, y = 17 },
    treatment = { x_offset = 73, y = 17 },
    history = { x_offset = 62, y = 17 },
    description = { x_offset = 50, y = 17 },
    traits = { x_offset = 47, y = 13 }, -- personality page
    values = { x_offset = 84, y = 17 },
    preferences = { x_offset = 72, y = 17 },
    needs = { x_offset = 59, y = 17 },
    thoughts = { x_offset = 60, y = 13 },
    memories = { x_offset = 74, y = 17 },
    current_thought = { x_offset = 92, y = 15 } -- Overview page
}

-- Utility functions
local function getFileHandle(filename)
    local handle, error = io.open(filename, 'r+')
    if not handle and error:match("No such file or directory") then
        -- If the file doesn't exist, create it
        handle, error = io.open(filename, 'w+')
    end
    if not handle then
        qerror("Error opening file: " .. filename .. ". " .. error)
    end
    return handle
end

local function readExistingData(handle)
    local content = handle:read("*a")
    handle:seek("set", 0)  -- Reset file pointer to start
    if content and #content > 0 then
        return json.decode(content)
    end
    return {}
end

local function closeFileHandle(handle, data, filename)
    handle:seek("set", 0)  -- Reset file pointer to start
    handle:write(json.encode(data))
    handle:close()
    print('\nData appended in "' .. 'Dwarf Fortress/' .. filename .. '"')
end

local function reformat(str)
    return str:gsub('%[B%]', '\n\n')
        :gsub('%[R%]', '\n\n')
        :gsub('%[P%]', '')
        :gsub('%[C:%d+:%d+:%d+%]', '')
        :gsub('\n\n+', '\n\n')
end

local function clickAndLog(screen, windowSize, xOffset, y, logTitle, rawStringAccessor)
    gps.mouse_x = windowSize - xOffset
    gps.mouse_y = y
    gui.simulateInput(screen, '_MOUSE_L')

    local raw_data = rawStringAccessor()

    data[logTitle] = {}
    if type(raw_data) == 'string' and raw_data ~= '' then
        data[logTitle] = reformat(dfhack.df2utf(raw_data))
    elseif type(raw_data) == 'userdata' and #raw_data > 0 then
        local concat_data = ''
        for i = 0, #raw_data - 1 do
            concat_data = concat_data .. reformat(dfhack.df2utf(raw_data[i].value))
        end
        data[logTitle] = concat_data
    else
        data[logTitle] = ''
    end
end

local function get_offsets(is_big_portrait, entry)
    local base = base_offsets[entry]
    if is_big_portrait then
        return base.x_offset, base.y
    else
        return base.x_offset, base.y - 2
    end
end

local function getSexString(sex)
    if sex == -1 then
      return "none"
    elseif sex == 0 then
      return "female"
    elseif sex == 1 then
      return "male"
    end
end

local function get_skill_rating_name(rating)
    local rating_table = {
        [0] = "Dabbling",
        [1] = "Novice",
        [2] = "Adequate",
        [3] = "Competent",
        [4] = "Skilled",
        [5] = "Proficient",
        [6] = "Talented",
        [7] = "Adept",
        [8] = "Expert",
        [9] = "Professional",
        [10] = "Accomplished",
        [11] = "Great",
        [12] = "Master",
        [13] = "High Master",
        [14] = "Grand Master",
    }
    return rating_table[rating] or "Legendary"
end

local function serialize_skills(unit)
    if not unit or not unit.status or not unit.status.current_soul then
        return ''
    end
    local skills = {}
    for _, skill in ipairs(unit.status.current_soul.skills) do
        if skill.rating > 0 then -- ignore dabbling
            skills[df.job_skill[skill.id]] = {
                rating = skill.rating,
                rating_name = get_skill_rating_name(skill.rating),
            }
        end
    end
    return skills
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
    return
end

local identifier = nil

if item then
    -- Item processing
    local itemRawName = dfhack.items.getDescription(item, 0, true)
    local itemRawDescription = mi.view_sheets.raw_description
    data = {
        id = item.id,
        name = dfhack.df2utf(itemRawName),
        description = reformat(dfhack.df2utf(itemRawDescription))
    }
    print('Exporting description of the ' .. itemRawName)
    filename = 'items.json'
    identifier = item.id
elseif unit then
    -- Get data from unit
    data = {
        id = unit.id,
        name = dfhack.units.getReadableName(unit),
        age = df.global.cur_year - unit.birth_year,
        sex = getSexString(unit.sex),
        profession = dfhack.units.getProfessionName(unit),
        -- skills = serialize_skills(unit),
        race = df.creature_raw.find(unit.race).name[0]
    }

    -- Get data from view_sheets
    local is_big_portrait = unit.portrait_texpos > 0 and true or false

    -- for _, entry in ipairs({"status", "wounds", "treatment", "history", "description"}) do
    --     local x_offset, y = get_offsets(is_big_portrait, entry)
    --     clickAndLog(screen, windowSize, x_offset, y, entry, function()
    --         return mi.view_sheets.unit_health_raw_str
    --     end)
    -- end

    -- for _, entry in ipairs({"traits", "values", "preferences", "needs"}) do
    --     local x_offset, y = get_offsets(is_big_portrait, entry)
    --     clickAndLog(screen, windowSize, x_offset, y, entry, function()
    --         return mi.view_sheets.personality_raw_str
    --     end)
    -- end

    -- local thoughts_x_offset, thoughts_y = get_offsets(is_big_portrait, 'thoughts')
    -- clickAndLog(screen, windowSize, thoughts_x_offset, thoughts_y, 'thoughts', function()
    --     return mi.view_sheets.raw_thought_str
    -- end)

    -- local memories_x_offset, memories_y = get_offsets(is_big_portrait, 'memories')
    -- clickAndLog(screen, windowSize, memories_x_offset, memories_y, 'memories', function()
    --     return mi.view_sheets.thoughts_raw_memory_str
    -- end)

    local current_thought_x_offset, current_thought_y = get_offsets(is_big_portrait, 'current_thought')
    clickAndLog(screen, windowSize, current_thought_x_offset, current_thought_y, 'current_thought', function()
        return mi.view_sheets.raw_current_thought
    end)

    filename = 'units.json'
    identifier = unit.id
end

local log = getFileHandle(filename)
local existingData = readExistingData(log)

local updated = false
if data.id then
    for index, entry in ipairs(existingData) do
        if entry.id == identifier then
            -- Update the existing entry
            existingData[index] = data
            updated = true
            break
        end
    end
else
    updated = true
end

if not updated then
    table.insert(existingData, data)
end

closeFileHandle(log, existingData, filename)
