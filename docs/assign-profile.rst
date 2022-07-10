
assign-profile
==============
A script to change the characteristics of a unit
according to a profile loaded from a json file.

A profile can describe which attributes, skills, preferences, beliefs,
goals and facets a unit must have. The script relies on the presence
of the other ``assign-...`` modules in this collection: please refer
to the other modules documentation for more specific information.

For information about the json schema, please see the
the "/hack/scripts/dwarf_profiles.json" file.

Usage:

``-help``:
                    print the help page.

``-unit <UNIT_ID>``:
                    the target unit ID. If not present, the
                    target will be the currently selected unit.

``-file <filename>``:
                    the json file containing the profile to apply.
                    It's a relative path, starting from the DF
                    root directory and ending at the json file.
                    It must begin with a slash. Default value:
                    "/hack/scripts/dwarf_profiles.json".

``-profile <profile>``:
                    the profile to apply. It's the name of
                    the profile as stated in the json file.

``-reset [ <list of characteristics> ]``:
                    the characteristics to be reset/cleared. If not present,
                    it will not clear or reset any characteristic, and it will
                    simply add what is described in the profile. If it's a
                    valid list of characteristic, those characteristics will
                    be reset, and then what is described in the profile
                    will be applied. If set to ``PROFILE``, it will reset
                    only the characteristics directly modified by the profile
                    (and then the new values described will be applied).
                    If set to ``ALL``, it will reset EVERY characteristic and
                    then it will apply the profile.
                    Accepted values:
                    ``ALL``, ``PROFILE``, ``ATTRIBUTES``, ``SKILLS``,
                    ``PREFERENCES``, ``BELIEFS``, ``GOALS``, ``FACETS``.
                    There must be a space before and after each square
                    bracket. If only one value is provided, the square brackets
                    can be omitted.

Examples:

* Loads and applies the profile called "DOCTOR" in the default json file,
  resetting/clearing all the characteristics changed by the profile, leaving
  the others unchanged, and then applies the new values::

    assign-profile -profile DOCTOR -reset PROFILE

* Loads and applies the profile called "ARCHER" in the provided (fictional) json,
  keeping all the old characteristics but the attributes and the skills, which
  will be reset (and then, if the profile provides some attributes or skills values,
  those new values will be applied)::

    assign-profile -file /hack/scripts/military_profiles.json -profile ARCHER -reset [ ATTRIBUTES SKILLS ]
