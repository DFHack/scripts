
remove-stress
=============
Sets stress to -1,000,000; the normal range is 0 to 500,000 with very stable or
very stressed dwarves taking on negative or greater values respectively.
Applies to the selected unit, or use ``remove-stress -all`` to apply to all units.

Using the argument ``-value 0`` will reduce stress to the value 0 instead of -1,000,000.
Negative values must be preceded by a backslash (\): ``-value \-10000``.
Note that this can only be used to *decrease* stress - it cannot be increased
with this argument.

