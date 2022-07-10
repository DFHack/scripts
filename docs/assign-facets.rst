
assign-facets
=============
A script to change the facets (traits) of a unit.

Facets are defined with a token and a number from -3 to 3, which describes
the different levels of facets strength, as explained here:
https://dwarffortresswiki.org/index.php/DF2014:Personality_trait#Facets

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

Resetting a facet means setting it to a level that does not
trigger a report in the "Thoughts and preferences" screen.

Usage:

``-help``:
                    print the help page.

``-unit <UNIT_ID>``:
                    set the target unit ID. If not present, the
                    currently selected unit will be the target.

``-beliefs [ <FACET> <LEVEL> <FACET> <LEVEL> <...> ]``:
                    the facets to modify and their levels. The
                    valid facet tokens can be found in the wiki page
                    linked above; level values range from -3 to 3.
                    There must be a space before and after each square
                    bracket.

``-reset``:
                    reset all facets to a neutral level. If the script is
                    called with both this option and a list of facets/levels,
                    first all the unit facets will be reset and then those
                    facets listed after ``-facets`` will be modified.

Example::

    assign-facets -reset -facets [ HATE_PROPENSITY -2 CHEER_PROPENSITY -1 ]

Resets all the unit facets, then sets the listed facets to the following values:

* Hate propensity: a value between 10 and 24 (level -2);
* Cheer propensity: a value between 25 and 39 (level -1).

The final result (for a dwarf) will be: "She very rarely develops negative
feelings toward things. She is rarely happy or enthusiastic, and she is
conflicted by this as she values parties and merrymaking in the abstract."

Note that the facets are compared to the beliefs, and if conflicts arise they
will be reported.
