fix/wildlife
============

.. dfhack-tool::
    :summary: Moves stuck wildlife off the map so new waves can enter.
    :tags: fort bugfix animals

This tool identifies wildlife that is trying to leave the map but has gotten
stuck. The stuck creatures will be moved off the map so that new waves of
wildlife can enter. When removing stuck wildlife, their regional population
counters are correctly incremented, just as if they had successfully left the
map on their own.

Dwarf Fortress manages wildlife in "waves". A small group of creatures of a
species that has population associated with a local region enters the map,
wanders around for a while (or aggressively attacks you if it is an agitated
group), and then leaves the map. Any members of the group that successfully
leave the map will get added back to the regional population.

The trouble, though, is that the group sometimes gets stuck when attempting to
leave. A new wave cannot enter until the previous group has been destroyed or
has left the map, so wildlife activity effectively completely halts. This is DF
:bug:`12921`.

You can run this script without parameters to immediately remove stuck
wildlife, or you can enable it in the `gui/control-panel` on the Bug Fixes tab
to monitor and manage wildlife in the background. When enabled from the control
panel, it will monitor for stuck wildlife and remove wildlife after it has been
stuck for 7 days.

Unlike most bugfixes, this one is not enabled by default since some players
like to keep wildlife around for creative purposes (e.g. for intentionally
stalling wildlife waves or for controlled startling of friendly necromancers).
These players can selectively ignore the wildlife they want to keep captive
before they enable `fix/wildlife`.

Usage
-----
::

    fix/wildlife [<options>]
    fix/wildlife ignore [unit ID]

Examples
--------

``fix/wildlife``
    Remove any wildlife that is currently trying to leave the map but has not
    yet succeeded.
``fix/wildlife --week``
    Remove wildlife that has been stuck for at least a week. The command must
    be run periodically with this option so it can discover newly stuck
    wildlife and remove wildlife when timeouts expire.
``fix/wildlife ignore``
    Disconnect the selected unit from its wildlife population so it doesn't
    block new wildlife from entering the map, but keep the unit on the map.
    This unit will not be touched by future invocations of this tool.

Options
-------

``-n``, ``--dry-run``
    Print out which creatures are stuck but take no action.
``-w``, ``--week``
    Discover newly stuck units and associate the current in-game time with
    them. Units that were discovered on a previous invocation where this
    parameter was specified will be removed if that time was at least a week
    ago.
``-q``, ``--quiet``
    Don't print the number of affected units if no units were affected.
