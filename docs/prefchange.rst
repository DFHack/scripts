prefchange
==========

.. dfhack-tool::
    :summary: Set strange mood preferences.
    :tags: unavailable

This tool sets preferences for strange moods to include a weapon type, equipment
type, and material. If you also wish to trigger a mood, see `strangemood`.

Usage
-----

::

    prefchange <command>

Examples
--------

Examine the preferences across all dwarves::

    prefchange show

Clear a unit's existing preferences and make them like hammers, mail shirts, and
steel::

    prefchange c
    prefchange has

Commands
--------

:show:  show preferences of all units
:c:     clear preferences of selected unit
:all:   clear preferences of all units
:axp:   likes axes, breastplates, and steel
:has:   likes hammers, mail shirts, and steel
:swb:   likes short swords, high boots, and steel
:spb:   likes spears, high boots, and steel
:mas:   likes maces, shields, and steel
:xbh:   likes crossbows, helms, and steel
:pig:   likes picks, gauntlets, and steel
:log:   likes long swords, gauntlets, and steel
:dap:   likes daggers, greaves, and steel
