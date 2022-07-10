
gui/liquids
===========
This script is a gui front-end to `liquids` and works similarly,
allowing you to add or remove water & magma, and create obsidian walls & floors.

.. image:: /docs/images/liquids.png

.. warning::

    There is **no undo support**.  Bugs in this plugin have been
    known to create pathfinding problems and heat traps.

The :kbd:`b` key changes how the affected area is selected. The default :guilabel:`Rectangle`
mode works by selecting two corners like any ordinary designation. The :kbd:`p`
key chooses between adding water, magma, obsidian walls & floors, or just
tweaking flags.

When painting liquids, it is possible to select the desired level with :kbd:`+`:kbd:`-`,
and choose between setting it exactly, only increasing or only decreasing
with :kbd:`s`.

In addition, :kbd:`f` allows disabling or enabling the flowing water computations
for an area, and :kbd:`r` operates on the "permanent flow" property that makes
rivers power water wheels even when full and technically not flowing.

After setting up the desired operations using the described keys, use :kbd:`Enter` to apply them.

