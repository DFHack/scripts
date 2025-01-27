position
========

.. dfhack-tool::
    :summary: Report cursor and mouse position, along with other info.
    :tags: adventure dfhack fort inspection map

This tool reports the current date, clock time, month, season, and historical
era. It also reports the keyboard cursor position (or just the z-level if no
active cursor), window size, and mouse location on the screen. If a site is
loaded, it prints the world coordinates of the site. If not, it prints the world
coordinates of the adventurer (if applicable).

Can also be used to copy the current keyboard cursor position for later use.

Usage
-----

::

    position [--copy]

Examples
--------

``position``
    Print various information.
``position -c``
    Copy cursor position to system clipboard.

Options
-------

``-c``, ``--copy``
    Copy current keyboard cursor position to the clipboard in format ``0,0,0``
    instead of reporting info. For convenience with other tools.
