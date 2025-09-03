-- Spectate-Overlay module for research-info
--@ module = true

local researchInfo = reqscript("internal/research-info/info")

local function formatKnowledgeString(str)
    if not str or type(str) ~= "string" or str == "" then
        return str or ""
    end

    local parts = {}
    for part in str:gmatch("[^_]+") do
        -- do capitalize the first letter
        local formatted = part:sub(1,1):upper() .. part:sub(2):lower()
        table.insert(parts, formatted)
    end

    return table.concat(parts, " ")
end

function GetUnitResearchInfo(unit_id)
    local info = ''
    historical_figure = df.historical_figure.find(unit_id)
    historical_figure = researchInfo.getHistoricalFigure(unit_id)
    local knowledge = researchInfo.getHistoricKnowledge(historical_figure)
    local data = {
        knowledge_goal_category = researchInfo.getKnowledgeGoalCategoryInfo(knowledge.knowledge_goal_category),
        knowledge_goal = formatKnowledgeString(researchInfo.getGoalInfo(knowledge.knowledge_goal, knowledge.knowledge_goal_category)),
        research_points = knowledge.research_points, --TOTAL: 100'000
        research_percentage = string.format("%.2f", (knowledge.research_points / 100000) * 100),
        times_pondered = knowledge.times_pondered
    }

    if((data.knowledge_goal ~= 'nil') and ((data.times_pondered > 0) or (knowledge.research_points > 0))) then
        info = data.knowledge_goal..string.format(' %s%%', data.research_percentage)..string.format(' [%d] ', data.times_pondered)
    end

    return info
end

function GetUnitKnowledge(unit_id)
    return researchInfo.getUnitKnowledge(unit_id)
end
