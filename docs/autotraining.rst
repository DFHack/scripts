autotraining
============

.. dfhack-tool::
    :summary: Assigns citizens to a military squad until they have fulfilled their need for Martial Training
    :tags: fort auto bugfix units

Automation script for citizens to hit the gym when they yearn for the gains. Also passively builds military skills and physical stats.

Critical setup:

- Minimum 1 squad with the correct name (default is ``Gym``)
- An assigned squad leader in the squad
- An assigned Barracks for the squad
- Active Training orders for the squad

This should be a new non-military-use squad. The uniform should be set to "No Uniform" and the squad should be set to "Constant Training" in the military screen.
Set the squad's schedule to full time training with at least 8 or 9 training.
The squad doesn't need months off. The members leave the squad once they have gotten their gains.

NOTE: Dwarfs with the labor "Fish Dissection" enabled are ignored. Make a Dwarven labour with only the Fish Dissection enabled, set to "Only selected do this" and assign it to a dwarf to ignore them.

Usage
-----

    ``autotraining [<options>]``

Examples
--------

``autotraining``
    Current status of script

``enable autotraining``
    Checks to see if you have fullfilled the creation of a training gym.
    If there is no squad with the correct name (default: ``Gym``) with a squad leader assigned it will not proceed.
    Searches your fort for dwarves with a need to go to the gym, and begins assigning them to said gym.
    Once they have fulfilled their need they will be removed from the gym squad to be replaced by the next dwarf in the list.

``disable autotraining``
    Dwarves currently in the Gym squad, with the exception of the squad leader, will be unassigned and no new dwarves will be added to the squad.

Options
-------
    ``-t``
        Use integer values. (Default 5000)
        The negative need threshhold to trigger for each citizen
        The greater the number the longer before a dwarf is added to the waiting list.

    ``-n``
        Use a string. (Default ``Gym``)
        Pick a different name for the squad the script looks for.
