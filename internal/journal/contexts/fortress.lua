--@ module = true

local JOURNAL_WELCOME_COPY =  [=[
Welcome to gui/journal, the chronicler's tool for Dwarf Fortress!

Here, you can carve out notes, sketch your grand designs, or record the history of your fortress.
The text you write here is saved together with your fort.

For guidance on navigation and hotkeys, tap the ? button in the upper right corner.
Happy digging!
]=]

local TOC_WELCOME_COPY =  [=[
Start a line with # symbols and a space to create a header. For example:

# My section heading

or

## My section subheading

Those headers will appear here, and you can click on them to jump to them in the text.]=]


FortressJournalContext = defclass(FortressJournalContext)
FortressJournalContext.ATTRS{
  save_prefix=''
}

function get_fort_context_key(prefix)
    return prefix .. 'journal'
end

function FortressJournalContext:save_content(text, cursor)
  if dfhack.isWorldLoaded() then
    dfhack.persistent.saveSiteData(
        get_fort_context_key(self.save_prefix),
        {text={text}, cursor={cursor}}
    )
  end
end

function FortressJournalContext:load_content()
  if dfhack.isWorldLoaded() then
    local site_data = dfhack.persistent.getSiteData(
        get_fort_context_key(self.save_prefix)
    ) or {}

    if not site_data.text then
        site_data.text={''}
        site_data.show_tutorial = true
    end
    site_data.cursor = site_data.cursor or {#site_data.text[1] + 1}
    return site_data
  end
end

function FortressJournalContext:delete_content()
  if dfhack.isWorldLoaded() then
    dfhack.persistent.deleteSiteData(
        get_fort_context_key(self.save_prefix)
    )
  end
end

function FortressJournalContext:welcomeCopy()
  return JOURNAL_WELCOME_COPY
end

function FortressJournalContext:tocWelcomeCopy()
  return TOC_WELCOME_COPY
end
