ban-cooking
===========

.. dfhack-tool::
    :summary: Protect useful items from being cooked.
    :tags: fort productivity items plants

Some cookable ingredients have other important uses. For example, seeds can be
cooked, but if you cook them all, then your farmers will have nothing to plant
in the fields. Similarly, booze can be cooked, but if you do that, then your
dwarves will have nothing (good) to drink.

If you open the Kitchen screen, you can select individual item types and choose
to ban them from cooking. To prevent all your booze from being cooked, for
example, you'd filter by "Drinks" and then click each of the visible types of
booze to prevent them from being cooked. Only types that you have in stock are
shown, so if you acquire a different type of booze in the future, you have to
come back to this screen and ban the new types.

Instead of doing all that clicking, ``ban-cooking`` can ban entire classes of
items (e.g. all types of booze) in one go. It can even ban types that you don't
have in stock yet, so when you *do* get some in stock, they will already be
banned. It will never ban items that are only good for eating or cooking, like
meat or non-plantable nuts. It is usually a good idea to run
``ban-cooking all`` as one of your first actions in a new fort. You can add
this command to your Autostart list in `gui/control-panel`.

If you want to re-enable cooking for a banned item type, you can go to the
Kitchen screen and un-ban whatever you like by clicking on the "cook"
icon. You can also un-ban an entire class of items with the ``--unban`` option.

Usage
-----

::

    ban-cooking <type|all> [<type> ...] [<options>]

Valid types are:

- ``booze``
- ``brew`` (brewable plants)
- ``fruit``
- ``honey``
- ``milk``
- ``mill`` (millable plants)
- ``oil``
- ``seeds`` (plantable seeds)
- ``tallow``
- ``thread``

Note that in the vanilla game, there are no items that can be milled or turned
into thread that can also be cooked, so these types are only useful when using
mods that add such items to the game.

Examples
--------

``ban-cooking oil tallow``
    Ban all types of oil and tallow from cooking.
``ban-cooking all``
    Ban all otherwise useful types of foods from being cooked. This command can
    be enabled for Autostart in `gui/control-panel`.

Options
-------

``-u``, ``--unban``
    Un-ban the indicated item types.

``-v``, ``--verbose``
    Print each ban as it happens.
