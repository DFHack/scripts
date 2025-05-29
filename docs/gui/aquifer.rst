gui/aquifer
===========

.. dfhack-tool::
    :summary: View, add, remove, or modify aquifers.
    :tags: fort armok map

This is the interactive GUI for the `aquifer` tool. While `gui/aquifer` is
open, aquifer tiles will be highlighted as per the `dig.warmdamp <dig>` overlay
(but unlike that overlay, only aquifer tiles are highlighted, not "just damp"
tiles or warm tiles). Note that "just damp" tiles will still be highlighted if
they are otherwise already visible.

You can draw boxes around areas of tiles to alter their aquifer properties, or
you can use the :kbd:`Ctrl`:kbd:`A`` shortcut to affect entire layers at a time.

If you want to see where the aquifer tiles are so you can designate digging,
please run `gui/reveal`. If you only want to see the aquifer tiles and not
reveal the caverns or other tiles, please run
`gui/reveal --aquifers-only <gui/reveal>` instead.

Usage
-----

::

    gui/aquifer
