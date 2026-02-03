-- Writes the currently viewed unit or item flavor text to a file.
--
-- Usage:
--   flavor-text

local folder = 'flavor text'
local filename = 'read flavor.txt'
local filepath = folder .. '/' .. filename

local function clear_output_file()
    local ok, err = pcall(dfhack.filesystem.mkdir_recursive, folder)
    if not ok then
        qerror(('Failed to create folder "%s": %s'):format(folder, err))
    end
    local file, open_err = io.open(filepath, 'w')
    if not file then
        qerror(('Failed to open file "%s" for writing: %s'):format(filepath, open_err))
    end
    file:write('')
    file:close()
end

local function reformat(str)
    local cleaned = str:gsub('%[B%]', '')
        :gsub('%[P%]', '')
        :gsub('%[R%]', '')
        :gsub('%[C:%d+:%d+:%d+%]', '')
        :gsub('%s+', ' ')
        :gsub('^%s+', '')
        :gsub('%s+$', '')
    return cleaned
end

local function collect_lines(entries)
    local lines = {}
    for _, entry in ipairs(entries) do
        if entry.value ~= '' then
            local cleaned = reformat(dfhack.df2utf(entry.value))
            if cleaned ~= '' then
                table.insert(lines, cleaned)
            end
        end
    end
    return lines
end

local function get_health_text(view_sheets)
    if #view_sheets.unit_health_raw_str == 0 then
        return nil
    end
    local lines = collect_lines(view_sheets.unit_health_raw_str)
    if #lines == 0 then
        return nil
    end
    return table.concat(lines, '\n')
end

local function get_personality_text(view_sheets)
    if #view_sheets.personality_raw_str == 0 then
        return nil
    end
    local lines = collect_lines(view_sheets.personality_raw_str)
    if #lines == 0 then
        return nil
    end
    return table.concat(lines, '\n')
end

local UNIT_SHEET_SUBTAB = {
    HEALTH = 2,
    SKILLS = 3,
    PERSONALITY = 10,
}

local HEALTH_ACTIVE_TAB = {
    STATUS = 0,
    WOUNDS = 1,
    TREATMENT = 2,
    HISTORY = 3,
    DESCRIPTION = 4,
}

local PERSONALITY_ACTIVE_TAB = {
    TRAITS = 0,
    VALUES = 1,
    PREFERENCES = 2,
    NEEDS = 3,
}

local SKILL_ACTIVE_TAB = {
    KNOWLEDGE = 4,
}

local function get_skill_text(view_sheets)
    if #view_sheets.skill_description_raw_str == 0 then
        return nil
    end
    local lines = collect_lines(view_sheets.skill_description_raw_str)
    if #lines == 0 then
        return nil
    end
    return table.concat(lines, '\n')
end

local function get_unit_flavor_text(view_sheets)
    local unit = df.unit.find(view_sheets.active_id)
    if not unit then
        qerror('Unable to resolve the active unit.')
    end

    if view_sheets.active_sub_tab == UNIT_SHEET_SUBTAB.HEALTH then
        local health_text = get_health_text(view_sheets)
        if health_text then
            return unit, 'Health', health_text
        end
        clear_output_file()
        qerror('No text found on the Health tab.')
    end

    if view_sheets.active_sub_tab == UNIT_SHEET_SUBTAB.PERSONALITY
        and (view_sheets.personality_active_tab == PERSONALITY_ACTIVE_TAB.TRAITS
            or view_sheets.personality_active_tab == PERSONALITY_ACTIVE_TAB.VALUES
            or view_sheets.personality_active_tab == PERSONALITY_ACTIVE_TAB.PREFERENCES
            or view_sheets.personality_active_tab == PERSONALITY_ACTIVE_TAB.NEEDS)
    then
        local text = get_personality_text(view_sheets)
        if text then
            return unit, 'Personality', text
        end
        clear_output_file()
        qerror('No text found on the Personality subtab (Traits/Values/Preferences/Needs).')
    end

    if view_sheets.active_sub_tab == UNIT_SHEET_SUBTAB.SKILLS
        and view_sheets.unit_skill_active_tab == SKILL_ACTIVE_TAB.KNOWLEDGE
    then
        local text = get_skill_text(view_sheets)
        if text then
            return unit, 'Skill', text
        end
        clear_output_file()
        qerror('No text found on the Knowledge subtab.')
    end

    clear_output_file()
    qerror('Open Health, Personality, Skills, or an item window before running this script.')
end

local function get_item_flavor_text(view_sheets)
    local item = dfhack.gui.getSelectedItem(true)
    if not item then
        qerror('Select an item or open an item view sheet before running this script.')
    end

    local description = view_sheets.raw_description or ''
    if description == '' then
        qerror('No item description text found on the item view sheet.')
    end

    return item, 'Item', reformat(dfhack.df2utf(description))
end

local view_sheets = df.global.game.main_interface.view_sheets
if not view_sheets.open then
    clear_output_file()
    qerror('Open a unit or item view sheet before running this script.')
end

local screen = dfhack.gui.getDFViewscreen()
local is_unit_sheet = dfhack.gui.matchFocusString('dwarfmode/ViewSheets/UNIT', screen)
local is_item_sheet = dfhack.gui.matchFocusString('dwarfmode/ViewSheets/ITEM', screen)

local subject, flavor_type, text
if is_unit_sheet then
    subject, flavor_type, text = get_unit_flavor_text(view_sheets)
elseif is_item_sheet then
    subject, flavor_type, text = get_item_flavor_text(view_sheets)
else
    clear_output_file()
    qerror('Open a unit or item view sheet before running this script.')
end

local ok, err = pcall(dfhack.filesystem.mkdir_recursive, folder)
if not ok then
    qerror(('Failed to create folder "%s": %s'):format(folder, err))
end

local file, open_err = io.open(filepath, 'w')
if not file then
    qerror(('Failed to open file "%s" for writing: %s'):format(filepath, open_err))
end

file:write(text)
file:close()

local name
if is_unit_sheet then
    name = dfhack.df2console(dfhack.units.getReadableName(subject))
else
    name = dfhack.df2console(dfhack.items.getDescription(subject, 0, true))
end

print(('Wrote %s flavor text for %s to "%s".'):format(flavor_type, name, filepath))
