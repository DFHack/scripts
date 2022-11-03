-- Function:     Turn any historical figure into a playable adventurer. Even dead ones.
-- Author:       Dikbutdagrate
-- Credit:       This is almost 1-for-1 Atomic Chicken's unretire-anyone script, only now it lets you revive dead npcs. 
-- More Credit:  "devel/kill-hf.lua", which was converted into a script for resurrecting an off-site histfig.

--[====[
dikbutdagrate/unretire-literally-anyone
===============

Useage:
Litrally the same as unretire-anyone, except now you can choose dead npcs using the adv-unretire startup gui.

Note about dead characters: 
When unretiring a dead npc or adventurer, you will likely be greeted by immidiate death due to not having a body. This is normal. 
Run the resurrect-adv command in the console window after the immidiate death spawn, and your character should have a body again.

]====]

local dialogs = require 'gui.dialogs'

local viewscreen = dfhack.gui.getCurViewscreen()
if viewscreen._type ~= df.viewscreen_setupadventurest then
  qerror("This script can only be used during adventure mode setup!")
end

--luacheck: in=df.viewscreen_setupadventurest,df.nemesis_record
function addNemesisToUnretireList(advSetUpScreen, nemesis)
  local unretireOption = false
  for i = #advSetUpScreen.race_ids-1, 0, -1 do
    if advSetUpScreen.race_ids[i] == -2 then -- this is the "Specific Person" option on the menu
      unretireOption = true
      break
    end
  end

  if not unretireOption then
    advSetUpScreen.race_ids:insert('#', -2)
  end

  nemesis.flags.ADVENTURER = true
  advSetUpScreen.nemesis_ids:insert('#', nemesis.id)
end

--luacheck: in=table
function showNemesisPrompt(advSetUpScreen)
  local choices = {}
  for _,nemesis in ipairs(df.global.world.nemesis.all) do
    if nemesis.figure and not nemesis.flags.ADVENTURER then -- these are already available for unretiring
      local histFig = nemesis.figure
      local histFlags = histFig.flags

      local creature = df.creature_raw.find(histFig.race).caste[histFig.caste]
      local name = creature.caste_name[0]
        -- Beginning of revive function
        if histFig.died_year >= -1 then
            histFig.old_year = df.global.cur_year
            histFig.old_seconds = df.global.cur_year_tick + 1
            histFig.died_year = -1
            histFig.died_seconds = -1
        end
        if histFig.info and histFig.info.curse then
          local curse = histFig.info.curse
          if curse.name ~= '' then
            name = name .. ' ' .. curse.name
          end
          if curse.undead_name ~= '' then
            name = curse.undead_name .. " - reanimated " .. name
          end
        end
        if histFlags.ghost then
          name = name .. " ghost"
        end
        local sym = df.pronoun_type.attrs[creature.sex].symbol
        if sym then
          name = name .. ' (' .. sym .. ')'
        end
        if histFig.name.has_name then
          name = dfhack.TranslateName(histFig.name) .. " - (" .. dfhack.TranslateName(histFig.name, true).. ") - " .. name
        end
        table.insert(choices, {text = name, nemesis = nemesis, search_key = name:lower()})
      end
  end
  dialogs.showListPrompt('unretire-anyone', "Select someone to add to the \"Specific Person\" list:", COLOR_WHITE, choices, function(id, choice)
    addNemesisToUnretireList(advSetUpScreen, choice.nemesis)
  end, nil, nil, true)
end

showNemesisPrompt(viewscreen)
