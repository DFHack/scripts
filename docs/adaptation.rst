adaptation
==========

.. dfhack-tool::
    :summary: Adjust a unit's cave adaptation level.
    :tags: fort armok units

Cave adaptation (or adaption) increases for a unit when they spend time underground. If it reaches a high enough level, the unit will be affected when
View or set the level of cavern adaptation for the selected unit or the whole
fort.

Usage
-----

::

    adaptation [show] [--all]
    adaptation set [--all] <value>

The ``value`` must be between 0 and 800,000 (inclusive), with higher numbers
representing greater levels of cave adaptation.

Examples
--------

``adaptation``
    Show the cave adaptation level for the selected unit.
``adaptation set --all 0``
    Clear the cave adaptation levels for all citizens and residents.

Options
-------

``-a``, ``--all``
    Apply to all citizens and residents.
