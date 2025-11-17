
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

Shapes
------

- Rectangle
    - They can be hollow or filled using 'h'.
    - When hollow line thickness can be increased/decreased using 'T'/'t'.
    - They can be inverted using 'i'.
- Ellipse
    - They can be hollow or filled using 'h'.
    - When hollow line thickness can be increased/decreased using 'T'/'t'.
    - They can be inverted using 'i'.
- Star
    - The default has 5 points, use 'B'/'b' to increase/decrease points.
    - They can be hollow or filled using 'h'.
    - When hollow line thickness can be increased/decreased using 'T'/'t'.
    - They can be inverted using 'i'.
    - The next-point offset can be increased/decreased using 'N'/'n' which
      particularly affects 7 point stars and above to make them spikier or
      smoother, but can also be used to decrease to 1 to make symmetrical
      polygons or increase to N which only paints the vertexes.
    - The orientation can be changed by adding a main axis point using 'v' and
      moving this to point in the desired direction.
- Rows
    - Vertical rows can be toggled using 'v'.
    - Horizontal rows can be toggled using 'h'.
    - Spacing can be increased/decreased using 'T'/'t'.
    - They can be inverted using 'i'.
- Diagonal
    - Direction can be reversed using 'R'.
    - Spacing can be increased/decreased using 'T'/'t'.
    - They can be inverted using 'i'.
- Line
    - Line thickness can be increased/decreased using 'T'/'t'.
    - Can be curved by adding one or more control points using 'v'.
- FreeForm
    - Can be toggled open multi-line sequence or closed polygon using 'y'
    - Line thickness can be increased/decreased using 'T'/'t'.

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
