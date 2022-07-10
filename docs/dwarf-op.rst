
dwarf-op
========
Dwarf optimization is a script designed to provide a robust solution
to hacking dwarves to be better at work. The primary use case is as follows:

 1) take a dwarf
 2) delete their ability to do anything, even walk (job skills, phyiscal/mental attributes)
 3) load the job distribution table from dorf_tables
 4) update values in said table so the table accurately represents the distribution of your dwarves
 5) pick an under-represented job from the table
 6) apply the job to the dwarf, which means:

    - apply professions
    - provide custom profession name
    - add job skills
    - apply dwarf types
    - etc.

Beyond this use case of optimizing dwarves according to the tables in
`dorf_tables`, this script makes each step in the process available to use
separately, if you so choose.

There are two basic steps to using this script: selecting a subset of your dwarves,
and running commands on those dwarves.


Usage::

    dwarf-op -help
    dwarf-op -select <select-option> -<command> <args>

Examples::

  dwarf-op -select [ jobs Trader Miner Leader Rancher ] -applytype adaptable
  dwarf-op -select all -clear -optimize
  dwarf-op -select pall -clear -optimize
  dwarf-op -select optimized -reroll
  dwarf-op -select named -reroll inclusive -applyprofession RECRUIT

**Select options:**

.. note::

    Prepend the letter ``p`` to any option to include protected dwarves in your selection


:(none):        same as typing '-select highlighted'
:all:           selects all dwarves.

:highlighted:   selects only the in-game highlighted dwarf (from any screen).
                [Ignores protection status]

:<name>:        selects any dwarf with <name> in their name or nickname.
                (sub-string match) [Ignores protection status]

:named:         selects dwarves with user-given names.
:unnamed:       selects dwarves without user-given names.
:employed:      selects dwarves with custom professions. Excludes optimized dwarves.

:optimized:     selects dwarves based on session data. Dwarves who have been
                optimized should be listed in this data.

:unoptimized:   selects any dwarves that don't appear in session data.

:protected:     selects any dwarves which use protection signals in their name
                or profession. (i.e. ``.``, ``,``)

:unprotected:   selects any dwarves which don't use protection signals in their
                name or profession.

:drunks:        selects any dwarves which are currently zeroed, or were
                originally drunks as their profession.

:jobs:          selects any dwarves with the listed jobs. This will only match
                with custom professions, or optimized dwarves (for optimized
                dwarves see jobs in `dorf_tables`).

                Usage::

                    dwarf-op -select [ jobs job1 job2 etc. ]

                Example::

                    dwarf-op -select [ jobs Miner Trader ]

:waves:         selects dwarves from the specified migration waves. Waves are
                enumerated starting at 0 and increasing by 1 with each wave. The
                waves go by season and year and thus should match what you see
                in `list-waves` or Dwarf Therapist. It is recommended that you
                ``-show`` the selected dwarves before modifying.

                Example::

                    dwarf-op -select [ waves 0 1 3 5 7 13 ]


**General commands:**

- ``-reset``: deletes json file containing session data (bug: might not delete
  session data)

- ``-resetall``: deletes both json files. session data and existing persistent
  data (bug: might not delete session data)

- ``-show``: displays affected dwarves (id, name, migration wave, primary job).
  Useful for previewing selected dwarves before modifying them, or looking up
  the migration wave number for a group of dwarves.


**Dwarf commands:**

``clean <value>``:    Cleans selected dwarves.
                        Checks for skills with a rating of ``<value>`` and
                        deletes them from the dwarf's skill list

``-clear``:           Zeroes selected dwarves, or zeroes all dwarves if no selection is given.
                        No attributes, no labours. Assigns ``DRUNK`` profession.

``-reroll [inclusive]``: zeroes selected dwarves, then rerolls that dwarf based on its job.

                        - Ignores dwarves with unlisted jobs.
                        - optional argument: ``inclusive`` - means your dorf(s) get the best of N rolls.
                        - See attrib_levels table in `dorf_tables` for ``p`` values describing the
                          normal distribution of stats (each p value has a sub-distribution, which
                          makes the bell curve not so bell-shaped). Labours do not follow the same
                          stat system and are more uniformly random, which are compensated for in
                          the description of jobs/professions.

``-optimize``:        Performs a job search for unoptimized dwarves.
                        Each dwarf will be found a job according to the
                        job_distribution table in `dorf_tables`.

``-applyjobs``:       Applies the listed jobs to the selected dwarves.
                        - List format: ``[ job1 job2 jobn ]`` (brackets and jobs all separated by spaces)
                        - See jobs table in `dorf_tables` for available jobs."

``-applyprofessions``: Applies the listed professions to the selected dwarves.
                        - List format: ``[ prof1 prof2 profn ]`` (brackets and professions all separated by spaces)
                        - See professions table in `dorf_tables` for available professions.

``-applytypes``:      Applies the listed types to the selected dwarves.
                        - List format: ``[ type1 type2 typen ]`` (brackets and types all separated by spaces)
                        - See dwf_types table in `dorf_tables` for available types.

``renamejob <name>``: Renames the selected dwarves' custom profession to whatever is specified

**Other Arguments:**

``-help``: displays this help information.

``-debug``: enables debugging print lines

