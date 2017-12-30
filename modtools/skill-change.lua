-- Sets or modifies a skill of a unit
--author expwnent
--based on skillChange.lua by Putnam
--TODO: skill rust?
local help = [====[

modtools/skill-change
=====================
Sets or modifies a skill of a unit.  Args:

:-skill skillName:  set the skill that we're talking about
:-mode (add/set):   are we adding experience/levels or setting them?
:-granularity (experience/level):
                    direct experience, or experience levels?
:-unit id:          id of the target unit
:-value amount:     how much to set/add
:-loud:             if present, prints changes to console
]====]
local utils = require 'utils'

validArgs = validArgs or utils.invert({
    'help',
    'skill',
    'mode',
    'value',
    'granularity',
    'unit',
    'loud',
})

mode = mode or utils.invert({
    'add',
    'set',
})

granularity = granularity or utils.invert({
    'experience',
    'level',
})

local args = utils.processArgs({...}, validArgs)

if args.help then
    print(help)
    return
end

if not args.unit or not tonumber(args.unit) or not df.unit.find(tonumber(args.unit)) then
    error 'Invalid unit.'
end
args.unit = df.unit.find(tonumber(args.unit))

args.skill = df.job_skill[args.skill]
args.mode = mode[args.mode or 'set']
args.granularity = granularity[args.granularity or 'level']
args.value = tonumber(args.value)

if not args.skill then
    error('invalid skill')
end
if not args.value then
    error('invalid value')
end

local skill
for _,skill_c in ipairs(args.unit.status.current_soul.skills) do
    if skill_c.id == args.skill then
        skill = skill_c
    end
end

if not skill then
    skill = df.unit_skill:new()
    skill.id = args.skill
    utils.insert_sorted(args.unit.status.current_soul.skills,skill,'id')
end

if args.loud then
    print('old: ' .. skill.rating .. ': ' .. skill.experience)
end

if args.granularity == granularity.experience then
    if args.mode == mode.set then
        skill.experience = args.value
    elseif args.mode == mode.add then
    -- Changing of skill levels when experience increases/decreases hacked in by Atkana
    -- https://github.com/DFHack/scripts/pull/27
        local function nextCost(rating)
            if rating == 0 then
                return 1
            else
                return (400 + (100 * rating))
            end
        end
        local newExp = skill.experience + args.value
        if (newExp < 0) or (newExp > nextCost(skill.rating+1)) then
            if newExp > 0 then --positive
                repeat
                    newExp = newExp - nextCost(skill.rating+1)
                    skill.rating = skill.rating + 1
                until newExp < nextCost(skill.rating)
            else -- negative
                repeat
                    newExp = newExp + nextCost(skill.rating)
                    skill.rating = math.max(skill.rating - 1, 0)
                until (newExp >= 0) or skill.rating == 0
                -- hack because I can't maths. Will only happen if loop stopped because skill was 0
                if newExp < 0 then newExp = 0 end
            end
        end
        -- Update exp
        skill.experience = newExp
    else
        error 'bad mode'
    end
elseif args.granularity == granularity.level then
    if args.mode == mode.set then
        skill.rating = args.value
    elseif args.mode == mode.add then
        skill.rating = args.value + skill.rating
    else
        error 'bad mode'
    end
else
    error 'bad granularity'
end

if args.loud then
    print('new: ' .. skill.rating .. ': ' .. skill.experience)
end
