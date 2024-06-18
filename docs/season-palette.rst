season-palette
==============

.. dfhack-tool::
    :summary: Swap color palettes when the seasons change.
    :tags: unavailable

For this tool to work you need to add *at least* one color palette file to your
save raw directory. These files must be in the same format as
:file:`data/init/colors.txt`.

Palette file names are::

    "colors.txt": The world (worldgen and default replacement) palette.
    "colors_spring.txt": The palette displayed during spring.
    "colors_summer.txt": The palette displayed during summer.
    "colors_autumn.txt": The palette displayed during autumn.
    "colors_winter.txt": The palette displayed during winter.

If you do not provide a world palette, palette switching will be disabled for
the current world. The seasonal palettes are optional; the default palette is
not! The default palette will be used to replace any missing seasonal palettes
and is used during worldgen.

When the world is unloaded or this script is disabled, the system default color
palette (:file:`/data/init/colors.txt`) will be loaded. The system default
palette will always be used in the main menu, but your custom palettes should be
used everywhere else.

Usage
-----

``enable season-palette``
    Begin swapping seasonal color palettes.
``disable season-palette``
    Stop swapping seasonal color palettes and load the default color palette.

API
---

If loaded as a module this script will export a single Lua function:

``LoadPalette(path)``
    Load a color palette from the text file at "path". This file must be in the
    same format as :file:`data/init/colors.txt`. If there is an error, any
    changes will be reverted and this function will return false. Otherwise, it
    returns true.
