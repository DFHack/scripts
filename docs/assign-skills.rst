
assign-skills
=============
A script to change the skills of a unit.

Skills are defined by their token and their rank. Skills tokens can be
found here: https://dwarffortresswiki.org/index.php/DF2014:Skill_token

Below you can find a list of the first 16 ranks:

====  ============
Rank  Skill name
====  ============
0     Dabbling
1     Novice
2     Adequate
3     Competent
4     Skilled
5     Proficient
6     Talented
7     Adept
8     Expert
9     Professional
10    Accomplished
11    Great
12    Master
13    High Master
14    Grand Master
15+   Legendary
====  ============

For more information:
https://dwarffortresswiki.org/index.php/DF2014:Skill#Skill_level_names

Usage:

``-help``:
                    print the help page.

``-unit <UNIT_ID>``:
                    the target unit ID. If not present, the
                    currently selected unit will be the target.

``-skills [ <SKILL> <RANK> <SKILL> <RANK> <...> ]``:
                    the list of the skills to modify and their ranks.
                    Rank values range from -1 (the skill is not learned)
                    to normally 20 (legendary + 5). It is actually
                    possible to go beyond 20, no check is performed.
                    There must be a space before and after each square
                    bracket.

``-reset``:
                    clear all skills. If the script is called with
                    both this option and a list of skills/ranks,
                    first all the unit skills will be cleared
                    and then the listed skills will be added.

Example::

    assign-skills -reset -skills [ WOODCUTTING 3 AXE 2 ]

Clears all the unit skills, then adds the Wood cutter skill (competent level)
and the Axeman skill (adequate level).
