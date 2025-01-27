fix/stuck-squad
===============

.. dfhack-tool::
    :summary: Allow squads and messengers to rescue lost squads.
    :tags: fort bugfix military

Occasionally, squads that you send out on a mission get stuck on the world map.
They lose their ability to navigate and are unable to return to your fortress.
This tool allows a messenger that is returning from a holding or any other of
your squads that is returning from a mission to rescue the lost squad along the
way and bring them home.

This fix is enabled by default in the DFHack
`control panel <gui/control-panel>`, or you can run it as needed. However, it
is still up to you to send out a messenger or squad that can be tasked with the
rescue. If you have a holding that is linked to your fort, you can send out a
messenger -- you don't have to actually request any workers. Otherwise, you can
send a squad out on a mission with minimal risk, like "Demand one-time tribute".

This tool is integrated with `gui/notify`, so you will get a notification in
the DFHack notification panel when a squad is stuck and there are no squads or
messengers currently out traveling that can rescue them.

Note that there might be other reasons why your squad appears missing -- if it
got wiped out in combat and nobody survived to report back, for example -- but
this tool should allow you to recover from the cases that are actual bugs.

Usage
-----

::

    fix/stuck-squad
