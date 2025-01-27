fix/dry-buckets
===============

.. dfhack-tool::
    :summary: Allow discarded water buckets to be used again.
    :tags: fort bugfix items

Sometimes, dwarves drop buckets of water on the ground if their water hauling
job is interrupted. These buckets then become unavailable for any other kind of
use, such as making lye. This tool finds those discarded buckets and removes the
water from them.

This tool also fixes over-full buckets that are blocking well operations.

If enabled in `gui/control-panel` (it is enabled by default), this fix is
periodically run automaticaly, so you should not normally need to run it
manually.

Usage
-----

``fix/dry-buckets``
    Empty water buckets not currently used in jobs.
``fix/dry-buckets -q``, ``fix/dry-buckets --quiet``
    Empty water buckets not currently used in jobs. Don't print to the console.
