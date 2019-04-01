-- print sum of all needs
--[====[

allneeds
========
Show which needs are high for all dwarfs.
Weight and Focus are divided by the number of dwarves that have that need.

]====]
local ENUM = {}

ENUM[0]  = "Socialize"
ENUM[1]  = "DrinkAlcohol"
ENUM[2]  = "PrayOrMedidate"
ENUM[3]  = "StayOccupied"
ENUM[4]  = "BeCreative"
ENUM[5]  = "Excitement"
ENUM[6]  = "LearnSomething"
ENUM[7]  = "BeWithFamily"
ENUM[8]  = "BeWithFriends"
ENUM[9]  = "HearEloquence"
ENUM[10] = "UpholdTradition"
ENUM[11] = "SelfExamination"
ENUM[12] = "MakeMerry"
ENUM[13] = "CraftObject"
ENUM[14] = "MartialTraining"
ENUM[15] = "PracticeSkill"
ENUM[16] = "TakeItEasy"
ENUM[17] = "MakeRomance"
ENUM[18] = "SeeAnimal"
ENUM[19] = "SeeGreatBeast"
ENUM[20] = "AcquireObject"
ENUM[21] = "EatGoodMeal"
ENUM[22] = "Fight"
ENUM[23] = "CauseTrouble"
ENUM[24] = "Argue"
ENUM[25] = "BeExtravagant"
ENUM[26] = "Wander"
ENUM[27] = "HelpSomebody"
ENUM[28] = "ThinkAbstractly"
ENUM[29] = "AdmireArt"


local need = {}
local n = 0
for _, unit in ipairs(df.global.world.units.all) do
    if not unit then
      qerror('Unit not real.')
    end
    -- Select valid dwarf
    if unit.status.current_soul and unit.race == 572 then
        n = n+1
        local mind = unit.status.current_soul.personality.needs
        -- sum need_level and focus_level for each need
        for k,v in pairs(mind) do
            if need[v.id] == nil then
                need[v.id] = {0, 0, 0}
            end
            need[v.id] = {need[v.id][1] + v.need_level, need[v.id][2] + v.focus_level, need[v.id][3] + 1}
        end
    end
end

-- for sorting output
function compare(a,b)
    return a[1]*a[2] > b[1]*b[2]
end

sorted = {}
i = 1
for k,v in pairs(need) do
    sorted[i] = {v[1], v[2], v[3], ENUM[k]}
    i = i + 1
end
table.sort(sorted, compare)

-- Print sorted output
print(string.format("%20s %8s %8s %9s", "Need", "Weight", "Focus", "# Dwarves"))
for k,v in ipairs(sorted) do
    print(string.format("%20s %8.1f %8.1f %9d",  v[3], v[1]/v[3], v[2]/v[3], v[3]))
end
