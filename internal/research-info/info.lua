-- Main module for research-info
--@ module = true

---@param unit_id df.unit.id
function getHistoricalFigure(unit_id)
    for _, historical_figure in ipairs(df.global.world.history.figures) do
        if historical_figure.unit_id == unit_id then
            return historical_figure
        end
    end
    print("No historical figure found for unit ID: " .. unit_id)
    return nil
end

function getKnowledgeGoalCategoryInfo(category_id)
    -- alt: df.scholar_knowledgest
    local topic_categories = {
        [-1] = "None",  -- None
        [0] = "Philosophy",  -- PHILOSOPHY_FLAG
        [1] = "Philosophy Adv",  -- PHILOSOPHY_FLAG2
        [2] = "Mathematics",  -- MATHEMATICS_FLAG
        [3] = "Mathematics Adv",  -- MATHEMATICS_FLAG2
        [4] = "History",  -- HISTORY_FLAG
        [5] = "Astronomy",  -- ASTRONOMY_FLAG
        [6] = "Naturalist",  -- NATURALIST_FLAG
        [7] = "Chemistry",  -- CHEMISTRY_FLAG
        [8] = "Geography",  -- GEOGRAPHY_FLAG
        [9] = "Medicine 1",  -- MEDICINE_FLAG
        [10] = "Medicine 2",  -- MEDICINE_FLAG2
        [11] = "Medicine 3",  -- MEDICINE_FLAG3
        [12] = "Engineering",  -- ENGINEERING_FLAG
        [13] = "Engineering Adv"  -- ENGINEERING_FLAG2
    }
    return topic_categories[category_id] or string.format("Unknown Category: %s", category_id)
end

function getGoalInfo(goal, category)
    local goal_info = ''
    if not goal then
        return goal_info
    end

    for i = 0, 31 do
        if goal[i] then
            local global_flag_index = category * 32 + i -- wizards move
            goal_info = string.format("%s", df.dfhack_knowledge_scholar_flag[global_flag_index]) or string.format("Unknown Flag: %s", i)
        end
    end
    return goal_info
end

local function getTopicInfo(topic)
    if not topic then
        return "No topic information available."
    end

    local topic_info = ""

    for key, value in pairs(topic) do
        if type(value) == "boolean" and value then
            -- show learned topics
            topic_info = topic_info .. string.format("\n\t\t%s", key)
        end
    end

    if topic_info == "" then
        return "No learned topics."
    end

    return topic_info
end

---@param historical_figure df.historical_figure
function getHistoricKnowledge(historical_figure)
    if not historical_figure then
        print("Historical figure not found.")
        return nil, "Historical figure not found."
    end

    local known_info = historical_figure.info.known_info

    if not known_info then
        return nil, "No known_info found."
    end

    local knowledge = known_info.knowledge

    if not knowledge then
        return nil, "No knowledge found."
    end

    return knowledge
end

---@param unit_id df.unit.id
function getUnitKnowledge(unit_id)
    return getHistoricKnowledge(getHistoricalFigure(unit_id))
end

---@param historical_figure df.historical_figure
function getResearchData(historical_figure)
    local knowledge = getHistoricKnowledge(historical_figure)
    local data = {
        name = dfhack.translation.translateName(historical_figure.name),
        knowledge_goal_category = getKnowledgeGoalCategoryInfo(knowledge.knowledge_goal_category),
        knowledge_goal = getGoalInfo(knowledge.knowledge_goal, knowledge.knowledge_goal_category),
        research_points = knowledge.research_points,
        research_percentage = string.format("%.2f", (knowledge.research_points / 100000) * 100),
        times_pondered = knowledge.times_pondered,
        research_topics = {}
    }

    for i, topic in pairs(knowledge) do
        if type(topic) == "userdata" and i ~= "knowledge_goal" then
            local topic_info = getTopicInfo(topic)
            if topic_info ~= "\tNo topic information available." and topic_info ~= "No learned topics." then
                table.insert(data.research_topics, {name = i, info = topic_info})
            end
        end
    end

    return {data}
end
