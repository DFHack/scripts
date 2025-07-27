autotraining
============

.. dfhack-tool::
    :summary: Assigns citizens to a military squad until they have fulfilled their need for Martial Training
    :tags: fort auto bugfix units

This script automatically assigns citizens with the need for military training to designated training squads.

You need to have at least one squad that is set up for training. The squad should be set to "Constant Training" in the military screen. The squad doesn't need months off. The members leave the squad once they have satisfied their need for military training.

The configured uniform determines the skills that are acquired by the training dwarves. Providing "No Uniform" is a perfectly valid choice and will make your militarily inclined civilians become wrestlers over time. However, you can also provide weapons and armor to pre-train civilians for future drafts.

Once you have made squads for training use `gui/autotraining` to select the squads and ignored units, as well as the needs threshhold.

Usage
-----

    ``autotraining [<options>]``

Examples
--------

``autotraining``
    Current status of script

``enable autotraining``
    Checks to see if you have fullfilled the creation of a training squad.
    If there is no squad marked for training use, a clickable notification will appear letting you know to set one up/
    Searches your fort for dwarves with a need for military training, and begins assigning them to a training squad.
    Once they have fulfilled their need they will be removed from their squad to be replaced by the next dwarf in the list.

``disable autotraining``
    Stops adding new units to the squad.

Options
-------
    ``-t``
        Use integer values. (Default 5000)
        The negative need threshhold to trigger for each citizen
        The greater the number the longer before a dwarf is added to the waiting list.
