
gui/quantum
===========
This script provides a visual, interactive interface to make setting up quantum
stockpiles much easier.

Quantum stockpiles simplify fort management by allowing a small stockpile to
contain an infinite number of items. This reduces the complexity of your storage
design, lets your dwarves be more efficient, and increases FPS.

Quantum stockpiles work by linking a "feeder" stockpile to a one-tile minecart
hauling route. As soon as an item from the feeder stockpile is placed in the
minecart, the minecart is tipped and all items land on an adjacent tile. The
single-tile stockpile in that adjacent tile that holds all the items is your
quantum stockpile.

Before you run this script, create and configure your "feeder" stockpile. The
size of the stockpile determines how many dwarves can be tasked with bringing
items to this quantum stockpile. Somewhere between 1x3 and 5x5 is usually a good
size.

The script will walk you through the steps:
1) Select the feeder stockpile
2) Configure your quantum stockpile with the onscreen options
3) Select a spot on the map to build the quantum stockpile

If there are any minecarts available, one will be automatically associated with
the hauling route. If you don't have a free minecart, ``gui/quantum`` will
enqueue a manager order to make one for you. Once it is built, run
``assign-minecarts all`` to assign it to the route, or enter the (h)auling menu
and assign one manually. The quantum stockpile needs a minecart to function.

Quantum stockpiles work much more efficiently if you add the following line to
your ``onMapLoad.init`` file::

    prioritize -a StoreItemInVehicle

This prioritizes moving of items from the feeder stockpile to the minecart.
Otherwise, the feeder stockpile can get full and block the quantum pipeline.

See :wiki:`the wiki <Quantum_stockpile>` for more information on quantum
stockpiles.
