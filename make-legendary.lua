-- Make a skill or skills of a unit Legendary +5

local utils = require('utils')

function getName(unit)
    return dfhack.df2console(dfhack.TranslateName(dfhack.units.getVisibleName(unit)))
end

function legendize(unit, skill_idx)
    utils.insert_or_update(unit.status.current_soul.skills,
        {new=true, id=skill_idx, rating=df.skill_rating.Legendary5},
        'id')
end

function make_legendary(skillname)
    local unit = dfhack.gui.getSelectedUnit()
    if not unit then
        return
    end

    local skillnum = df.job_skill[skillname]
    if not skillnum then
        qerror('The skill name provided is not in the list')
    end

    local skillnamenoun = df.job_skill.attrs[skillnum].caption_noun
    if not skillnamenoun then
        qerror('skill name noun not found')
    end

    legendize(unit, skillnum)
    print(getName(unit) .. ' is now a legendary ' .. skillnamenoun)
end

function PrintSkillList()
    for i, name in ipairs(df.job_skill) do
        local attr = df.job_skill.attrs[i]
        if attr.caption then
            print(('%s (%s), Type: %s'):format(
                name, attr.caption, df.job_skill_class[attr.type]))
        end
    end
    print()
    print('Provide the UPPER_CASE argument, for example: ENGRAVE_STONE rather than Engraving.')
end

function BreathOfArmok()
    local unit = dfhack.gui.getSelectedUnit()
    if not unit then
        return
    end
    for i in ipairs(df.job_skill) do
        legendize(unit, i)
    end
    print('The breath of Armok has engulfed ' .. getName(unit))
end

function LegendaryByClass(skilltype)
    local unit = dfhack.gui.getSelectedUnit()
    if not unit then
        return
    end
    for i in ipairs(df.job_skill) do
        local attr = df.job_skill.attrs[i]
        if skilltype == df.job_skill_class[attr.type] then
            print(('%s skill %s is now legendary for %s'):format(
                skilltype, attr.caption, getName(unit)))
            legendize(unit, i)
        end
    end
end

function PrintSkillClassList()
    print('Skill class names:')
    for _, name in ipairs(df.job_skill_class) do
        print('  ' .. name)
    end
    print()
    print('Provide one of these arguments, and all skills of that type will be made Legendary')
    print('For example: Medical will make all medical skills legendary')
end

--main script operation starts here
----
local opt = ...

if not opt then
    print(dfhack.script_help())
    return
end

if opt == 'list' then
    PrintSkillList()
    return
elseif opt == 'classes' then
    PrintSkillClassList()
    return
elseif opt == 'all' then
    BreathOfArmok()
    return
elseif df.job_skill_class[opt] then
    LegendaryByClass(opt)
    return
else
    make_legendary(opt)
end
