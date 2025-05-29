fix/corrupt-equipment
=====================

.. dfhack-tool::
    :summary: Fixes some game crashes caused by corrupt military equipment.
    :tags: unavailable

This fix corrects some kinds of corruption that can occur in equipment lists, as
in :bug:`11014`. Run this script at least every time a squad comes back from a
raid.

Usage
-----

::

    fix/corrupt-equipment

Examples
--------

``fix/corrupt-equipment``
    Run the fix manually a single time.
``repeat --time 100 --timeUnits ticks --command [ fix/corrupt-equipment ]``
    Automatically run the fix in the background every 100 ticks so you don't
    have to remember to run it manually.

Technical details
-----------------

There are several types of corruption that have been identified:

1. Items that have been deleted without being removed from the equipment lists
2. Items of the wrong type being stored in the equipment lists
3. Items of the wrong type being assigned to squad members

This script currently only fixes the first two, as they have been linked to the
majority of crashes.

Note that in some cases, multiple issues may be present, and may only be present
for a short window of time before DF crashes. To address this, running this
script with `repeat` is recommended.

Running this script with `repeat` on all saves is not recommended, as it can
have overhead (sometimes over 0.1 seconds on a large save). In general, running
this script with `repeat` is recommended if:

- You have experienced crashes likely caused by :bug:`11014`, and running this
  script a single time produces output but does not fix the crash
- You are running large military operations, or have sent squads out on raids
