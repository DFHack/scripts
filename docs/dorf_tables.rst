
dorf_tables
===========
Data tables for `dwarf-op`

Arguments:
    - ``-list [jobs|professions|types]``

Examples::

    dorf_tables -list all
    dorf_tables -list job_distributions
    dorf_tables -list attrib_levels
    dorf_tables -list jobs
    dorf_tables -list professions
    dorf_tables -list types

~~~~~~~~~~

The data tables defined are described below.

job_distributions:
    Defines thresholds for each column of distributions. The columns must
    add up to the values in the thresholds row for that column.
    Every other row references an entry in 'jobs'

attrib_levels:
    Defines stat distributions, used for both physical and mental attributes.
    Each level gives a probability of a dwarf randomly being assigned an
    attribute level, and it provides a mean and standard deviation for the
    attribute's value.

jobs:
    Defines `dwarf-op`'s nameable jobs. This is preferable to taking every
    profession and making a distribution that covers all 100+ profs.

    Each job is comprised of required professions, optional professions,
    probabilities for each optional profession, a 'max' number of
    optional professions, and a list of type(s) to apply to dwarves in
    the defined job.

professions:
    These are a subset of the professions DF has. All professions listed
    will match a profession dwarf fortress has built in, however not all
    the built-ins are defined here.

    Each profession is defined with a set of job skills, these match
    the skills built in to dwarf fortress. Each skill is given a value
    which represents the bonus a dwarf will get to this skill. The skills
    are added in a random order, with the first few receiving the highest
    values (excluding the bonus just mentioned). Thus the bonuses are to
    ensure a minimum threshold is passed for certain skills deemed
    critical to a profession.

types:
    These are a sort of archetype system for applying to dwarves. It
    primarily includes physical attributes, but can include skills as well.

    Each type has a probability of being applied to a dwarf just by pure
    luck - this is in addition to types applied by other means. Each type
    also has a list of attribute(s) each attribute has a attribute_level
    associated to it. Additionally each type may define a list of skills
    from the aforementioned job_skill listing, each skill is defined with
    a minimum value and maximum value, the given value is an evening
    distributed random number between these two numbers (inclusive).

~~~~~~~~~~

To see a full list of built-in professions and jobs, you can run these commands::

    devel/query -table df.profession
    devel/query -table df.job_skill
