unsuspend
=========

.. dfhack-tool::
    :summary: Unsuspends building construction jobs.
    :tags: fort productivity jobs

Unsuspends building construction jobs, except for jobs managed by `buildingplan`
and those where water flow is greater than 1. This allows you to quickly recover
if a bunch of jobs were suspended due to the workers getting scared off by
wildlife or items temporarily blocking building sites.

See `autounsuspend` for periodic automatic unsuspending of suspended jobs.

Usage
-----

::

    unsuspend

Overlay
-------

This script also provides an overlay that is managed by the `overlay` framework.
When the overlay is enabled, a letter will appear over suspended buildings:

- ``P`` (green in ASCII mode) indicates that the building still in planning mode
  and is waiting on materials. The `buildingplan` plugin will unsuspend it for
  you when those materials become available.
- ``x`` (yellow in ASCII mode) means that the building is suspended and that you
  can unsuspend it manually or with the `unsuspend` command.
- ``X`` (red in ASCII mode) means that the building has been re-suspended
  multiple times, and that you might need to look into whatever is preventing
  the building from being built.

Note that in ASCII mode the letter will only appear when the game is paused
since it takes up the whole tile. In graphics mode, the letter can appear even
when the game is unpaused since you can still see the building underneath.
