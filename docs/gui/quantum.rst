gui/quantum
===========

.. dfhack-tool::
    :summary: Quickly and easily create quantum stockpiles.
    :tags: fort productivity map stockpiles

This tool provides a visual, interactive interface for creating quantum
stockpiles.

Quantum stockpiles simplify fort management by allowing a small stockpile to
contain a large number of items. This reduces the complexity of your storage
design, lets your dwarves be more efficient, and increases FPS.

Quantum stockpiles work by linking on or more "feeder" stockpiles to a one-tile
minecart hauling route. As soon as an item from the feeder stockpile(s) is
placed in the minecart, the minecart is tipped and all items land on an
adjacent tile. The single-tile stockpile in that adjacent tile holds all the
items and is your quantum stockpile. You can also choose to not have a
receiving stockpile and instead have the minecart dump into a pit (perhaps a
pit filled with magma).

Before you run this tool, create and configure your "feeder" stockpile(s). The
size of the feeders determine how many dwarves can be tasked with bringing
items to this quantum stockpile. Somewhere between 1x3 and 5x5 is usually a good
size. Make sure to assign an appropriate number of wheelbarrows to feeder
stockpiles that will contain heavy items like corpses, furniture, or boulders.

The UI will walk you through the steps:

1. Select a feeder stockpile by clicking on it. If you want to select multiple
   feeder stockpiles, switch the feeder selection toggle into multi mode.
2. Set configuration with the onscreen options.
3. Click on the map to build the quantum stockpile there.

If there are any minecarts available, one will be automatically assigned to the
hauling route. If you don't have a free minecart, ``gui/quantum`` will enqueue a
manager order to make a wooden one for you. Once it is built, you'll have to run
`assign-minecarts all <assign-minecarts>` to assign it to the route or open
the (H)auling menu and assign it manually. The quantum stockpile will not
function until the minecart is in place.

See :wiki:`the wiki <Quantum_stockpile>` for more information on quantum
stockpiles.

Usage
-----

::

    gui/quantum

Tips
----

Loading items into minecarts is a low priority task. If you find that your
feeder stockpiles are filling up because your dwarves aren't loading the items
into the minecarts, there are a few things you could change to get things
moving along:

- Make your dwarves less busy overall by reducing the number of other jobs they
  have to do
- Assign a few dwarves the Hauling work detail and specialize them so they
  focus on those tasks. Note that there is no specific labor for loading items
  into vehicles, it's just "hauling" in general.
- Run ``prioritize -a StoreItemInVehicle``, which causes the game to prioritize
  the minecart loading tasks. Note that this can pull artisans away from their
  workshops to go load minecarts. You can protect against this by specializing
  your artisans who are assigned to workshops.
