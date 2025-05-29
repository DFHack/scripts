assign-profile
==============

.. dfhack-tool::
    :summary: Adjust characteristics of a unit according to saved profiles.
    :tags: unavailable

This tool can load a profile stored in a JSON file and apply the
characteristics to a unit.

A profile can describe which attributes, skills, preferences, beliefs, goals,
and facets a unit will have. The script relies on the presence of the other
``assign-...`` modules in this collection; please refer to the other modules'
documentation for more information on the kinds of characteristics you can set.

See the "hack/scripts/dwarf_profiles.json" file for examples of the json schema.
Please make a new file with your own additions, though, since the example file
will get overwritten when you upgrade DFHack.

Usage
-----

::

    assign-profile [--unit <id>] <options>

Examples
--------

* Loads and applies the profile called "DOCTOR" in the default json file,
  resetting the characteristics that are changed by the profile::

    assign-profile --profile DOCTOR --reset PROFILE

* Loads and applies a profile called "ARCHER" in a file you (the player) wrote.
  It keeps all the old characteristics except the attributes and the skills,
  which will be reset (and then, if the profile provides some attributes or
  skills values, those new values will be applied)::

    assign-profile --file /dfhack-config/assign-profile/military_profiles.json --profile ARCHER --reset [ ATTRIBUTES SKILLS ]

Options
-------

``--unit <id>``
    The target unit ID. If not present, the currently selected unit will be the
    target.
``--file <filename>``
    The json file containing the profile to apply. It's a relative path,
    starting from the DF root directory and ending at the json file. It must
    begin with a slash. Default value: "/hack/scripts/dwarf_profiles.json".
``--profile <profile>``
    The profile inside the json file to apply.
``--reset [ <list of characteristics> ]``
    The characteristics to be reset/cleared. If not present, it will not clear
    or reset any characteristic, and it will simply add what is described in the
    profile. If it's a valid list of characteristics, those characteristics will
    be reset, and then what is described in the profile will be applied. If set
    to the string ``PROFILE``, it will reset only the characteristics directly
    modified by the profile (and then the new values described will be applied).
    If set to ``ALL``, it will reset EVERY characteristic and then it will apply
    the profile. Accepted values are: ``ALL``, ``PROFILE``, ``ATTRIBUTES``,
    ``SKILLS``, ``PREFERENCES``, ``BELIEFS``, ``GOALS``, and ``FACETS``. There
    must be a space before and after each square bracket. If only one value is
    provided, the square brackets can be omitted.
