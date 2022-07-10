
assign-goals
============
A script to change the goals (dreams) of a unit.

Goals are defined with the goal token and a true/false value
that describes whether or not the goal has been accomplished. Be
advised that this last feature has not been properly tested and
might be potentially destructive: I suggest leaving it at false.

For a list of possible goals:
https://dwarffortresswiki.org/index.php/DF2014:Personality_trait#Goals

Bear in mind that nothing will stop you from assigning zero or
more than one goal, but it's not clear how it will affect the game.

Usage:

``-help``:
                    print the help page.

``-unit <UNIT_ID>``:
                    set the target unit ID. If not present, the
                    currently selected unit will be the target.

``-goals [ <GOAL> <REALIZED_FLAG> <GOAL> <REALIZED_FLAG> <...> ]``:
                    the goals to modify/add and whether they have
                    been realized or not. The valid goal tokens
                    can be found in the wiki page linked above.
                    The flag must be a true/false value.
                    There must be a space before and after each square
                    bracket.

``-reset``:
                    clear all goals. If the script is called with
                    both this option and a list of goals, first all
                    the unit goals will be erased and then those
                    goals listed after ``-goals`` will be added.

Example::

    assign-goals -reset -goals [ MASTER_A_SKILL false ]

Clears all the unit goals, then sets the "master a skill" goal. The final result
will be: "dreams of mastering a skill".

