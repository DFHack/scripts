
gui/companion-order
===================
A script to issue orders for companions. Select companions with lower case chars (green when selected), issue orders with upper
case. Must be in look or talk mode to issue command on tile (e.g. move/equip/pick-up).

.. image:: /docs/images/companion-order.png

* move - orders selected companions to move to location. If companions are following they will move no more than 3 tiles from you.
* equip - try to equip items on the ground.
* pick-up - try to take items into hand (also wield)
* unequip - remove and drop equipment
* unwield - drop held items
* wait - temporarily remove from party
* follow - rejoin the party after "wait"
* leave - remove from party (can be rejoined by talking)

Can be called with '-c' flag to display "cheating" commands.

* patch up - fully heals the companion
* get in - rides e.g. minecart at cursor. Bit buggy as unit will teleport to the item when e.g. pushing it.
