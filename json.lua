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
    local handle, error = io.open(filename, 'w')
    if not handle then
        qerror("Error opening file: " .. filename .. ". " .. error)
    end
    return handle
end

local function closeFileHandle(handle, data, filename)
    handle:write(json.encode(data))
    handle:close()
    print('\nData overwritten in "' .. 'Dwarf Fortress/' .. filename .. '"')
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

if item then
    -- Item processing
    local itemRawName = dfhack.items.getDescription(item, 0, true)
    local itemRawDescription = mi.view_sheets.raw_description
    data = {
        item = item.id,
        name = dfhack.df2utf(itemRawName),
        description = reformat(dfhack.df2utf(itemRawDescription))
    }
    print('Exporting description of the ' .. itemRawName)
    filename = 'item_' .. item.id .. '.json'
elseif unit then
    -- Get data from unit
    data['id'] = {}
    data['id'] = unit.id
    data['name'] = {}
    data['name'] = dfhack.units.getReadableName(unit)
    data['age'] = {}
    data['age'] = df.global.cur_year - unit.birth_year
    data['sex'] = {}
    data['sex'] = getSexString(unit.sex)
    data['profession'] = {}
    data['profession'] = dfhack.units.getProfessionName(unit)
    data['skills'] = serialize_skills(unit)
    data['race'] = {}
    data['race'] = df.creature_raw.find(unit.race).name[0]
    data['isCitizen'] = {}
    data['isCitizen'] = dfhack.units.isCitizen(unit)
    data['isResident'] = {}
    data['isResident'] = dfhack.units.isResident(unit)
    data['isAlive'] = {}
    data['isAlive'] = dfhack.units.isAlive(unit)
    data['isDead'] = {}
    data['isDead'] = dfhack.units.isDead(unit)
    data['isKilled'] = {}
    data['isKilled'] = dfhack.units.isKilled(unit)
    data['isSane'] = {}
    data['isSane'] = dfhack.units.isSane(unit)
    data['isCrazed'] = {}
    data['isCrazed'] = dfhack.units.isCrazed(unit)
    data['isGhost'] = {}
    data['isGhost'] = dfhack.units.isGhost(unit)
    data['isBaby'] = {}
    data['isBaby'] = dfhack.units.isBaby(unit)
    data['isChild'] = {}
    data['isChild'] = dfhack.units.isChild(unit)
    data['isAdult'] = {}
    data['isAdult'] = dfhack.units.isAdult(unit)
    data['isGay'] = {}
    data['isGay'] = dfhack.units.isGay(unit)
    data['isNaked'] = {}
    data['isNaked'] = dfhack.units.isNaked(unit)
    data['isForest'] = {}
    data['isForest'] = dfhack.units.isForest(unit)
    data['isMischievous'] = {}
    data['isMischievous'] = dfhack.units.isMischievous(unit)
    data['isOpposedToLife'] = {}
    data['isOpposedToLife'] = dfhack.units.isOpposedToLife(unit)
    data['isBloodsucker'] = {}
    data['isBloodsucker'] = dfhack.units.isBloodsucker(unit)
    data['isDwarf'] = {}
    data['isDwarf'] = dfhack.units.isDwarf(unit)
    data['isMerchant'] = {}
    data['isMerchant'] = dfhack.units.isMerchant(unit)
    data['isDiplomat'] = {}
    data['isDiplomat'] = dfhack.units.isDiplomat(unit)
    data['isVisitor'] = {}
    data['isVisitor'] = dfhack.units.isVisitor(unit)
    data['isInvader'] = {}
    data['isInvader'] = dfhack.units.isInvader(unit)
    data['isUndead'] = {}
    data['isUndead'] = dfhack.units.isUndead(unit)
    data['isNightCreature'] = {}
    data['isNightCreature'] = dfhack.units.isNightCreature(unit)
    data['isSemiMegabeast'] = {}
    data['isSemiMegabeast'] = dfhack.units.isSemiMegabeast(unit)
    data['isMegabeast'] = {}
    data['isMegabeast'] = dfhack.units.isMegabeast(unit)
    data['isTitan'] = {}
    data['isTitan'] = dfhack.units.isTitan(unit)
    data['isForgottenBeast'] = {}
    data['isForgottenBeast'] = dfhack.units.isForgottenBeast(unit)
    data['isDemon'] = {}
    data['isDemon'] = dfhack.units.isDemon(unit)
    data['isDanger'] = {}
    data['isDanger'] = dfhack.units.isDanger(unit)

    data['isAnimal'] = {}
    data['isAnimal'] = dfhack.units.isAnimal(unit)
    if data['isAnimal'] then
        data['isAvailableForAdoption'] = {}
        data['isAvailableForAdoption'] = dfhack.units.isAvailableForAdoption(unit)
        data['isPet'] = {}
        data['isPet'] = dfhack.units.isPet(unit)
        data['isWar'] = {}
        data['isWar'] = dfhack.units.isWar(unit)
        data['isTame'] = {}
        data['isTame'] = dfhack.units.isTame(unit)
        data['isTamable'] = {}
        data['isTamable'] = dfhack.units.isTamable(unit)
        data['isDomesticated'] = {}
        data['isDomesticated'] = dfhack.units.isDomesticated(unit)
        data['isTrained'] = {}
        data['isTrained'] = dfhack.units.isTrained(unit)
        data['isHunter'] = {}
        data['isHunter'] = dfhack.units.isHunter(unit)
        data['isGelded'] = {}
        data['isGelded'] = dfhack.units.isGelded(unit)
        data['isEggLayer'] = {}
        data['isEggLayer'] = dfhack.units.isEggLayer(unit)
        data['isEggLayerRace'] = {}
        data['isEggLayerRace'] = dfhack.units.isEggLayerRace(unit)
        data['isGrazer'] = {}
        data['isGrazer'] = dfhack.units.isGrazer(unit)
        data['isMilkable'] = {}
        data['isMilkable'] = dfhack.units.isMilkable(unit)
    end

    -- Get data from view_sheets
    local is_big_portrait = unit.portrait_texpos > 0 and true or false

    for _, entry in ipairs({"status", "wounds", "treatment", "history", "description"}) do
        local x_offset, y = get_offsets(is_big_portrait, entry)
        clickAndLog(screen, windowSize, x_offset, y, entry, function()
            return mi.view_sheets.unit_health_raw_str
        end)
    end

    for _, entry in ipairs({"traits", "values", "preferences", "needs"}) do
        local x_offset, y = get_offsets(is_big_portrait, entry)
        clickAndLog(screen, windowSize, x_offset, y, entry, function()
            return mi.view_sheets.personality_raw_str
        end)
    end

    local thoughts_x_offset, thoughts_y = get_offsets(is_big_portrait, 'thoughts')
    clickAndLog(screen, windowSize, thoughts_x_offset, thoughts_y, 'thoughts', function()
        return mi.view_sheets.raw_thought_str
    end)

    local memories_x_offset, memories_y = get_offsets(is_big_portrait, 'memories')
    clickAndLog(screen, windowSize, memories_x_offset, memories_y, 'memories', function()
        return mi.view_sheets.thoughts_raw_memory_str
    end)

    local current_thought_x_offset, current_thought_y = get_offsets(is_big_portrait, 'current_thought')
    clickAndLog(screen, windowSize, current_thought_x_offset, current_thought_y, 'current_thought', function()
        return mi.view_sheets.raw_current_thought
    end)

    filename = 'unit_' .. unit.id .. '.json'
end

local log = getFileHandle(filename)
closeFileHandle(log, data, filename)
