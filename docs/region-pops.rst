region-pops
===========

.. dfhack-tool::
    :summary: Change regional animal populations.
    :tags: fort inspection animals

This tool can show or modify the populations of animals in the region.

Usage
-----

``region-pops list [<pattern>]``
    Shows race populations of the region that your civilization knows about. You
    can filter the list by specifying a pattern.
``region-pops list-all [<pattern>]``
    Lists total race populations of the region, including those units that your
    civilization does not know about. You can filter the list by specifying a
    pattern.
``region-pops boost <race> <factor>``
    Multiply all populations of the given race by the given factor. If the
    factor is greater than one, the command will increase the population. If it
    is between 0 and 1, the command will decrease the population.
``region-pops boost-all <pattern> <factor>``
    Same as above, but apply to all races that match the given pattern.
``region-pops incr <race> <amount>``
    Add the given amount to the population counts of the given race. If the
    amount is negative, this will decrease the population.
``region-pops incr-all <pattern> <amount>``
    Same as above, but apply to all races that match the given pattern.

Examples
--------

``region-pops list-all BIRD``
    List the populations of all the bird races in the region.
``region-pops incr TROLL 1000``
    Add 1000 trolls to the region.
``region-pops boost-all .* .5``
    Halve the population of all creatures in the region.
``region-pops boost-all .* 10``
    Increase populations of all creatures by a factor of 10. Hashtag zoolife.
