fix/ownership
=============

.. dfhack-tool::
    :summary: Fixes instances of units claiming the same item or an item they don't own.
    :tags: fort bugfix units

Due to a bug a unit can believe they own an item when they actually do not.

When enabled in `gui/control-panel`, `fix/ownership` will run once a day to check citizens and residents and make sure they don't
mistakenly own an item they shouldn't.

This should help issues of units getting stuck in a "Store owned item" job.

Usage
-----

::

    fix/ownership
