fix/gifted-pets
===============

.. dfhack-tool::
    :summary: fixes pets you gift in adventure mode.
    :tags: adventure bugfix

Fix pets you gift in adventure mode. For companions, it fixes their pets not being added to your adventurer party,
leading their pets to get lost in fast-travel and being forced to follow you as a separate army.

For non-companions, it fixes pets you just gifted being lost in the site and ignoring their pet owner's associated
home building. It also fixes those pets still being part of your adventurer's nemesis companions data, which may
lead to unknown issues.

Usage
-----

::

    fix/gifted-pets
