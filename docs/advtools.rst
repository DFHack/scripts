advtools
========

.. dfhack-tool::
    :summary: A collection of useful adventure mode tools.
    :tags: adventure interface gameplay units

Usage
-----

::

    advtools party

``party`` command
-----------------

When you run this command, you will get a list of your extra party members and
can choose who to promote into your "core party". This will let you control
them when in the tactics mode.

Overlays
--------

This tool provides several functions that are managed by the overlay
framework. They can be repositioned via `gui/overlay` or toggled via
`gui/control-panel`.

``advtools.conversation``
~~~~~~~~~~~~~~~~~~~~~~~~~

When enabled, this overlay will automatically add additional searchable
keywords to conversation topics. In particular, topics that relate to slain
enemies will gain the ``slay`` and ``kill`` keywords. It will also add
additional conversation options for asking whereabouts of your relationships --
in vanilla, you can only ask whereabouts of historical figures involved in
rumors you personally witnessed or heard about.

``advtools.fastcombat``
~~~~~~~~~~~~~~~~~~~~~~~

When enabled, this overlay will allow you to skip most combat animations, 
including the whooshes and projectiles travelling through the screen. It will
also let you skip the announcements window if "More" button is active,
scrolling you to the very bottom with the first press, and skipping the window
entirely with the second press. This drastically speeds up combat while still
being intuitive enough - you can still be slow and methodical if you choose
not to skip. Skip keys are left mouseclick, the SELECT button, the movement
keys and combat-related keys that don't bring up its own menu (such as bump
attack). If clicking to skip past combat, it will properly understand when
you're clicking within the announcements box and not activate the script -
only clicking OUTSIDE it will process the skipping.
