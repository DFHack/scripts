modtools/moddable-gods
======================

.. dfhack-tool::
    :summary: Create deities.
    :tags: unavailable

This is a standardized version of Putnam's moddableGods script. It allows you
to create gods on the command-line.

Arguments::

    -name godName
        sets the name of the god to godName
        if there's already a god of that name, the script halts
    -spheres [ sphereList ]
        define a space-separated list of spheres of influence of the god
    -gender male|female|neuter
        sets the gender of the god
    -depictedAs str
        often depicted as a str
    -verbose
        if specified, prints details about the created god
