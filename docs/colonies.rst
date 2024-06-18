colonies
========

.. dfhack-tool::
    :summary: Manipulate vermin colonies and hives.
    :tags: fort armok map

Usage
-----

``colonies``
    List all vermin colonies on the map.
``colonies place [<type>]``
    Place a colony under the cursor.
``colonies convert [<type>]``
    Convert all existing colonies to the specified type.

The ``place`` and ``convert`` subcommands create or convert to honey bees by
default.

Examples
--------

``colonies place``
    Place a honey bee colony.
``colonies place ANT``
    Place an ant hive.
``colonies convert TERMITE``
    End your beekeeping industry by converting all colonies to termite mounds.
