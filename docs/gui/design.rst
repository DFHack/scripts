
gui/design
==========

.. dfhack-tool::
    :summary: Design designation utility with shapes.
    :tags: fort design productivity interface map

This tool provides a point and click interface to make designating shapes
and patterns easier. Supports both digging designations and placing
constructions.

Usage
-----

::

    gui/design

Overlay
-------

This tool also provides two overlays that are managed by the `overlay`
framework.

dimensions
~~~~~~~~~~

The ``gui/design.dimensions`` overlay shows the selected dimensions when
designating with vanilla tools, for example when painting a burrow or
designating digging. The dimensions show up in a tooltip that follows the mouse
cursor.

When this overlay is enabled, the vanilla dimensions display will be hidden.
When this overlay is disabled, the vanilla dimensions display will be unhidden.

rightclick
~~~~~~~~~~

The ``gui/design.rightclick`` overlay prevents the right mouse button and other
keys bound to "Leave screen" from exiting out of designation mode when drawing
a box with vanilla tools, instead making it cancel the designation first.
