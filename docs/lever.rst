
lever
=====
Allow manipulation of in-game levers from the dfhack console.

Can list levers, including state and links, with::

    lever list

To queue a job so that a dwarf will pull the lever 42, use ``lever pull 42``.
This is the same as :kbd:`q` querying the building and queue a :kbd:`P` pull request.

To queue a job at high priority, add ``--high`` or ``--priority``::

    lever pull 42 --high

To magically toggle the lever immediately, add ``--now`` or ``--cheat``::

    lever pull 42 --now

