gym
===

.. dfhack-tool::
    :summary: Assigns Dwarves to a military squad until they have fulfilled their need for Martial Training
    :tags: fort auto bugfix units

Also passively builds military skills and physical stats.

Critical setup:

- Minimum 1 squad with the name "Gym"
- An assigned squadleader in "Gym"
- An assigned Barracks for the squad "Gym"
- Active Training orders for the squad "Gym"

This should be a new non-military-use squad. The uniform should be set to "No Uniform" and the squad should be set to "Constant Training" in the military screen.
Set the squad's schedule to full time training with at least 8 or 9 training.
The squad doesn't need months off. The members leave the squad once they have gotten their gains.

NOTE: Dwarfs with the labor "Fish Dissection" enabled are ignored. Make a Dwarven labour with only the Fish Dissection enabled, set to "Only selected do this" and assign it to a dwarf to ignore them.

Usage
-----

    ``gym [<options>]``

Examples
--------

``gym``
    Current status of script

``gym -start``
    Checks to see if you have fullfilled the creation of a training gym.
    Searches your fort for dwarves with a need to go to the gym, and begins assigning them to said gym.
    Once they have fulfilled their need they will be removed from the gym squad to be replaced by the next dwarf in the list.

``gym -stop``
    Dwarves currently in the Gym squad, with the exception of the squad leader, will be unassigned and no new dwarves will be added to the squad.

Options
-------
    ``-start``
        Starts the script
        If there is no squad named ``Gym`` with a squadleader assigned it will not proceed.

    ``-stop``
        Stops the script

    ``-t``
        Use integer values. (Default 3000)
        The negative need threshhold to trigger for each citizen
        The greater the number the longer before a dwarf is added to the waiting list.
