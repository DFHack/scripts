fix/stuck-instruments
=====================

.. dfhack-tool::
    :summary: Allow bugged instruments to be interacted with again.
    :tags: fort bugfix items

Fixes instruments that were picked up for a performance, but were instead
simulated and are now stuck permanently in a job that no longer exists.

This works around the issue encountered with :bug:`9485`, and should be run
if you notice any instruments lying on the ground that seem to be stuck in a
job.


Usage
-----

``fix/stuck-instruments``
    Fixes item data for all stuck instruments on the map.
``fix/stuck-instruments -n``, ``fix/stuck-instruments --dry-run``
    List how many instruments would be fixed without performing the action.
