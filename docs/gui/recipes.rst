gui/recipes
===========

.. dfhack-tool::
    :summary: View, add, and remove the item recipes a civ knows.
    :tags: adventure fort gameplay

Civs pick randomly from a pool of item types at worldgen, so not every civ gets
togas, whips, or high boots. This lists every weapon, armor, clothing, ammo,
tool, toy, trap component, siege ammo, and instrument in the raws, marks the
ones your civ knows how to make, and lets you toggle them.

Unlike `add-recipe`, you can see what your civ already knows, and you can take a
recipe away again. Removing one only stops new orders; items already made are
unaffected.

Pick a category on the left, or search the ``All`` list, then hit :kbd:`Enter` to
toggle a row. Changes are saved with the fortress.

Rows are marked ``native`` if the recipe came from your civ's raws, ``exotic`` if
it did not, ``gen`` for procedurally generated items, and ``xN`` if the recipe is
listed more than once, which repeated ``add-recipe single`` runs will do.
:kbd:`Ctrl`:kbd:`D` removes duplicates.

Usage
-----

::

    gui/recipes
