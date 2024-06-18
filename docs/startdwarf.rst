startdwarf
==========

.. dfhack-tool::
    :summary: Change the number of dwarves you embark with.
    :tags: embark fort armok

You must use this tool before you get to the embark preparation screen (e.g. at
the site selection screen or any time before) to change the number of dwarves
you embark with from the default of 7. The value that you set will remain in
effect until DF is restarted (or you use `startdwarf` to set a new value).

The maximum number of dwarves you can have is 32,767, but that is far more than
the game can handle.

Usage
-----

::

    startdwarf <number>

Examples
--------

``startdwarf 10``
    Start with a few more warm bodies to help you get started.
``startdwarf 1``
    Hermit fort! (also see the `hermit` tool for keeping it that way)
``startdwarf 500``
    Start with a teeming army of dwarves (leading to immediate food shortage and
    FPS issues).

Overlay
-------

The vanilla DF screen doesn't provide a way to scroll through the starting
dwarves, so if you start with more dwarves than can fit on your screen, this
tool provides a scrollbar that you can use to scroll through them. The vanilla
list was *not* designed for scrolling, so there is some odd behavior. When you
click on a dwarf to set skills, the list will jump so that the dwarf you
clicked on will be at the top of the page.
