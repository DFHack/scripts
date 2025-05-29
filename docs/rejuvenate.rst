rejuvenate
==========

.. dfhack-tool::
    :summary: Resets unit age.
    :tags: fort armok units

If your most valuable citizens are getting old, this tool can save them. It
decreases the age of the selected dwarf to the minimum adult age, or to the age
specified. Age can only be increased (e.g. when this tool is run on babies or
children) if the ``--force`` option is specified.

Usage
-----

::

    rejuvenate [<options>]

Examples
--------

``rejuvenate``
    Set the age of the selected dwarf to 18 (if they're older than 18). The
    target age may be different if you have modded dwarves to become an adult
    at a different age, or if you have selected a unit that is not a dwarf.
``rejuvenate --all``
    Set the ages of all adult citizens and residents to their minimum adult
    ages.
``rejuvenate --all --force``
    Set the ages of all citizens and residents (including children and babies)
    to their minimum adult ages.
``rejuvenate --age 149 --force``
    Set the age of the selected dwarf to 149, even if they are younger.

Options
-------

``--all``
    Rejuvenate all citizens and residents instead of a selected unit.
``--age <num>``
    Sets the target to the age specified. If this is not set, the target age defaults to the minimum adult age for the unit.
``--force``
    Set age for units under the specified age to the specified age. Useful if
    there are too many babies around...
``--dry-run``
    Only list units that would be changed; don't actually change ages.
