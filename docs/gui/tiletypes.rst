gui/tiletypes
=============

.. dfhack-tool::
    :summary: Interactively shape the map.
    :tags: fort armok map

This tool is a gui for placing and modifying tiles and tile properties,
allowing you to click and paint the specified options onto the map.

.. warning::

    There is **no undo support**. This tool can confuse the game if you paint
    yourself into an "impossible" situation (like removing the original surface
    layer). Be sure to save your game before making any changes.

Usage
-----

::

    gui/tiletypes [<options>]

Examples
--------

``gui/tiletypes``
    Start the tiletypes GUI.
``gui/tiletypes --unrestricted``
    Start the tiletypes GUI with non-standard stone types available.

Options
-------

``-f``, ``--unrestricted``
    Include non-standard stone types in the selection list.

Selectors
---------

The UI provides a variety of selectors for choosing which tiles to create and
which properties to give them.

Mode
~~~~

:Paint:   Overwrite whatever tile is currently on the map.
:Replace: Only affect tiles that are not open air.
:Fill:    Only affect tiles that *are* open air.
:Remove:  Restores tiles to a form they would have if they were just dug out (if
          the ``Autocorrect`` option is enabled -- see below) or with empty air
          (if ``Autocorrect`` is not enabled).

Shape
~~~~~

A shape of ``NONE`` will keep the shape that is already on the map. You can
cycle through common shapes by clicking on the ``Shape`` selector, or you can
click on the gear button to the right of the selector to choose from the full
list of available shapes, like ramps, fortifications, or stairs.

Material
~~~~~~~~

Again, ``NONE`` will keep the material of the existing tiles, and you can cycle
through the common options by clicking on the ``Material`` selector. Extended
material selections, like grass, are available via the gear button. If you want
to paint an empty, open tile, use a material of ``AIR``.

To paint a particular type of stone, mineral, or gem, select ``STONE`` as the
material, then choose the type from the ``Stone`` selector. If you leave it at
``NONE``, then it will choose the stone associated with the geological layer.

Special
~~~~~~~

You can choose special properties of the tile, like whether it is rough or
smooth. Note that when creating walls, they will inherit the smoothness
property of whatever was there before unless you specifically set the Special
selector to ``NORMAL`` (for rough walls) or ``SMOOTH`` (for smooth walls).

Extended special properties are available via the gear button.

Variant
~~~~~~~

For tiles that have visual variations (like grass tiles in ASCII mode), you can
choose a specific variant with the selector.

More options
~~~~~~~~~~~~

These options are mostly three-state selectors. An empty box means that the
property will be left untouched. A green check (or plus symbol in ASCII mode)
indicates that the property will be set (enabled). Red Xs indicate that the
property will be cleared (disabled).

:Hidden:       Sets whether the tile is revealed or unrevealed. If you are
               filling up space with solid rock, for example, you might want to
               enable this to make the now non-exposed tiles hidden.
:Light:        Sets whether the tile is exposed to light. Dark tiles increase
               cave adaption in dwarves that cross the tile. Light tiles that
               are not also outside (see Skyview below) will neither increase
               nor decrease cave adaption in dwarves that cross the tile.
:Subterranean: Sets whether the tile is considered underground. This affects
               what crops you can plant in farm plots on this tile.
:Skyview:      Sets whether the tile is considered "outside". Weather affects
               things that are outside (e.g. by producing a grumpy thought
               about being caught in the rain). Outside tiles may also cause
               nausea in dwarves that are cave adapted, and will reduce the
               cave adaption level in dwarves that cross the tile.
:Aquifer:      Sets whether the tile is an aquifer. Two drops (in graphics
               mode) or one light blue ≈ (in ascii mode) indicates a light
               aquifer. Three drops (or ≈≈ in ascii mode) indicates a heavy
               aquifer.
:Autocorrect:  When you modify a tile, automatically fix adjacent tiles to fit
               your changes. For example, when you place a ramp, it will
               automatically place a corresponding "ramp top" in the z-level
               above (which otherwise must be done manually for the ramp to be
               displayed correctly and function). Most players should leave
               this on, but you can turn this off if you need precise control
               over each changed tile.
