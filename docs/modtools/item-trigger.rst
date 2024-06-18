modtools/item-trigger
=====================

.. dfhack-tool::
    :summary: Run DFHack commands when a unit uses an item.
    :tags: dev

This powerful tool triggers DFHack commands when a unit equips or unequips
items or attacks another unit with specified item types, specified item
materials, or specified item contaminants.

Usage
-----

::

    modtools/item-trigger [<options>] --command [ <command> ]

At least one of the following options must be specified when registering a
trigger: ``--itemType``, ``--material``, or ``--contaminant``.

Options
-------

``--clear``
    Clear existing registered triggers before adding the specified trigger. If
    no new trigger is specified, this option just clears existing triggers.

``--checkAttackEvery <n>``
    Check for attack events at least once every n ticks.

``--checkInventoryEvery <n>``
    Check for inventory events at least once every n ticks.

``--itemType <type>``
    Trigger the command for items of this type (as specified in the raws).
    Examples::

        ITEM_WEAPON_PICK
        RING

``--material <mat>``
    Trigger the command on items with the given material. Examples::

        INORGANIC:IRON
        CREATURE:DWARF:BRAIN
        PLANT:OAK:WOOD

``--contaminant <mat>``
    Trigger the command for items with a given material contaminant. Examples::

        INORGANIC:GOLD
        CREATURE:HUMAN:BLOOD
        PLANT:MUSHROOM_HELMET_PLUMP:DRINK
        WATER

``--onStrike``
    Trigger the command on appropriate weapon strikes.

``--onEquip <mode>``
    Trigger the command when someone equips an appropriate item. Optionally,
    the equipment mode can be specified. Possible values for mode::

        Hauled
        Weapon
        Worn
        Piercing
        Flask
        WrappedAround
        StuckIn
        InMouth
        Pet
        SewnInto
        Strapped

    Multiple values can be specified simultaneously. Example::

        -onEquip [ Weapon Worn Hauled ]

``--onUnequip <mode>``
    Trigger the command when someone unequips an appropriate item. Same mode
    values as ``--onEquip``.

``--command [ <commandStrs> ]``
    Specify the command to be executed. The following tokens can be used in the
    command and they will be replaced with appropriate values::

        \\ATTACKER_ID
        \\DEFENDER_ID
        \\ITEM_MATERIAL
        \\ITEM_MATERIAL_TYPE
        \\ITEM_ID
        \\ITEM_TYPE
        \\CONTAMINANT_MATERIAL
        \\CONTAMINANT_MATERIAL_TYPE
        \\CONTAMINANT_MATERIAL_INDEX
        \\MODE
        \\UNIT_ID
        \\anything -> \anything
        anything -> anything
