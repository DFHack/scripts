rejuvenate
==========

.. dfhack-tool::
    :summary: Resets unit age.
    :tags: fort armok units

If your most valuable citizens are getting old, this tool can save them. It
decreases the age of the selected dwarf to 20 years, or to the age specified.
Age is only increased using the --force option.

Usage
-----

::

    rejuvenate [<options>]

Examples
--------

``rejuvenate``
    Set the age of the selected dwarf to 20 (if they're older).
``rejuvenate --all``
    Set the age of all dwarves over 20 to 20.
``rejuvenate --all --force``
    Set the age of all dwarves (including babies) to 20.
``rejuvenate --age 149 --force``
    Set the age of the selected dwarf to 149, even if they are younger.

Options
-------

``--all``
    Rejuvenate all citizens, not just the selected one.
``--age <num>``
    Sets the target to the age specified. If this is not set, the target age is 20.
``--force``
    Set age for units under the specified age to the specified age. Useful if there are too
    many babies around...
``--dry-run``
    Only list units that would be changed; don't actually change ages.
