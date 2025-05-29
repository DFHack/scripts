allneeds
========

.. dfhack-tool::
    :summary: Summarize the cumulative needs of a unit or the entire fort.
    :tags: fort units

Provides an overview of the needs of the selected unit, or, if no unit is
selected, the fort in general. By default, the list is sorted by which needs
are making your dwarves (or the selected dwarf) most unfocused right now.

Usage
-----

::

    allneeds [<options>]

Examples
--------

``allneeds``
    Show the cumulative needs for the entire fort, or just for one unit if a
    unit is selected in the UI.

``allneeds --sort strength``
    Sort the list of needs by how strongly the people feel about them.

Options
-------

``-s``, ``--sort <criteria>``
    Choose the sort order of the list. the criteria can be:

    - ``id``: sort the needs in alphabetical order.
    - ``strength``: sort by how strongly units feel about the need. that is, if
      left unmet, how quickly the focus will decline.
    - ``focus``: sort by how unfocused the unmet needs are making your dwarves
      feel right now.
    - ``freq``: sort by how many times the need is seen (note that a single dwarf
      can feel a need many times, e.g. when needing to pray to multiple gods).
