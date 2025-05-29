modtools/invader-item-destroyer
===============================

.. dfhack-tool::
    :summary: Destroy invader items when they die.
    :tags: unavailable

This tool can destroy invader items to prevent clutter or to prevent
the player from getting tools exclusive to certain races.

Arguments::

    -clear
        reset all registered data
    -allEntities [true/false]
        set whether it should delete items from invaders from any civ
    -allItems [true/false]
        set whether it should delete all invader items regardless of
        type when an appropriate invader dies
    -item itemdef
        set a particular itemdef to be destroyed when an invader
        from an appropriate civ dies.  examples:
            ITEM_WEAPON_PICK
    -entity entityName
        set a particular entity up so that its invaders destroy their
        items shortly after death.  examples:
            MOUNTAIN
            EVIL
