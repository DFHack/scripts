gui/create-item
===============

.. dfhack-tool::
    :summary: Summon items from the aether.
    :tags: adventure fort armok items

This tool provides a graphical interface for creating items of your choice. It
walks you through the creation process with a series of prompts, asking you
for the type of item, the material, the quality, and the quantity.

If a unit is selected, that unit will be designated the creator of the summoned
items. Any item with a "sized for" property, like armor, will be created for
that unit's race, and the items will appear at that unit's feet. If no unit is
selected, the first citizen unit will be used as the creator.

Usage
-----

::

    gui/create-item [<options>]

Examples
--------

``gui/create-item``
    Walk player through the creation of an item that can normally exist in the
    game.
``gui/create-item --unrestricted --count 1``
    Create one item made of anything in the game. For example, you can create
    a bar of vomit, if you please.

Options
-------

``-c``, ``--count <num>``
    Set the quantity of items to create instead of prompting for it.
``-u``, ``--unit <id>``
    Use the specified unit as the "creator" of the generated item instead of the
    selected unit or the first citizen.
``-f``, ``--unrestricted``
    Don't restrict the material options to only those that are normally
    appropriate for the selected item type.
``--startup``
    Instead of showing the item creation interface, start monitoring for a
    modded reaction with a code of ``DFHACK_WISH``. When a reaction with that
    code is completed, show the item creation gui (with ``--count 1``). This
    allows you to mod in "wands of wishing" that can let your adventurer make
    wishes for an item.
