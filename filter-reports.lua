-- filters reports out from announcelist screen (``a``).

local HELP = [====[

filter-reports
==============
filters reports out from announcelist screen (``a``). Doesn't prevent them from
entering gamelog.txt.

Example usage: in your announcements.txt, find following lines::

  [REGULAR_CONVERSATION:A_D]
  [CONFLICT_CONVERSATION:A_D:UCR_A]

and add ``D_D``, like this::

  [REGULAR_CONVERSATION:A_D:D_D]
  [CONFLICT_CONVERSATION:A_D:UCR_A:D_D]

Restart the game.

Now there are conversations in the reports, which is a bit too much. Luckily,
this script deals with exact that problem::

    filter-reports REGULAR_CONVERSATION CONFLICT_CONVERSATION

And finally you would need another tool to do something about all the stuff
that's in the gamelog now. Like Soundsense or Announcement Window.
]====]

local utils = require 'utils'
local eventful=require 'plugins.eventful'

if not (...) then
    print(HELP)
    return
elseif (...)=='disable' or (...)=='stop' then
    eventful.onReport.filter_reports = nil
    dfhack.onStateChange.filter_reports_clean_announcelist = nil
    return
end

local logprefix=dfhack.current_script_name()..':'
local function log(...)
    -- uncomment for debugging
    --print(logprefix, ...)
end

local suppressing = utils.invert{...}
-- make it behave like df.announcement_type does
for k in pairs(suppressing) do
    suppressing[k]=df.announcement_type[k]
    suppressing[suppressing[k]]=k
    print('suppressing ' .. k)
end

-- TODO: decide to do something about `continuation` (and do it) or not.
-- df.report.T_flags:
    -- 0 = continuation
    -- 1 = unconscious
    -- 2 = announcement

eventful.onReport.filter_reports = function(id)
    -- TODO: is this check necessary? devel/annc-monitor does it.
    if not dfhack.isWorldLoaded() then return end

    local report=df.report.find(id)
    log(id, df.announcement_type[report.type], report.text)

    if not suppressing[report.type] then return end

    local vec = df.report.get_vector()
    -- TODO: loop because I don't know if current id will
    -- always be the last one.
    for i = #vec-1,0,-1 do
        if vec[i].id == id then
            -- TODO: do we need to set `world.status.display_timer = 0` here?
            vec:erase(i)
            log ('suppressed', i)
            break
        end
    end
end
eventful.enableEvent(eventful.eventType.REPORT, 1)

dfhack.onStateChange.filter_reports_clean_announcelist = function(change_type)
    if change_type ~= SC_VIEWSCREEN_CHANGED then return end
    log "screen changed"
    local scr = dfhack.gui.getCurViewscreen()
    if not df.viewscreen_announcelistst:is_instance(scr) then return end
    log "to announcelist"

    local reports = scr.reports
    for i = #reports-1,0,-1 do
        local report=reports[i]
        if not df.report.find(report.id) then
            log ('removing '..report.id..' @ '..i, df.announcement_type[report.type], report.text)
            reports:erase(i)
        end
    end
end
