assign-facets
=============

.. dfhack-tool::
    :summary: Adjust a unit's facets and traits.
    :tags: fort armok units

Facets are defined with a token and a number from -3 to 3, which describes
the different levels of facet strength, as explained on the
:wiki:`wiki <Personality_trait>`

Usage
-----

::

    assign-facets [--unit <id>] <options>

Please run ``devel/query --table df.personality_facet_type`` to see a list of
valid facet tokens.

Example
-------

::

    assign-facets --reset --facets [ HATE_PROPENSITY -2 CHEER_PROPENSITY -1 ]

Resets all the unit facets, then sets the listed facets to the following values:

* Hate propensity: a value between 10 and 24 (level -2);
* Cheer propensity: a value between 25 and 39 (level -1).

The final result (for a dwarf) will be: "She very rarely develops negative
feelings toward things. She is rarely happy or enthusiastic, and she is
conflicted by this as she values parties and merrymaking in the abstract."

Note that the facets are compared to the beliefs, and if conflicts arise they
will be reported.

Options
-------

``--unit <id>``
    The target unit ID. If not present, the currently selected unit will be the
    target.
``--facets [ <facet> <level> [<facet> <level> ...] ]``
    The list of the facets to modify and their levels. The valid facet tokens
    can be found in the :wiki:`Personality_trait` (substitute any space with
    underscores). Levels range from -3 to 3. There must be a space before and
    after each square bracket.
``--reset``
    Reset all facets to a neutral level, aligned with the unit's race's
    cultural values. If both this option and ``--facets`` are specified, the
    unit's facets will be reset and then the listed facets will be modified.

Facet strengths
---------------

The facet strength corresponds to the text that DF will use to describe a unit's
facets:

========  =========
Strength  Effect
========  =========
3         Highest
2         Very High
1         High
0         Neutral
-1        Low
-2        Very Low
-3        Lowest
========  =========

Resetting a facet means setting it to a level that does not trigger a report in
the "Thoughts and preferences" screen, which is dependent on the race of the
unit.
