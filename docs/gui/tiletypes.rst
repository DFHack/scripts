gui/tiletypes
=============

.. dfhack-tool::
    :summary: Interactively paint tiles of specified types onto the map.
    :tags: fort armok map

This tool is a gui for placing and modifying tiles and tile properties,
allowing you to click and paint the specified options onto the map.

.. warning::

    There is **no undo support**. This tool can be dangerous, be sure
    to save your game before making any changes.

Usage
-----

::

    gui/tiletypes [<options>]

Examples
--------

``gui/tiletypes``
    Start the tiletypes GUI.
``gui/tiletypes --unrestricted``
    Start the tiletypes GUI with non-standard stone types available.

Options
-------

``-f``, ``--unrestricted``
    Include non-standard stone types in the selection list.
