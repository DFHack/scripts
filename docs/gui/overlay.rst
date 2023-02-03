gui/overlay
===========

.. dfhack-tool::
    :summary: Reposition DFHack overlay widgets.
    :tags: dfhack interface

Whereas `gui/control-panel` provides a way to browse installed overlays, enable
them, and see their help, this tool allows you to reposition the `overlay`
widgets to your liking. You can either see all overlay widgets or just the ones
configured to appear on the current DF screen. Each visible overlay widget will
be highlighted in a frame so you can find them easily. You can click on the
frame and drag the widget around the screen to reposition it, or hit
:kbd:`Enter` with the widget selected and reposition with the cursor keys.

The frame around the selected widget will show a yellow highlight to indicate
which screen edge the widget is anchored to. For example, if the bottom and
right edges of the frame are highlighted, the widget will move relative to the
bottom and right screen edge when the DF window is resized.

Usage
-----

::

    gui/overlay
