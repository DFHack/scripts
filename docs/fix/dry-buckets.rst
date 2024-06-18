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

Usage
-----

::

    fix/dry-buckets
