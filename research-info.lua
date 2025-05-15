local researchInfo = reqscript("internal/research-info/info")

local function sortResearchDataByPercAndPondered(data_list)
    table.sort(data_list, function(a, b)
        if tonumber(a.research_percentage) == tonumber(b.research_percentage) then
            return a.times_pondered > b.times_pondered
        end
        return tonumber(a.research_percentage) > tonumber(b.research_percentage)
    end)

    return data_list
end

local function printResearchData(data)
    if not data then
        print("No data to display.")
        return
    end

    if data.research_points == 0 and data.knowledge_goal == "" and data.times_pondered == 0 then
        return
    end

    print("==================")
    print("Dwarf: " .. data.name)
    print("\tKnowledge Goal Category: " .. data.knowledge_goal_category)
    print("\tKnowledge Goal: " .. data.knowledge_goal)
    print("\tResearch Points: " .. data.research_points .. "/100000")
    print("\tResearch Percentage: " .. data.research_percentage .. "%")
    print("\tTimes Pondered: " .. data.times_pondered)

    if #data.research_topics > 0 then
        print("Knowledge:")
        for _, topic in ipairs(data.research_topics) do
            print("\t" .. topic.name .. ": " .. topic.info)
        end
    end
end

--
local unit  = dfhack.units.getCitizens()
local selected_unit = dfhack.gui.getSelectedUnit()

if unit then
    local research_data_list = {}
    for i, unit in pairs(dfhack.units.getCitizens()) do
        
        if selected_unit and selected_unit.id ~= unit.id then
            goto continue
        end

        local historical_figure = researchInfo.getHistoricalFigure(unit.id)
        if historical_figure then
            local research_data, error_msg = researchInfo.getResearchData(historical_figure)
            if research_data then
                for _, data in ipairs(research_data) do
                    table.insert(research_data_list, data)
                end
            end
        end
    ::continue::
    end

    research_data_list = sortResearchDataByPercAndPondered(research_data_list)

    for _, data in ipairs(research_data_list) do
        printResearchData(data)
    end
end