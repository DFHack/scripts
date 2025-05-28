--@ module = true

local json = require 'json'

local JOURNAL_WELCOME_COPY =  [=[
Welcome to gui/journal, your planning scroll for the world of Dwarf Fortress!

Here, you can outline your fortress ideas, compare embark sites, or record thoughts before founding your settlement.
The text you write here is saved together with your world - even if you cancel the embark.

For guidance on navigation and hotkeys, tap the ? button in the upper right corner.
Strike the earth!
]=]

local TOC_WELCOME_COPY =  [=[
Start a line with # symbols and a space to create a header. For example:

# My section heading

or

## My section subheading

Those headers will appear here, and you can click on them to jump to them in the text.]=]

worldmap_config = worldmap_config or json.open('dfhack-config/journal-context.json')

WorldmapJournalContext = defclass(WorldmapJournalContext)
WorldmapJournalContext.ATTRS{
  save_prefix='',
  world_id=DEFAULT_NIL
}

function get_worldmap_context_key(prefix, world_id)
    return prefix .. 'world:' .. world_id
end

function WorldmapJournalContext:save_content(text, cursor)
  if dfhack.isWorldLoaded() then
    local key = get_worldmap_context_key(self.save_prefix, self.world_id)
    worldmap_config.data[key] = {text={text}, cursor={cursor}}
    worldmap_config:write()
  end
end

function WorldmapJournalContext:load_content()
  if dfhack.isWorldLoaded() then
    local key = get_worldmap_context_key(self.save_prefix, self.world_id)
    local worldmap_data = copyall(worldmap_config.data[key] or {})

    if not worldmap_data.text or #worldmap_data.text[1] == 0 then
        worldmap_data.text={''}
        worldmap_data.show_tutorial = true
    end
    worldmap_data.cursor = worldmap_data.cursor or {#worldmap_data.text[1] + 1}
    return worldmap_data
  end
end

function WorldmapJournalContext:delete_content()
  if dfhack.isWorldLoaded() then
    local key = get_worldmap_context_key(self.save_prefix, self.world_id)
    worldmap_config.data[key] = nil
    worldmap_config:write()
  end
end

function WorldmapJournalContext:welcomeCopy()
  return JOURNAL_WELCOME_COPY
end

function WorldmapJournalContext:tocWelcomeCopy()
  return TOC_WELCOME_COPY
end
