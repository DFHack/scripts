add-recipe
==========

.. dfhack-tool::
    :summary: Add crafting recipes to a civ.
    :tags: adventure fort gameplay

Civilizations pick randomly from a pool of possible recipes, which means, for
example, not all civs get high boots. This script can help fix that. Only
weapons, armor, and tools are currently supported; dynamically generated item
types like instruments are not.

Usage
-----

::

    add-recipe (all|native)
    add-recipe single <item token>

Examples
--------

``add-recipe native``
    Add all crafting recipes that your civ could have chosen from its pool, but
    did not.
``add-recipe all``
    Add *all* available weapons and armor, including exotic items like
    blowguns, two-handed swords, and capes.
``add-recipe single SHOES:ITEM_SHOES_BOOTS``
    Allow your civ to craft high boots.
