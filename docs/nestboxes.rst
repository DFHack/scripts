nestboxes
=========

.. dfhack-tool::
    :summary: Protect fertile eggs incubating in a nestbox.
    :tags: fort auto animals

This script will automatically check newly laid fertile eggs, compare with limit according to configuration. Any newly laid fertile eggs below limit will be forbidden so that dwarves won't come to collect them for eating. The eggs will hatch normally, even when forbidden. Adult and/or child animals can be included in check against limit. Race can be marked as ignored by script.

Usage
-----

::

    ``enable nestboxes``

    ``disable nestboxes``

    ``nestboxes target <race> <limit> <count_children> <count_adults> <ignore>``

    target command allows to change how script handles specyfic animal race, or DEFAULT settings for new animal spiecies.
    Default settings are assigned first time fertile egg is found for given race. <race> either "DEFAULT" or creature_id. <count_children> boolean if children for specified race should be added to count of existing forbidden eggs.  <count_adults> boolean if adults for specified race should be added to count of existing forbidden eggs. <ignore> boolean if race should be ignored by script.
    Script will accept "true"/"false", "0"/"1", "Y"/"N" as boolean values. If not specified value will be set to false.
    Domestic egglayers have folowing creature_id(s): BIRD_CHICKEN, BIRD_DUCK, BIRD_GOOSE, BIRD_GUINEAFOWL, BIRD_PEAFOWL_BLUE, BIRD_TURKEY.

    ``nestboxes split_stacks <boolean>``
    split_stacks command allows to specify how egg stacks that are only partialy over limit should be handled. If set to false whole stack will be forbidden. If set to true only eggs below limit will be forbidden, remaining part of stack will be separated and left for dwarves to collect.

Examples
--------

    ``nestboxes target BEAK_DOG 30 1 1 0``
    command sets limit for beak dogs to 30 including adult and children animals, race is not ignored

    ``nestboxes target BIRD_TURKEY 10``
    command sets limit  for turkeys to 10, count of live animals will not be checked, race is not ignored

    ``nestboxes target BIRD_GOOSE 10 1 1 1``
    command marks geese as ignored, geeseeggs will not be checked by script at all
    
    ``nestboxes target BIRD_GOOSE 10 1 1 1``
    command marks geese as ignored, geeseeggs will not be checked by script at all
    
