-- Turn any historical figure into a playable adventurer.
-- author: Atomic Chicken

--[====[

unretire-anyone
===============
This script allows the user to play as any living (or undead)
historical figure (except for deities) in adventure mode.

To use, simply enter "unretire-anyone" in the DFHack console
at the start of adventure mode character creation. You will be
presented with a searchable list from which you may choose
your desired historical figure.

This figure will be added to the 'Specific Person' list at the
bottom of the creature selection page. They can then be picked
for use as a player character, as if regaining control of a
retired adventurer.

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
      if (histFig.died_year == -1 or histFlags.ghost) and not histFlags.deity and not histFlags.force then
        local creature = df.creature_raw.find(histFig.race).caste[histFig.caste]
        local name = creature.caste_name[0]
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
  end
  dialogs.showListPrompt('unretire-anyone', "Select someone to add to the \"Specific Person\" list:", COLOR_WHITE, choices, function(id, choice)
    addNemesisToUnretireList(advSetUpScreen, choice.nemesis)
  end, nil, nil, true)
end

showNemesisPrompt(viewscreen)
