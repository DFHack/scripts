
list-waves
==========
This script displays information about migration waves of the specified citizen(s).

Examples::

  list-waves -all -showarrival -granularity days
  list-waves -all -showarrival
  list-waves -unit -granularity days
  list-waves -unit
  list-waves -unit -all -showarrival -granularity days

**Selection options:**

These options are used to specify what wave information to display

``-unit``:
    Displays the highlighted unit's arrival wave information

``-all``:
    Displays all citizens' arrival wave information

**Other options:**

``-granularity <value>``:
    Specifies the granularity of wave enumeration: ``years``, ``seasons``, ``months``, ``days``
    If omitted, the default granularity is ``seasons``, the same as Dwarf Therapist

``-showarrival``:
    Shows the arrival information for the selected unit.
    If ``-all`` is specified the info displayed will be relative to the
    granularity used. Note: this option is always used when ``-unit`` is used.
