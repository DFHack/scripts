
fix/population-cap
==================
Run this after every migrant wave to ensure your population cap is not exceeded.

The reason for population cap problems is that the population value it
is compared against comes from the last dwarven caravan that successfully
left for mountainhomes. This script instantly updates it.
Note that a migration wave can still overshoot the limit by 1-2 dwarves because
of the last migrant bringing his family. Likewise, king arrival ignores cap.

