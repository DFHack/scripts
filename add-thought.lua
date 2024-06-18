-- Adds emotions to creatures.
--@ module = true

local script = require('gui.script')
local utils = require('utils')

function addEmotionToUnit(unit,thought,emotion,severity,strength,subthought)
    local personality = unit.status.current_soul.personality
    local emotions = personality.emotions
    if not tonumber(emotion) then
        emotion = df.emotion_type[emotion] --luacheck: retype
    end
    severity = tonumber(severity) or 0
    local properThought = tonumber(thought) or df.unit_thought_type[thought]
    local properSubthought = tonumber(subthought)
    if not properThought or not df.unit_thought_type[properThought] then
        for _,syn in ipairs(df.global.world.raws.syndromes.all) do
            if syn.syn_name == thought then
                properThought = df.unit_thought_type.Syndrome
                properSubthought = syn.id
                break
            end
        end
    end
    emotions:insert('#', {
      new=df.personality_moodst,
      type=emotion,
      strength=1,
      relative_strength=tonumber(strength),
      thought=properThought,
      subthought=properSubthought,
      severity=severity,
      year=df.global.cur_year,
      year_tick=df.global.cur_year_tick
    })
    local divider=df.emotion_type.attrs[emotion].divider
    if divider ~= 0 then
        personality.stress = personality.stress + math.ceil(severity/df.emotion_type.attrs[emotion].divider)
    end
end

local validArgs = utils.invert({
 'unit',
 'thought',
 'emotion',
 'severity',
 'strength',
 'subthought',
 'gui'
})

function tablify(iterableObject)
    local t = {}
    for k,v in ipairs(iterableObject) do
        t[k] = v~=nil and v or 'nil'
    end
    return t
end

if dfhack_flags.module then
  return
end

local args = utils.processArgs({...}, validArgs)

local unit = args.unit and df.unit.find(tonumber(args.unit)) or dfhack.gui.getSelectedUnit(true)
if not unit then qerror('A unit must be specified or selected.') end

if args.gui then
    script.start(function()
        local tok,thought = script.showListPrompt('emotions','Which thought?',COLOR_WHITE,tablify(df.unit_thought_type),10,true)
        if not tok then return end
        local eok,emotion = script.showListPrompt('emotions','Which emotion?',COLOR_WHITE,tablify(df.emotion_type),10,true)
        if not eok then return end
        local stok,strength = script.showInputPrompt('emotions','At what strength? 1 (Slight), 2 (Moderate), 5 (Strong), 10 (Intense).',COLOR_WHITE,'0')
        if not stok then return end
        addEmotionToUnit(unit,thought,emotion,0,strength,0)
    end)
else
    local thought = args.thought or df.unit_thought_type.NeedsUnfulfilled
    local emotion = args.emotion or -1
    local severity = args.severity or 0
    local subthought = args.subthought or 0
    local strength = args.strength or 0

    addEmotionToUnit(unit,thought,emotion,severity,strength,subthought)
end
