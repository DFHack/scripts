
modtools/item-trigger
=====================
This powerful tool triggers DFHack commands when a unit equips, unequips, or
attacks another unit with specified item types, specified item materials, or
specified item contaminants.

Arguments::

    -clear
        clear all registered triggers
    -checkAttackEvery n
        check the attack event at least every n ticks
    -checkInventoryEvery n
        check inventory event at least every n ticks
    -itemType type
        trigger the command for items of this type
        examples:
            ITEM_WEAPON_PICK
            RING
    -onStrike
        trigger the command on appropriate weapon strikes
    -onEquip mode
        trigger the command when someone equips an appropriate item
        Optionally, the equipment mode can be specified
        Possible values for mode:
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
        multiple values can be specified simultaneously
        example: -onEquip [ Weapon Worn Hauled ]
    -onUnequip mode
        trigger the command when someone unequips an appropriate item
        see above note regarding 'mode' values
    -material mat
        trigger the commmand on items with the given material
        examples
            INORGANIC:IRON
            CREATURE:DWARF:BRAIN
            PLANT:OAK:WOOD
    -contaminant mat
        trigger the command for items with a given material contaminant
        examples
            INORGANIC:GOLD
            CREATURE:HUMAN:BLOOD
            PLANT:MUSHROOM_HELMET_PLUMP:DRINK
            WATER
    -command [ commandStrs ]
        specify the command to be executed
        commandStrs
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
