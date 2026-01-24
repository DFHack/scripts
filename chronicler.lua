-- The Chronicler: DFHack Narrator Data Exporter
-- Comprehensive fortress state extraction for AI narration
--@ module = true

local json = require('json')
local repeatUtil = require('repeat-util')
local utils = require('utils')

-- Configuration
local DEFAULT_INTERVAL = 5 -- minutes
local SCRIPT_NAME = 'chronicler'

-- State to track what has already been exported
local last_exported_report_id = -1

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

local function get_skill_rating_name(rating)
    local names = {
        [0] = "Dabbling", [1] = "Novice", [2] = "Adequate", [3] = "Competent",
        [4] = "Skilled", [5] = "Proficient", [6] = "Talented", [7] = "Adept",
        [8] = "Expert", [9] = "Professional", [10] = "Accomplished",
        [11] = "Great", [12] = "Master", [13] = "High Master", [14] = "Grand Master"
    }
    return names[rating] or "Legendary"
end

local function get_sex_string(sex)
    if sex == 0 then return "female"
    elseif sex == 1 then return "male"
    else return "unknown"
    end
end

--------------------------------------------------------------------------------
-- Data Extraction Functions
--------------------------------------------------------------------------------

local function getRecentReports()
    local reports = {}
    local world_reports = df.global.world.status.reports
    
    local start_idx = 0
    if last_exported_report_id ~= -1 then
        for i = #world_reports - 1, 0, -1 do
            if world_reports[i].id == last_exported_report_id then
                start_idx = i + 1
                break
            end
        end
    else
        start_idx = math.max(0, #world_reports - 50)
    end

    for i = start_idx, #world_reports - 1 do
        local r = world_reports[i]
        table.insert(reports, {
            id = r.id,
            text = r.text,
            type = r.flags.announcement and "announcement" or "report",
            year = r.year,
            time = r.time,
        })
        last_exported_report_id = r.id
    end
    
    return reports
end

local function extractSkills(unit)
    local skills = {}
    local soul = unit.status.current_soul
    if not soul then return skills end
    
    for _, skill in ipairs(soul.skills) do
        if skill.rating > 0 then
            table.insert(skills, {
                name = df.job_skill[skill.id],
                rating = skill.rating,
                rating_name = get_skill_rating_name(skill.rating),
                experience = skill.experience,
            })
        end
    end
    return skills
end

local function extractPersonalityTraits(unit)
    local traits = {}
    local soul = unit.status.current_soul
    if not soul or not soul.personality then return traits end
    
    -- Personality facets (50 different traits like LOVE_PROPENSITY, BRAVERY, etc.)
    for trait_name, trait_value in pairs(soul.personality.traits) do
        -- Only include notable traits (very high or very low)
        if trait_value >= 75 or trait_value <= 25 then
            traits[trait_name] = trait_value
        end
    end
    return traits
end

local function extractNeeds(unit)
    local needs = {}
    local soul = unit.status.current_soul
    if not soul or not soul.personality or not soul.personality.needs then return needs end
    
    for _, need in ipairs(soul.personality.needs) do
        table.insert(needs, {
            type = df.need_type[need.id] or "UNKNOWN",
            focus_level = need.focus_level,
            need_level = need.need_level,
        })
    end
    return needs
end

local function extractDescription(unit)
    -- Get race/caste description (e.g., "Dwarves are legendary miners...")
    local caste = dfhack.units.getCasteRaw(unit)
    if caste and caste.description and #caste.description > 0 then
        return caste.description
    end
    return nil
end

local function extractEmotions(unit)
    local emotions = {}
    local soul = unit.status.current_soul
    if not soul or not soul.personality or not soul.personality.emotions then return emotions end
    
    -- Get unique thoughts from emotions (last 10, deduplicated by thought type)
    local seen_thoughts = {}
    local count = #soul.personality.emotions
    local start_idx = math.max(0, count - 10)
    
    for i = count - 1, start_idx, -1 do
        local e = soul.personality.emotions[i]
        local thought_key = tostring(e.thought)
        
        -- Deduplicate by thought type, keep most severe
        if not seen_thoughts[thought_key] or e.severity > seen_thoughts[thought_key].severity then
            seen_thoughts[thought_key] = {
                emotion = df.emotion_type[e.type] or "UNKNOWN",
                thought = df.unit_thought_type[e.thought] or "UNKNOWN",
                severity = e.severity,
                year = e.year,
                strength = e.strength,
            }
        end
    end
    
    -- Convert to list
    for _, v in pairs(seen_thoughts) do
        table.insert(emotions, v)
    end
    return emotions
end

local function extractRelationships(unit)
    local relationships = {}
    if unit.hist_figure_id == -1 then return relationships end
    
    local hf = df.historical_figure.find(unit.hist_figure_id)
    if not hf or not hf.histfig_links then return relationships end
    
    for _, link in ipairs(hf.histfig_links) do
        local link_type = df.histfig_hf_link_type[link:getType()] or "UNKNOWN"
        local target_hf = df.historical_figure.find(link.target_hf)
        local target_name = target_hf and dfhack.translation.translateName(target_hf.name, true) or "Unknown"
        
        -- Only include family/spouse links for storytelling
        if link_type:find("SPOUSE") or link_type:find("CHILD") or link_type:find("PARENT") or link_type:find("SIBLING") then
            table.insert(relationships, {
                type = link_type,
                target_name = target_name,
                target_hf_id = link.target_hf,
            })
        end
    end
    return relationships
end

local function extractWounds(unit)
    local wounds = {}
    if not unit.body or not unit.body.wounds then return wounds end
    
    for _, wound in ipairs(unit.body.wounds) do
        local parts = {}
        for _, part_idx in ipairs(wound.parts) do
            local body_part = unit.body.body_plan.body_parts[part_idx]
            if body_part then
                table.insert(parts, body_part.name_singular[0].value)
            end
        end
        if #parts > 0 then
            table.insert(wounds, {
                parts = parts,
                flags = wound.flags.whole, -- bleeding, infection, etc.
            })
        end
    end
    return wounds
end

local function getCitizenData()
    local citizens = {}
    for _, unit in ipairs(dfhack.units.getCitizens(true)) do
        local soul = unit.status.current_soul
        local race_raw = df.creature_raw.find(unit.race)
        
        local citizen = {
            -- Basic info
            name = dfhack.units.getReadableName(unit),
            id = unit.id,
            hf_id = unit.hist_figure_id,
            age = df.global.cur_year - unit.birth_year,
            sex = get_sex_string(unit.sex),
            race = race_raw and race_raw.creature_id or "UNKNOWN",
            race_name = race_raw and race_raw.name[0] or "creature",
            profession = dfhack.units.getProfessionName(unit),
            description = extractDescription(unit),
            
            -- Mental state
            stress = soul and soul.personality.stress or 0,
            mood = unit.counters.soldier_mood,
            
            -- Status flags
            is_alive = dfhack.units.isAlive(unit),
            is_sane = dfhack.units.isSane(unit),
            
            -- Deep personality data
            skills = extractSkills(unit),
            traits = extractPersonalityTraits(unit),
            needs = extractNeeds(unit),
            emotions = extractEmotions(unit),
            relationships = extractRelationships(unit),
            wounds = extractWounds(unit),
        }
        
        table.insert(citizens, citizen)
    end
    return citizens
end

local function exportFortressState()
    if not dfhack.isWorldLoaded() or not dfhack.isMapLoaded() then
        return
    end

    local save_path = dfhack.getSavePath()
    if not save_path then return end
    
    local chronicler_dir = save_path .. '/chronicler'
    if not dfhack.filesystem.exists(chronicler_dir) then
        dfhack.filesystem.mkdir(chronicler_dir)
    end

    local state = {
        meta = {
            frame_counter = df.global.world.frame_counter,
            year = df.global.cur_year,
            year_tick = df.global.cur_year_tick,
            fortress_name = dfhack.df2console(dfhack.translation.translateName(
                df.global.world.world_data.fortress_entity.name)),
            export_time = os.date('%Y-%m-%dT%H:%M:%S'),
            citizen_count = #dfhack.units.getCitizens(),
        },
        reports = getRecentReports(),
        citizens = getCitizenData()
    }

    local output_file = chronicler_dir .. '/fortress_state.json'
    local f = io.open(output_file, 'w')
    if f then
        f:write(json.encode(state))
        f:close()
    else
        dfhack.printerr("Chronicler: Failed to write to " .. output_file)
    end
end

--------------------------------------------------------------------------------
-- CLI Interface
--------------------------------------------------------------------------------

local function print_status()
    if repeatUtil.isScheduled(SCRIPT_NAME) then
        dfhack.println("Chronicler is active.")
    else
        dfhack.println("Chronicler is inactive.")
    end
end

function main(...)
    local args = {...}
    if args[1] == 'start' or args[1] == 'enable' then
        local interval = tonumber(args[2]) or DEFAULT_INTERVAL
        repeatUtil.scheduleEvery(SCRIPT_NAME, interval, 'min', exportFortressState)
        dfhack.println("Chronicler started. Exporting every " .. interval .. " minutes.")
        exportFortressState()
    elseif args[1] == 'stop' or args[1] == 'disable' then
        repeatUtil.cancel(SCRIPT_NAME)
        dfhack.println("Chronicler stopped.")
    elseif args[1] == 'now' then
        exportFortressState()
        dfhack.println("Chronicler: Manual export triggered.")
    else
        print_status()
        dfhack.println("Usage:")
        dfhack.println("  chronicler start [interval_mins] - Start the narrator loop (default 5)")
        dfhack.println("  chronicler stop                  - Stop the narrator loop")
        dfhack.println("  chronicler now                   - Trigger a manual export")
    end
end

if not dfhack_flags.module then
    main(...)
end
