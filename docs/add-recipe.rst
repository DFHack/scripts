add-recipe
==========
Adds unknown weapon and armor crafting recipes to your civ.
E.g. some civilizations never learn to craft high boots. This script can
help with that, and more. Only weapons, armor, and tools are currently supported;
things such as instruments are not. Available options:

* ``add-recipe all`` adds *all* available weapons and armor, including exotic items
  like blowguns, two-handed swords, and capes.

* ``add-recipe native`` adds only native (but unknown) crafting recipes. Civilizations
  pick randomly from a pool of possible recipes, which means not all civs get
  high boots, for instance. This command gives you all the recipes your
  civilisation could have gotten.

* ``add-recipe single <item token>`` adds a single item by the given
  item token. For example::

    add-recipe single SHOES:ITEM_SHOES_BOOTS
