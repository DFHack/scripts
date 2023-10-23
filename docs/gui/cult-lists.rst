gui/cult-lists.lua
==============

.. dfhack-tool::
    :summary: List information related to deites and religions
    :tags: fort inspection

Provides a GUI interface to read data on deity and religion relationships held by units in the fort.
These are re-arranged in a per-subject basis and contain all descriptors related to individual deities and basic information on religions. It also displays textual faith levels for each worshipper.

The GUI is resizeable and such usage becomes be necessary to read the longest unit names. It is arranged in two tabs: Deities and Religions. Tabs can be changed with :kbd:`CRTL+T`. Each tabs contains two list: One for its cults and one for its units. First list is browsed with :kbd:`CTRL+V` - :kbd:`CTRL+B` and the second with :kbd:`CTRL+N` - :kbd:`CTRL+M`. The screen may be closed with :kbd:`Esc` or :kbd:`Right Click`. 

A 'quick & dirty' -console parameter dumps the lists on the DFhack console, the user may specify which list they wish to dump. The lists available are: Deities, Religions, and Deities worshipped per unit. It may also displays in-game IDs for units and historical IDs deities and religions.

The script's scope currently encopases citizens only.

Usage
-----

::

gui/cult-lists [<options>]


Options
--------

``-help``
    print in-game help message
    
``-nogui``
    disables the GUI
    
``-console``
    prints results to console plus a number of options
    default state prints all deities and their followers
    
``-printreligions``
    prints all religions and their members
    
``-printunits``
    prints all units and their personal deities
    
``-printall``
    prints cults list, worship list and unit list
    warning: large forts will exceed the console history limit.
    
``-showids``
    prints religion's history entity ids, deity's history figure ids and unit's in-game ids

Examples
--------

``gui/cult-lists``
Loads GUI with deity and religions tabs

``gui/cult-lists -nogui -console -printunits -showids``
Prints all gods per unit, with game id:
