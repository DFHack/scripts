gui/family-affairs
==================

.. dfhack-tool::
    :summary: Manage romantic relationships and generate pregnancies.
    :tags: adventure fort armok animals units

This tool provides an interface for inspecting (or meddling with) romantic
relationships and for producing pregnancies with specific mothers and fathers.
Perfect for matchmaking players!

If a unit is selected when you run `gui/family-affairs`, they will be
pre-loaded as a romantic partner (or prospective parent). While the window is
up, you can click on units on the map and assign them roles in the
`gui/family-affairs` UI.

You can click on unit names in the `gui/family-affairs` UI to zoom the map to
their location.

Whereas you can choose any historical figure (of the same race) to serve as a
spouse or lover, a unit must be on the map to participate in a pregnancy. For
example, you cannot generate a pregnancy with a father that is not on-site,
even if they are the selected mother's spouse.

Children and units that are insane cannot be selected for participation in a
pregnancy, and, due to game limitations, cross-species pregnancies are not
supported.

Usage
-----

::

    gui/family-affairs
    gui/family-affairs --pregnancy

Passing the ``--pregnancy`` option will start the `gui/family-affairs` UI on
the "Pregnancies" tab, and any (adult, sane) unit you have selected at the time
will be pre-selected as a parent.

Technical notes
---------------

The reason for the requirement that a father must be on the map to contribute
to a pregnancy is that the genes used for the pregnancy are associated with the
physical unit. They are not stored with the "historical figure" that represents
the father when he is off-map.
