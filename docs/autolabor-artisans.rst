autolabor-artisans
==================

.. dfhack-tool::
    :summary: Configures autolabor to produce artisan dwarves.
    :tags: unavailable

This script runs an `autolabor` command for all labors where skill level
influences output quality (e.g. Carpentry, Stone detailing, Weaponsmithing,
etc.). It automatically enables autolabor if it is not already enabled.

After running this tool, you can make further adjustments to autolabor
configuration by running autolabor commands directly.

Usage
-----

::

    autolabor-artisans <minimum> <maximum> <talent pool>

Examples:

``autolabor-artisans 0 2 3``
    Only allows a maximum of 2 dwarves to have skill-dependent labors enabled
    at once, chosen from the talent pool of the top 3 dwarves for that skill.
