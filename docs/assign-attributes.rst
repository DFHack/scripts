
assign-attributes
=================
A script to change the physical and mental attributes of a unit.

Attributes are divided into tiers from -4 to 4. Tier 0 is the
standard level and represents the average values for that attribute,
tier 4 is the maximum level, and tier -4 is the minimum level.

An example of the attribute "Strength":

====  ===================
Tier  Description
====  ===================
4     unbelievably strong
3     mighty
2     very strong
1     strong
0     (no description)
-1    weak
-2    very weak
-3    unquestionably weak
-4    unfathomably weak
====  ===================

For more information:
https://dwarffortresswiki.org/index.php/DF2014:Attribute

Usage:

``-help``:
                    print the help page.

``-unit <UNIT_ID>``:
                    the target unit ID. If not present, the
                    currently selected unit will be the target.

``-attributes [ <ATTRIBUTE> <TIER> <ATTRIBUTE> <TIER> <...> ]``:
                    the list of the attributes to modify and their tiers.
                    The valid attribute names can be found in the wiki:
                    https://dwarffortresswiki.org/index.php/DF2014:Attribute
                    (substitute any space with underscores); tiers range from -4
                    to 4. There must be a space before and after each square
                    bracket.

``-reset``:
                    reset all attributes to the average level (tier 0).
                    If both this option and a list of attributes/tiers
                    are present, the unit attributes will be reset
                    and then the listed attributes will be modified.

Example::

    assign-attributes -reset -attributes [ STRENGTH 2 AGILITY -1 SPATIAL_SENSE -1 ]

This will reset all attributes to a neutral value and will set the following
values (if the currently selected unit is a dwarf):

 * Strength: a random value between 1750 and 1999 (tier 2);
 * Agility: a random value between 401 and 650 (tier -1);
 * Spatial sense: a random value between 1043 and 1292 (tier -1).

The final result will be: "She is very strong, but she is clumsy.
She has a questionable spatial sense."
