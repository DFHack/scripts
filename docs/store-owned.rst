store-owned
===========

.. dfhack-tool::
    :summary: Task units to store their owned items.
    :tags: fort items buildings

Task any owned item to be stored in an appropriate storage furniture in
a room assigned to the item's owner.

Usage
-----

``store-owned [<option>]``

Select an owned item and run the tool to task the owner to put the item
into storage.

If the storage furniture is full, unreachable, or unavailable, the item
will be dropped off on the floor of the owner's room. If the owner has
no assigned room or is unable to access their room(s), the item will be
stored in the dormitory if available. If the dormitory is unreachable or
unavailable, the item will be dropped off at the trade depot instead.

This tool can be used to unburden a unit that has acquired too many
trinkets, or simply as an alternative to ``cleanowned`` when cleaning
up scattered owned items. It can also be used to force a unit to
relinquish ownership of the selected item.

Options
-------

``--dorm``
    Task the selected owned item for storage in an appropriate storage
    furniture, or on the floor, in any available dormitory zone.

``--depot``
    Task the selected owned item to be dropped off at the trade depot.

``--discard``
    Force the owner of the selected item to relinquish ownership of
    said item. The item will not be tasked for storage. If the item
    is in the owner's inventory, they will drop it on the ground.
