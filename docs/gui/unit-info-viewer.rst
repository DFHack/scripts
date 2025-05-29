gui/unit-info-viewer
====================

.. dfhack-tool::
    :summary: Display detailed information about a unit.
    :tags: adventure fort interface inspection units

When run, it displays information about age, birth, maxage, shearing, milking,
grazing, egg laying, body size, and death for the selected unit.

You can click on different units while the tool window is open and the
displayed information will refresh for the selected unit.

Usage
-----

::

    gui/unit-info-viewer

Overlays
--------

This tool adds progress bars, experience points and levels in the unit skill
panels, color-coded to highlight rust and the highest skill levels:

- If a skill is rusty, then the level marker is colored light red
- If a skill is at Legendary level or higher, it is colored light cyan
- Other skills are colored plain white
