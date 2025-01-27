idle-crafting
=============

.. dfhack-tool::
    :summary: Allow dwarves to independently craft objects when they have the need.
    :tags: fort gameplay

This script allows you to mark specific Craftsdwarf's Workshops for use as
"recreational crafting" stations. Dwarves who feel the need to craft objects
will be able to go there to independently satisfy their crafting needs without
manual intervention from the player.

There will be a toggle on the workshop info sheet ("Tasks") tab when you
select a Craftsdwarf's Workshop in the UI. More details below.

Usage
-----

``idle-crafting [status]``
     Print statistics about the status of the tool and the satisfaction of
     "craft item" needs in your fort.

``idle-crafting thresholds <number list>``
     Set the threshold(s) for the "craft item" need (i.e. the negated
     ``focus_level``) at which the tool starts to generate crafting jobs for a
     given unit. Units meeting higher thresholds will be prioritized. Defaults
     to ``500,1000,10000``.

``disable idle-crafting``
     Disallow idle crafting at all workshops. You can re-enable idle crafting
     at individual Craftsdwarf's workshops.

Examples
--------

``idle-crafting thresholds 500,1000,10000``
    Reset thresholds to defaults.

Overlay
-------

This script provides an overlay on the "Workers" tab of Craftsdwarf's workshops,
allowing you to designate that workshop for use by idle dwarves to satisfy their
needs to craft objects. Workshops that have a master assigned cannot be used in
this way.

When a workshop is designated for idle crafting, this tool will create crafting
jobs and assign them to idle dwarves who have a need for crafting objects. This
script respects the setting for permitted general work order labors from the "Workers"
tab.

For workshops without input stockpile links, bone carving and stonecrafting are
supported, with stonecrafting being the default option. Thus, to designate a
workshop for bone carving, disable the stonecrafting labor while keeping the
bone carving labor enabled.

For workshops with input stockpile links, the creation of totems, shell crafts,
and horn crafts are supported as well. In this case, the choice of job is made
randomly based on the resources available in the input stockpiles (respecting
the permitted labors from the workshop profile).
