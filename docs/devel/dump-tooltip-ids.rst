devel/dump-tooltip-ids
======================

.. dfhack-tool::
    :summary: Generate main_hover_instruction enum XML structures.
    :tags: dev

This script generates the contents of the ``main_hover_instruction`` enum and attrs, then cross-checks with the
currently-built enum attrs to determine the correct enum item names. This is intended to catch cases where items
move around.

For example, if DFHack has::

    <enum-item name='ArenaMud'>
        <item-attr name='caption' value='Add mud to the arena.'/>
    </enum-item>

as item 500, but we detect that caption at position 501 in ``main_interface.hover_instruction``, then the output
produced by the script will include the above element at position 501 instead of 500.

Before running this script, the size of ``main_interface.hover_instruction`` must be aligned properly with the
loaded verison of DF so the array of strings can be read.

Usage
-----

::

    devel/dump-tooltip-ids
