caravan
=======

.. dfhack-tool::
    :summary: Adjust properties of caravans on the map.
    :tags: fort armok bugfix

This tool can help with caravans that are leaving too quickly, refuse to unload,
or are just plain unhappy that you are such a poor negotiator.

Also see `force` for creating caravans.

Usage
-----

::

    caravan [list]
    caravan extend [<days> [<ids>]]
    caravan happy [<ids>]
    caravan leave [<ids>]
    caravan unload

Commands listed with the argument ``[<ids>]`` can take multiple
(space-separated) caravan IDs (see ``caravan list`` to get the IDs). If no IDs
are specified, then the commands apply to all caravans on the map.

Examples
--------

``caravan``
    List IDs and information about all caravans on the map.
``caravan extend``
    Force a caravan that is leaving to return to the depot and extend their
    stay another 7 days.
``caravan extend 30 0 1``
    Extend the time that caravans 0 and 1 stay at the depot by 30 days. If the
    caravans have already started leaving, they will return to the depot.
``caravan happy``
    Make the active caravans willing to trade again (after seizing goods,
    annoying merchants, etc.). If the caravan has already started leaving in a
    huff, they will return to the depot.
``caravan leave``
    Makes caravans pack up and leave immediately.
``caravan unload``
    Fix a caravan that got spooked by wildlife and refuses to fully unload.

Overlays
--------

Additional functionality is provided on the various trade-related screens via
`overlay` widgets. You can turn the overlays on and off in `gui/control-panel`,
or you can reposition them to your liking with `gui/overlay`.

Bring item to depot
```````````````````

**caravan.movegoods**

When the trade depot is selected, a button appears to bring up the DFHack
enhanced move trade goods screen. You'll get a searchable, sortable list of all
your tradeable items, with hotkeys to quickly select or deselect all visible
items.

There are filter sliders for selecting items of various condition levels and
quality. For example, you can quickly trade all your tattered, frayed, and worn
clothing by setting the condition slider to include from tattered to worn, then
hitting ``Ctrl-a`` to select all.

Click on an item and shift-click on a second item to toggle all items between
the two that you clicked on. If the one that you shift-clicked on was selected,
the range of items will be deselected. If the one you shift-clicked on was not
selected, then the range of items will be selected.

If any current merchants have ethical concerns, the list of goods that you can
bring to the depot is automatically filtered (by default) to only show
ethically acceptable items. Be aware that, again, by default, if you have items
in bins, and there are unethical items mixed into the bins, then the bins will
still be brought to the depot so you can trade the ethical items within those
bins. Please use the DFHack enhanced trade screen for the actual barter to
ensure the unethical items are not actually selected for sale.

**caravan.movegoods_hider**

This overlay simply hides the vanilla "Move trade goods" button, so if you
routinely prefer to use the enhanced DFHack "Move goods" dialog, you won't
accidentally click the vanilla button.

**caravan.assigntrade**

This overlay provides a button on the vanilla "Move trade goods" screen to
launch the DFHack enhanced dialog.

Trade screen
````````````

**caravan.trade**

This overlay enables some convenient gestures and keyboard shortcuts for working
with bins:

- ``Shift-Click checkbox``: Select all items inside a bin without selecting the
    bin itself
- ``Ctrl-Click checkbox``: Collapse or expand a single bin
- ``Ctrl-Shift-Click checkbox``: Select all items within the bin and collapse it
- ``Ctrl-c``: Collapse all bins
- ``Ctrl-x``: Collapse everything (all item categories and anything
    collapsible within each category)

There is also a reminder of the fast scroll functionality provided by the
vanilla game when you hold shift while scrolling (this works everywhere).

**caravan.tradebanner**

This overlay provides a button you can click to bring up the DFHack enhanced
trade dialog, which you can use to quickly search, filter, and select caravan
and fort goods for trade.

For example, to select all steel items for purchase, search for ``steel`` and
hit ``Ctrl-a`` (or click the "Select all" button) to select them all.

By default, the DFHack trade dialog will automatically filter out items that
the merchants you are trading with find ethically offensive.

You can also bring up the DFHack trade dialog with the keyboard shortcut
``Ctrl-t``.

**caravan.tradeethics**

This overlay shows an "Ethics warning" badge next to the ``Trade`` button when
you have any items selected for sale that would offend the merchants that you
are trading with. Clicking on the badge will show a list of problematic items,
and you can click the button on the dialog to deselect all the problematic
items in your trade list.

Trade agreements
````````````````

**caravan.tradeagreement**

This adds a small panel with some useful shortcuts:

* ``Ctrl-a`` for selecting all/none in the currently shown category.
* ``Ctrl-m`` for selecting items with specific base material price (only
  enabled for item categories where this matters, like gems and leather).

Display furniture
`````````````````

**caravan.displayitemselector**

A button is added to the screen when you are viewing display furniture
(pedestals and display cases) where you can launch a the extended DFhack item
assignment GUI.

The dialog allows you to sort by name, value, or where the item is currently
assigned for display.

You can search by name, and you can filter by:

- item quality
- whether the item is forbidden
- whether the item is reachable from the display furniture
- whether the item is a written work (book or scroll)
