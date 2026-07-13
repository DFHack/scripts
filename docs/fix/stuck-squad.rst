fix/stuck-squad
===============

.. dfhack-tool::
    :summary: Rescue stranded squads.
    :tags: fort bugfix military

Occasionally, squads that you send out on a mission get stuck on the world map.
They lose their ability to navigate and are unable to return to your fortress.
This tool brings them back to their senses and redirects them back home.

This fix is enabled by default in the DFHack
`control panel <gui/control-panel>`, or you can run it as needed.

This tool is integrated with `gui/notify`, so you will get a notification in
the DFHack notification panel when a squad is stuck and hasn't been fixed yet.

Note that there might be other reasons why your squad appears missing -- if it
got wiped out in combat and nobody survived to report back, for example -- but
this tool should allow you to recover from the cases that are actual bugs.

Usage
-----

::

    fix/stuck-squad [<options>]

Fix stuck squads and direct their armies back home. Multiple squads can share
a single army if sent on the same mission, and only armies are counted in the
total.

Examples
--------

``fix/stuck-squad``
    Fix stuck squads and print the number of affected armies.
``fix/stuck-squad -v``
    Same as above, but also print info about armies, etc.

Options
-------

``-v``, ``--verbose``
    Print IDs for the affected armies, controllers, and player fort.
    Indicate which specific armies were ignored (due to controller not fully
    removed).
``-q``, ``--quiet``
    Don't print the number of affected armies if it's zero. Intended for
    automatic use.
