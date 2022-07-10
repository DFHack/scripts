
modtools/create-item
====================
Replaces the `createitem` plugin, with standard
arguments. The other versions will be phased out in a later version.

Arguments::

    -creator id
        specify the id of the unit who will create the item,
        or \\LAST to indicate the unit with id df.global.unit_next_id-1
        examples:
            0
            2
            \\LAST
    -material matstring
        specify the material of the item to be created
        examples:
            INORGANIC:IRON
            CREATURE_MAT:DWARF:BRAIN
            PLANT_MAT:MUSHROOM_HELMET_PLUMP:DRINK
    -item itemstr
        specify the itemdef of the item to be created
        examples:
            WEAPON:ITEM_WEAPON_PICK
    -quality qualitystr
        specify the quality level of the item to be created (df.item_quality)
        examples: Ordinary, WellCrafted, FinelyCrafted, Masterful, or 0-5
    -matchingShoes
        create two of this item
    -matchingGloves
        create two of this item, and set handedness appropriately

