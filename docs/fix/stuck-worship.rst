fix/stuck-worship
=================

.. dfhack-tool::
    :summary: Prevent dwarves from getting stuck in Worship! states.
    :tags: fort bugfix units

Dwarves that need to pray to multiple deities sometimes get stuck in a state
where they repeatedly fulfill the need to pray/worship one deity but ignore the
others. The intense need to pray to the other deities causes the dwarf to start
a purple (uninterruptible) ``Worship!`` activity, but since those needs are
never satisfied, the dwarf becomes stuck and effectively useless. More info on
this problem at :bug:`10918`.

This fix analyzes all units that are actively praying/worshipping and detects
when they have become stuck (or are on the path to becoming stuck). It then
adjusts the distribution of need so when the dwarf finishes their current
prayer, a different prayer need will be fulfilled.

This fix will run automatically if it is enabled in the ``Bugfixes`` tab in
`gui/control-panel`. If it is disabled there, you can still run it as needed.
You'll know it worked if your units go from ``Worship!`` to a prayer to some
specific deity or if the unit just stops praying altogether and picks up
another task.

Usage
-----

::

    fix/stuck-worship
