autotraining
============

.. dfhack-tool::
    :summary: Assigns citizens to a military squad until they have fulfilled their need for Martial Training
    :tags: fort auto bugfix units

Automation script for citizens to hit the gym when they yearn for the gains. Also passively builds military skills and physical stats.

You need to have at least one squad that is set up for training. This should be a new non-military-use squad. The uniform should be
set to "No Uniform" and the squad should be set to "Constant Training" in the military screen. Edit the squad's schedule to full time training with around 8 units training.
The squad doesn't need months off. The members leave the squad once they have gotten their gains.

Once you have made squads for training use `gui/autotraining` to select the squads and ignored units, as well as the needs threshhold.

Usage
-----

    ``autotraining [<options>]``

Examples
--------

``autotraining``
    Current status of script

``enable autotraining``
    Checks to see if you have fullfilled the creation of a training gym.
    If there is no squad marked for training use, a clickable notification will appear letting you know to set one up/
    Searches your fort for dwarves with a need to go to the gym, and begins assigning them to said gym.
    Once they have fulfilled their need they will be removed from the gym squad to be replaced by the next dwarf in the list.

``disable autotraining``
    Stops adding new units to the squad.

Options
-------
    ``-t``
        Use integer values. (Default 5000)
        The negative need threshhold to trigger for each citizen
        The greater the number the longer before a dwarf is added to the waiting list.
