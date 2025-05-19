--@ module = true

local widgets = require 'gui.widgets'
local utils = require 'utils'
local DummyJournalContext = reqscript('internal/journal/contexts/dummy').DummyJournalContext
local FortressJournalContext = reqscript('internal/journal/contexts/fortress').FortressJournalContext
local WorldmapJournalContext = reqscript('internal/journal/contexts/worldmap').WorldmapJournalContext
local AdventurerJournalContext = reqscript('internal/journal/contexts/adventure').AdventurerJournalContext

JOURNAL_CONTEXT_MODE = {
  FORTRESS='fortress',
  ADVENTURE='adventure',
  WORLDMAP='worldmap',
  LEGENDS='legends',
  DUMMY='dummy'
}

function detect_journal_context_mode()
  if not dfhack.isMapLoaded() and dfhack.world.isFortressMode() then
    return JOURNAL_CONTEXT_MODE.WORLDMAP
  elseif dfhack.isMapLoaded() and dfhack.world.isFortressMode() then
    return JOURNAL_CONTEXT_MODE.FORTRESS
  elseif dfhack.isMapLoaded() and dfhack.world.isAdventureMode() then
    return JOURNAL_CONTEXT_MODE.ADVENTURE
  elseif dfhack.world.isLegends() then
    return JOURNAL_CONTEXT_MODE.LEGENDS
  else
    return nil
  end
end

function journal_context_factory(journal_context_mode, save_prefix)
  local world_id =  df.global.world.cur_savegame.world_header.id1
  local worldmap_journal_context = WorldmapJournalContext{save_prefix=save_prefix, world_id=world_id}

  if journal_context_mode == JOURNAL_CONTEXT_MODE.FORTRESS then
    return FortressJournalContext{
      save_prefix=save_prefix,
      worldmap_journal_context=worldmap_journal_context
    }
  elseif journal_context_mode == JOURNAL_CONTEXT_MODE.ADVENTURE then
    local interactions = df.global.adventure.interactions
    if #interactions.party_core_members == 0 or interactions.party_core_members[0] == nil then
      qerror('Can not identify party core member')
    end

    local adventurer_id = interactions.party_core_members[0]

    return AdventurerJournalContext{
      save_prefix=save_prefix,
      adventurer_id=adventurer_id,
      worldmap_journal_context=worldmap_journal_context
    }
  elseif journal_context_mode == JOURNAL_CONTEXT_MODE.WORLDMAP then
    return worldmap_journal_context
  elseif journal_context_mode == JOURNAL_CONTEXT_MODE.LEGENDS then
    return worldmap_journal_context
  elseif journal_context_mode == JOURNAL_CONTEXT_MODE.DUMMY then
    return DummyJournalContext{}
  else
    qerror('unsupported game mode')
  end
end
