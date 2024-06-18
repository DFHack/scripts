putontable
==========

.. dfhack-tool::
    :summary: Make an item appear on a table.
    :tags: unavailable

To use this tool, move an item to the ground on the same tile as a built table.
Then, place the cursor over the table and item and run this command. The item
will appear on the table, just like in adventure mode shops!

Usage
-----

::

    putontable [<options>]

Example
-------

``putontable``
    Of the items currently on the ground under the table, put one item on the
    table.
``putontable --all``
    Put all items on the table that are currently on the ground under the table.

Options
-------

``-a``, ``--all``
    Put all items at the cursor on the table, not just one.
