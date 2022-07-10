
region-pops
===========
Show or modify the populations of animals in the region.

Usage:

:region-pops list [pattern]:
        Lists encountered populations of the region, possibly restricted by pattern.
:region-pops list-all [pattern]:
        Lists all populations of the region.
:region-pops boost <TOKEN> <factor>:
        Multiply all populations of TOKEN by factor.
        If the factor is greater than one, increases the
        population, otherwise decreases it.
:region-pops boost-all <pattern> <factor>:
        Same as above, but match using a pattern acceptable to list.
:region-pops incr <TOKEN> <factor>:
        Augment (or diminish) all populations of TOKEN by factor (additive).
:region-pops incr-all <pattern> <factor>:
        Same as above, but match using a pattern acceptable to list.
