
fix/corrupt-equipment
=====================

Fixes some corruption that can occur in equipment lists, as in :bug:`11014`.

Note that there have been several possible types of corruption identified:

1. Items that have been deleted without being removed from the equipment lists
2. Items of the wrong type being stored in the equipment lists
3. Items of the wrong type being assigned to squad members

This script currently only fixes the first two, as they have been linked to the
majority of crashes.

Note that in some cases, multiple issues may be present, and may only be present
for a short window of time before DF crashes. To address this, running this
script with `repeat` is recommended. For example, to run this script every
100 ticks::

    repeat -name fix-corrupt-equipment -time 100 -timeUnits ticks -command [ fix/corrupt-equipment ]

To cancel it (which is likely safe if the script has not produced any output
in some time, and if you have saved first)::

    repeat -cancel fix-corrupt-equipment

Running this script with `repeat` on all saves is not recommended, as it can
have overhead (sometimes over 0.1 seconds on a large save). In general, running
this script with `repeat` is recommended if:

- You have experienced crashes likely caused by :bug:`11014`, and running this
  script a single time produces output but does not fix the crash
- You are running large military operations, or have sent squads out on raids

