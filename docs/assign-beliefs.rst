
assign-beliefs
==============
A script to change the beliefs (values) of a unit.

Beliefs are defined with the belief token and a number from -3 to 3,
which describes the different levels of belief strength, as explained here:
https://dwarffortresswiki.org/index.php/DF2014:Personality_trait#Beliefs

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

Resetting a belief means setting it to a level that does not trigger a
report in the "Thoughts and preferences" screen.

Usage:

``-help``:
                    print the help page.

``-unit <UNIT_ID>``:
                    set the target unit ID. If not present, the
                    currently selected unit will be the target.

``-beliefs [ <BELIEF> <LEVEL> <BELIEF> <LEVEL> <...> ]``:
                    the beliefs to modify and their levels. The
                    valid belief tokens can be found in the wiki page
                    linked above; level values range from -3 to 3.
                    There must be a space before and after each square
                    bracket.

``-reset``:
                    reset all beliefs to a neutral level. If the script is
                    called with both this option and a list of beliefs/levels,
                    first all the unit beliefs will be reset and then those
                    beliefs listed after ``-beliefs`` will be modified.

Example::

    assign-beliefs -reset -beliefs [ TRADITION 2 CRAFTSMANSHIP 3 POWER 0 CUNNING -1 ]

Resets all the unit beliefs, then sets the listed beliefs to the following
values:

* Tradition: a random value between 26 and 40 (level 2);
* Craftsmanship: a random value between 41 and 50 (level 3);
* Power: a random value between -10 and 10 (level 0);
* Cunning: a random value between -25 and -11 (level -1).

The final result (for a dwarf) will be: "She personally is a firm believer in
the value of tradition and sees guile and cunning as indirect and somewhat
worthless."

Note that the beliefs aligned with the cultural values of the unit have not
triggered a report.
