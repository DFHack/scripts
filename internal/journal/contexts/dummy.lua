--@ module = true

-- Dummy Context, no storage --

DummyJournalContext = defclass(DummyJournalContext)

function DummyJournalContext:save_content(text, cursor)
end

function DummyJournalContext:load_content()
  return {text={''}, cursor={1}, show_tutorial=true}
end

function DummyJournalContext:delete_content()
end

function DummyJournalContext:welcomeCopy()
  return ''
end

function DummyJournalContext:tocWelcomeCopy()
  return ''
end
