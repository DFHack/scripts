assign-skills
=============

.. dfhack-tool::
    :summary: Adjust a unit's skills.
    :tags: fort armok units

Skills are defined by their token and their rank. You can see a list of valid
skill tokens by running ``devel/query --table df.job_skill`` or by browsing the
:wiki:`wiki <Skill_token>`.

Usage
-----

::

    assign-skills [--unit <id>] <options>

Example
-------

::

    assign-skills --reset --skills [ WOODCUTTING 3 AXE 2 ]

Clears all the unit skills, then adds the Wood cutter skill (competent level)
and the Axeman skill (adequate level).

Options
-------

``--unit <id>``
    The target unit ID. If not present, the currently selected unit will be the
    target.
``--skills [ <skill> <rank> [<skill> <rank> ...] ]``
    The list of the skills to modify and their ranks. Rank values range from -1
    (the skill is not learned) to 20 (legendary + 5). It is actually possible to
    go beyond 20 (no check is performed), but the effect on the game may not be
    predictable. There must be a space before and after each square bracket.
``--reset``
    Clear all skills. If the script is called with both this option and
    ``--skills``, first all the unit skills will be cleared and then the listed
    skills will be added.

Skill ranks
-----------

Here is the mapping from rank value to description:

====  ================
Rank  Rank description
====  ================
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
====  ================

For more information, please see:
https://dwarffortresswiki.org/index.php/DF2014:Skill#Skill_level_names
