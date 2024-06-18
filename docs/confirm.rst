confirm
=======

.. dfhack-tool::
    :summary: Adds confirmation dialogs for destructive actions.
    :tags: fort interface

In the base game, it is frightenly easy to destroy hours of work with a single
misclick. Now you can avoid the consequences of accidentally disbanding a squad
(for example), or deleting a hauling route.

See `gui/confirm` for a configuration GUI that controls which confirmation
prompts are enabled.

Usage
-----

::

    confirm [list]
    confirm enable|disable all
    confirm enable|disable <id> [<id> ...]

Run without parameters (or with the ``list`` option) to see the available
confirmation dialogs and their IDs. You can enable or disable all dialogs or
set them individually by their IDs.
