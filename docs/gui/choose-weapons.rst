gui/choose-weapons
==================

.. dfhack-tool::
    :summary: Ensure military dwarves choose appropriate weapons.
    :tags: unavailable

Activate in the :guilabel:`Equip->View/Customize` page of the military screen.

A weapon specification of "individual choice" is unreliable when there is a
weapon shortage. Your military dwarves often end up equipping weapons with which
they have no experience using.

Depending on the cursor location, this tool rewrites all 'individual choice
weapon' entries in the selected squad or position to use a specific weapon type
matching the unit's top skill. If the cursor is in the rightmost list over a
weapon entry, this tool rewrites only that entry, and does it even if it is not
'individual choice'.

Usage
-----

::

    gui/choose-weapons
