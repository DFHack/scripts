modtools/create-item
====================

.. dfhack-tool::
    :summary: Create arbitrary items.
    :tags: dev

This tool provides a commandline interface for creating items of your choice.

Usage
-----

::

    modtools/create-item <options>

Examples
--------

``modtools/create-item -u 23145 -i WEAPON:ITEM_WEAPON_PICK -m INORGANIC:IRON -q4``
    Have unit 23145 create an exceptionally crafted iron pick.
``modtools/create-item -u 323 -i MEAT:NONE -m CREATURE:DWARF:BRAIN``
    Have unit 323 produce a lump of (prepared) brain.
``modtools/create-item -i BOULDER:NONE -m INORGANIC:RAW_ADAMANTINE -c 5``
    Spawn 5 raw adamantine boulders.
``modtools/create-item -i DRINK:NONE -m PLANT:MUSHROOM_HELMET_PLUMP:DRINK``
    Spawn a barrel of dwarven ale.

Options
-------

``-u``, ``--unit <id>`` (default: first citizen)
    The ID of the unit to use as the item's creator. You can also pass the
    string "\\LAST" to use the most recently created unit.
``-i``, ``--item <itemdef>`` (required)
    The def string of the item you want to create.
``-m``, ``--material <matdef>`` (required)
    That def string of the material you want the item to be made out of.
``-q``, ``--quality <num>`` (default: ``0``, equal to ``df.item_quality.Ordinary``)
    The quality of the created item.
``-d``, ``--description <string>`` (required if you are creating a slab)
    The text that will be engraved on the created slab.
``-c``, ``--count <num>`` (default: ``1``)
    The number of items to create. If the item is stackable, this will be the
    stack size.
``-t``, ``--caste <name or num>`` (default: ``0``)
    Used if producing a corpse or other creature-based item that could have a
    caste associated with it.
``-p``, ``--pos <x>,<y>,<z>``
    If specified, items will be spawned at the given coordinates instead of at
    the creator unit's feet.
